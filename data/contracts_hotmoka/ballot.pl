% Ballot (Java: io.hotmoka.examples.voting.Ballot).
% The chairperson gives the right to vote; voters vote for a proposal or delegate
% their vote; winnerName returns the proposal with the fewest votes (as the Java).
% State: Chair (chairperson, read only);
%        Pa = papers, StorageTreeMap<Contract, VotingPaper>, tree map
%             kv(Voter, paper(Weight, HasVoted, Delegate, VotedProposal))
%             (Delegate = null or an address, VotedProposal = -1 or the index of a proposal);
%        Pr = proposals, StorageLinkedList<Proposal>, list of proposal(Index, Name, VoteCount)
%             (Index = position in the list: it only serves to stop the walk of
%             proposals.get(i) without a numeric counter; it is not a field of Proposal).
% Mutations in place of the Java objects (a paper, a proposal) are rebuilt by
% set_paper/set_proposal: they cost only their resolution steps, no tree access.

:- module(_, [init/4, give_right/5, vote/6, delegate/6, winner/2, goal/1, goal_chain/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, .(hotmoka_gas)]).

:- regtype props/1.
props([]).
props([P|T]) :- proposal(P), props(T).
:- regtype proposal/1.
proposal(proposal(I, Name, Count)) :- int(I), atm(Name), int(Count).

:- entry give_right(Caller, Chair, To, Pa0, Pa) :
    (atm(Caller), atm(Chair), atm(To), map(Pa0), var(Pa)).
:- entry vote(Caller, Index, Pa0, Pa, Pr0, Pr) :
    (atm(Caller), int(Index), map(Pa0), var(Pa), props(Pr0), var(Pr)).
:- entry delegate(To, Caller, Pa0, Pa, Pr0, Pr) :
    (atm(To), atm(Caller), map(Pa0), var(Pa), props(Pr0), var(Pr)).
:- entry winner(Pr, Name) :
    (props(Pr), var(Name)).

% Ballot(proposalNames): the chairperson has a paper with the right to vote.
init(Chair, Names, [kv(Chair, paper(1, 0, null, -1))], Props) :-
    new_obj(paper),                                 % new VotingPaper(), giveRightToVote()
    init_props(Names, 0, Props).

init_props([], _, []).
init_props([N|T], I, [proposal(I, N, 0)|RT]) :-
    new_obj(proposal),                              % proposals.add(new Proposal(name))
    I1 is I + 1,
    init_props(T, I1, RT).

% @FromContract giveRightToVote(to)
give_right(Caller, Chair, To, !Pa) :-
    Caller == Chair,                                % require(caller() == chairperson)
    map_get(To, Pa, none, P0),                      % papers.computeIfAbsent(to, VotingPaper::new): tree get
    ( P0 == none ->
        new_obj(paper),                             % new VotingPaper() (not yet in the tree)
        map_put(To, paper(1, 0, null, -1), !Pa)     % computeIfAbsent puts the new key; giveRightToVote(): weight = 1
    ;
        paper_fields(P0, W, HV, D, VP),
        HV =:= 0,                                   % require(!paper.hasVoted())
        W =:= 0,                                    % require(!paper.hasRightToVote())
        store(weight),                              % Java: this.weight = 1 (existing paper)
        set_paper(To, paper(1, HV, D, VP), !Pa)     % paper.giveRightToVote(): weight = 1 (in place)
    ).

% @FromContract voteFor(proposalIndex)
vote(Caller, Index, !Pa, !Pr) :-
    map_get(Caller, Pa, none, P),                   % getVotingPaperFor(caller()): papers.get(caller)
    paper_fields(P, W, HV, D, _),
    HV =:= 0,                                       % require(!paper.hasVoted())
    W > 0,                                          % require(paper.hasRightToVote())
    add_votes(Index, W, !Pr),                       % proposals.get(index): walk; proposal.voteCount += weight
    store(voteCount),                               % Java: proposal.voteCount += weight
    store(hasVoted),                                % Java: hasVoted = true
    store(votedProposal),                           % Java: votedProposal = proposal
    set_paper(Caller, paper(W, 1, D, Index), !Pa).  % hasVoted = true; votedProposal = proposal

