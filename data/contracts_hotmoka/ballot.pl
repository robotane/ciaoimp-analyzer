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
% Fields of the storage objects (a paper, a proposal) are read and written as in Java,
% V = Obj[field] and Obj[field] := V (see hotmoka_tr.pl: the first read of a paper on a path
% loads it); the re-insertion of the object in the map/list (set_paper) costs only its
% resolution steps, no tree access.

:- module(_, [init/4, give_right/5, vote/6, delegate/6, winner/2, goal/1, goal_chain/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).                       % arithmetic is computed, as in Java

:- class(paper(weight, hasVoted, delegate, votedProposal)).
:- class(proposal(index, name, voteCount)).

:- regtype paper_obj/1.                         % a VotingPaper
paper_obj(paper(W, HV, D, VP)) :- int(W), int(HV), atm(D), int(VP).

% papers.get returns a VotingPaper: reading its fields (P[weight]...) has a known type (this
% replaces the type tests of the former paper_fields/5; the groundness of the paper comes from
% map_get, see hotmoka_gas.pl). The default of give_right is itself a
% paper (a sentinel of weight -1 for an absent key); in vote, delegate and follow the key is
% present (Java would stop on a NullPointerException otherwise). A union type with an atom
% (none) for the default makes the non-failure analysis of CiaoPP run for minutes.
:- trust success map_get(_, _, _, P) => paper_obj(P).

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
    Props = ~init_props(Names, 0).

init_props([], _, []).
init_props([N|T], I, [proposal(I, N, 0)|RT]) :-
    new_obj(proposal),                              % proposals.add(new Proposal(name))
    I1 = I + 1,
    RT = ~init_props(T, I1).

% @FromContract giveRightToVote(to)
give_right(Caller, Chair, To, !Pa) :-
    require(Caller == Chair),                       % require(caller() == chairperson)
    P0 = ~map_get(To, Pa, paper(-1, 0, null, -1)),  % papers.computeIfAbsent(to, VotingPaper::new): tree get
    if (P0 == paper(-1, 0, null, -1)) {             % absent key (sentinel default)
        new_obj(paper),                             % new VotingPaper() (not yet in the tree)
        map_put(To, paper(1, 0, null, -1), !Pa)     % computeIfAbsent puts the new key; giveRightToVote(): weight = 1
    } else {
        HV = P0[hasVoted],                          % paper.hasVoted(): loads the paper
        require(HV =:= 0),                          % require(!paper.hasVoted())
        W = P0[weight],
        require(W =:= 0),                           % require(!paper.hasRightToVote())
        P0[weight] := 1,                            % paper.giveRightToVote(): weight = 1 (in place)
        set_paper(To, P0, !Pa)                      % (the paper is mutated in place in Java)
    }.

% @FromContract voteFor(proposalIndex)
vote(Caller, Index, !Pa, !Pr) :-
    P = ~map_get(Caller, Pa, none),                 % getVotingPaperFor(caller()): papers.get(caller)
    HV = P[hasVoted],                               % paper.hasVoted(): loads the paper
    require(HV =:= 0),                              % require(!paper.hasVoted())
    W = P[weight],
    require(W > 0),                                 % require(paper.hasRightToVote())
    Prop = ~get_proposal(Index, Pr),                % proposals.get(index): walk
    Prop = proposal(_, _, Cnt),
    Cnt1 = Cnt + W,
    Prop[voteCount] := Cnt1,                        % proposal.voteCount += weight
    P[hasVoted] := 1,                               % hasVoted = true
    P[votedProposal] := Index,                      % votedProposal = proposal
    put_proposal(Index, Prop, !Pr),                 % (the proposal is mutated in place in Java)
    set_paper(Caller, P, !Pa).                     % (the paper is mutated in place in Java)

% @FromContract delegate(to)
delegate(To, Caller, !Pa, !Pr) :-
    PTo = ~map_get(To, Pa, none),                   % delegatedPaper = papers.get(to)
    WTo0 = PTo[weight],                             % delegatedPaper.hasRightToVote(): loads it
    require(WTo0 > 0),                              % require(delegatedPaper.hasRightToVote())
    PC = ~map_get(Caller, Pa, none),                % getVotingPaperFor(caller()): papers.get(caller)
    HV = PC[hasVoted],                              % paper.hasVoted(): loads it
    require(HV =:= 0),                              % require(!paper.hasVoted())
    W = PC[weight],
    require(W > 0),                                 % require(paper.hasRightToVote())
    require(To \== Caller),                         % require(delegate != payer)
                                                    % seen = new StorageTreeSet<>(): temporary, its cost is in tmp_get/tmp_put
    PTo = ~map_get(To, Pa, none),                   % from = papers.get(delegate): a tree get, and the
    Del = PTo[delegate],                            % same paper as delegatedPaper (already loaded)
    Fin = ~follow(Pa, Del, Pa, [], To),             % computeFinalDelegate: the walk, at most one hop per paper
    % The papers are rebuilt (set_paper, no cost) only after the costly goals: CiaoPP does not
    % see that set_paper has a single solution and would multiply what follows by length(Pa).
    % Reading the paper of Fin before rebuilding the paper of Caller is the same (Fin \== Caller).
    PF = ~map_get(Fin, Pa, none),                   % paperOfDelegate = papers.get(delegate)
    PF = paper(WF, HVF, _, VPF),                    % no load: this paper is already loaded, either
                                                    % delegatedPaper (no hop) or the last paper read by follow
    if (HVF =:= 1) {                                % if (paperOfDelegate.hasVoted())
        set_proposal(VPF, W, !Pr)                   % votedProposal.voteCount += weight
    } else {
        WF1 = WF + W,
        PF[weight] := WF1,                          % paperOfDelegate.weight += weight
        set_paper(Fin, PF, !Pa)                     % (the paper is mutated in place in Java)
    },
    PC[hasVoted] := 1,                              % this.hasVoted = true
    PC[delegate] := Fin,                            % this.delegate = delegate
    set_paper(Caller, PC, !Pa).                    % (the paper is mutated in place in Java)

% computeFinalDelegate. Java: from = papers.get(delegate); while (from.delegate != null) {
% delegate = from.delegate; require(delegate != payer); require(!seen.contains(delegate));
% seen.add(delegate); from = papers.get(delegate); }
% Del = from.delegate. A chain has at most one hop per paper: the recursion is over the list of papers.
% The addresses carried along are not measured (size_metric void).
% Final = the final delegate (returned along the recursion; not measured: size_metric void).
:- trust comp follow(Ps, Del, Pa, Seen, Last, Final)
   + (size_metric(Ps, length), size_metric(Del, void), size_metric(Pa, length), size_metric(Seen, length),
      size_metric(Last, void), size_metric(Final, void), is_det).
:- trust comp differ(A, B) + (size_metric(A, void), size_metric(B, void)).

follow([], _, _, _, Last, Last).                    % never reached (a chain visits distinct papers)
follow([_|Rest], Del, Pa, Seen, _, Final) :-
    differ(Del, null),                              % while (from.delegate != null)
    InSeen = ~tmp_get(Del, Seen, 0),                % seen.contains(delegate)
    require(InSeen =:= 0),                          % require(!seen.contains(delegate))
    tmp_put(Del, 1, Seen, Seen1),                   % seen.add(delegate)
    From = ~map_get(Del, Pa, none),                 % from = papers.get(delegate)
    Del1 = ~delegate_of(From),                      % from.delegate: loads the paper
    Final = ~follow(Rest, Del1, Pa, Seen1, Del).    % delegate = from.delegate
follow([_|_], null, _, _, Last, Last).              % from.delegate == null: the walk ends

differ(A, B) :- A \== B.

% from.delegate, read in a predicate of its own: written in the body of follow, the
% unification of From (whose size CiaoPP does not know: map_get gives none) makes the size
% analysis of follow fail (bound inf).
delegate_of(P, D) :-
    D = P[delegate].

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
    if (C1 =:= -1) { Name = N, Count = C }
    else if (C =< C1) { Name = N, Count = C }
    else { Name = N1, Count = C1 }.

% proposals.get(index): the walk loads one node per step; the Proposal is returned.
get_proposal(I0, [P|_], P) :-
    P = proposal(I, _, _),
    I =:= I0,
    load(P),                                        % the node
    load(P).                                        % the Proposal
get_proposal(I0, [P|T], X) :-
    P = proposal(I, _, _),
    I =\= I0,
    load(P),                                        % the node
    X = ~get_proposal(I0, T).

% The functional update of the proposal I0 (no cost of its own besides the steps).
put_proposal(I0, V, [P|T], [V|T]) :-
    P = proposal(I, _, _),
    I =:= I0.
put_proposal(I0, V, [P|T], [P|T1]) :-
    P = proposal(I, _, _),
    I =\= I0,
    put_proposal(I0, V, T, T1).

% votedProposal.voteCount += weight: the Proposal is reached through a reference (the walk on
% the index I0 only finds it in the Prolog list: no cost of its own besides the steps).
set_proposal(I0, W, [P|T], [P1|T]) :-
    P = proposal(I, _, _),
    I =:= I0,
    C = P[voteCount],                               % votedProposal.voteCount (reads the Proposal)
    C1 = C + W,
    P[voteCount] := C1,
    P1 = P.
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