% @FromContract delegate(to)
delegate(To, Caller, !Pa, !Pr) :-
    map_get(To, Pa, none, PTo),                     % papers.get(to)
    paper_fields(PTo, WTo0, _, _, _),
    WTo0 > 0,                                       % require(delegatedPaper.hasRightToVote())
    map_get(Caller, Pa, none, PC),                  % getVotingPaperFor(caller()): papers.get(caller)
    paper_fields(PC, W, HV, _, VP),
    HV =:= 0,                                       % require(!paper.hasVoted())
    W > 0,                                          % require(paper.hasRightToVote())
    To \== Caller,                                  % require(delegate != payer)
    new_obj(seen),                                  % seen = new StorageTreeSet<>()
    map_get(To, Pa, none, From),                    % from = papers.get(delegate)
    paper_fields(From, _, _, Del, _),
    follow(Pa, Del, Pa, [], To, Fin),               % computeFinalDelegate: the walk, at most one hop per paper
    store(hasVoted),                                % Java: this.hasVoted = true
    store(delegate),                                % Java: this.delegate = delegate
    set_paper(Caller, paper(W, 1, Fin, VP), !Pa),   % this.hasVoted = true; this.delegate = delegate
    map_get(Fin, Pa, none, PF),                     % paperOfDelegate = papers.get(delegate)
    paper_fields(PF, WF, HVF, DF, VPF),
    ( HVF =:= 1 ->                                  % if (paperOfDelegate.hasVoted())
        load(voted_proposal),                       % votedProposal (a reference to a Proposal object)
        set_proposal(VPF, W, !Pr),                  % votedProposal.voteCount += weight
        store(voteCount)                            % Java: votedProposal.voteCount += weight
    ;
        WF1 is WF + W,
        store(weight),                              % Java: paperOfDelegate.weight += weight
        set_paper(Fin, paper(WF1, HVF, DF, VPF), !Pa)   % paperOfDelegate.weight += weight
    ).

% computeFinalDelegate. Java: from = papers.get(delegate); while (from.delegate != null) {
% delegate = from.delegate; require(delegate != payer); require(!seen.contains(delegate));
% seen.add(delegate); from = papers.get(delegate); }
% Del = from.delegate. A chain has at most one hop per paper: the recursion is over the list of papers.
% The addresses carried along are not measured (size_metric void).
% Final = the final delegate (returned along the recursion; not measured: size_metric void).
:- trust comp follow(Ps, Del, Pa, Seen, Last, Final)
   + (size_metric(Ps, length), size_metric(Del, void), size_metric(Pa, length), size_metric(Seen, length),
      size_metric(Last, void), size_metric(Final, void)).
:- trust comp differ(A, B) + (size_metric(A, void), size_metric(B, void)).

follow([], _, _, _, Last, Last).                    % never reached (a chain visits distinct papers)
follow([_|Rest], Del, Pa, Seen, _, Final) :-
    differ(Del, null),                              % while (from.delegate != null)
    map_get(Del, Seen, 0, InSeen),                  % seen.contains(delegate)
    InSeen =:= 0,                                   % require(!seen.contains(delegate))
    map_put(Del, 1, Seen, Seen1),                   % seen.add(delegate)
    map_get(Del, Pa, none, From),                   % from = papers.get(delegate)
    paper_fields(From, _, _, Del1, _),
    follow(Rest, Del1, Pa, Seen1, Del, Final).      % delegate = from.delegate
follow([_|_], null, _, _, Last, Last).              % from.delegate == null: the walk ends

differ(A, B) :- A \== B.

% The fields of a VotingPaper and their types (the tests give CiaoPP the types of what the tree returns).
paper_fields(paper(W, HV, D, VP), W, HV, D, VP) :-
    integer(W), integer(HV), atom(D), integer(VP).

% winnerName(): proposals.forEach, one node and one Proposal loaded per element.
% Java keeps the first proposal with the fewest votes (min == -1 || voteCount < min).
% The best of the rest is computed on the way back.
winner(Pr, Name) :-
    best(Pr, Name, _).

best([], 'no winner', -1).
best([P|T], Name, Count) :-
    best(T, N1, C1),
    load(P),                                        % the list node
    load(P),                                        % the Proposal (name, voteCount)
    P = proposal(_, N, C),
    ( C1 =:= -1 -> Name = N, Count = C
    ; C =< C1 -> Name = N, Count = C
    ; Name = N1, Count = C1 ).

% proposals.get(index) then proposal.voteCount += weight: the walk loads one node per step.
add_votes(I0, W, [P|T], [proposal(I, N, C1)|T]) :-
    P = proposal(I, N, C),
    I =:= I0,
    load(P),                                        % the node
    load(P),                                        % the Proposal
    C1 is C + W.
add_votes(I0, W, [P|T], [P|T1]) :-
    P = proposal(I, _, _),
    I =\= I0,
    load(P),                                        % the node
    add_votes(I0, W, T, T1).

% proposal.voteCount += weight on a Proposal already reached through a reference.
set_proposal(I0, W, [P|T], [proposal(I, N, C1)|T]) :-
    P = proposal(I, N, C),
    I =:= I0,
    C1 is C + W.
set_proposal(I0, W, [P|T], [P|T1]) :-
    P = proposal(I, _, _),
    I =\= I0,
    set_proposal(I0, W, T, T1).

% In-place mutation of a paper: rebuild of the map (no tree access).
set_paper(K, V, [kv(K1, _)|T], [kv(K1, V)|T]) :-
    K == K1.
set_paper(K, V, [kv(K1, V1)|T], [kv(K1, V1)|T1]) :-
    K \== K1,
    set_paper(K, V, T, T1).

% --- Test: admin creates [prop_a, prop_b, prop_c]; alice, bob, charlie get the right
% to vote; alice votes prop_a (0); bob delegates to alice (alice then has weight 2 only
% if she has not voted: she has, so prop_a gets bob's vote); charlie votes prop_b (1);
% admin votes prop_a (0). Votes: prop_a = 3, prop_b = 1, prop_c = 0. ---
% Expected winner (fewest votes, first one): prop_c.
goal(W) :-
    init(admin, [prop_a, prop_b, prop_c], Pa0, Pr0),
    give_right(admin, admin, alice, Pa0, Pa1),
    give_right(admin, admin, bob, Pa1, Pa2),
    give_right(admin, admin, charlie, Pa2, Pa3),
    vote(alice, 0, Pa3, Pa4, Pr0, Pr1),
    delegate(alice, bob, Pa4, Pa5, Pr1, Pr2),
    vote(charlie, 1, Pa5, Pa6, Pr2, Pr3),
    vote(admin, 0, Pa6, _, Pr3, Pr4),
    winner(Pr4, W).

% --- Test of a chain: bob delegates to alice (who has not voted), then dan delegates
% to bob: the final delegate of dan is alice, who gets weight 3 and votes prop_b (1).
% Expected votes: prop_a 0, prop_b 3, prop_c 0; winner (fewest, first one): prop_a. ---
goal_chain([W, WA]) :-
    init(admin, [prop_a, prop_b, prop_c], Pa0, Pr0),
    give_right(admin, admin, alice, Pa0, Pa1),
    give_right(admin, admin, bob, Pa1, Pa2),
    give_right(admin, admin, dan, Pa2, Pa3),
    delegate(alice, bob, Pa3, Pa4, Pr0, Pr1),
    delegate(bob, dan, Pa4, Pa5, Pr1, Pr2),
    map_get(alice, Pa5, none, paper(WA, _, _, _)),
    vote(alice, 1, Pa5, _, Pr2, Pr3),
    winner(Pr3, W).
