% Ballot (Java: io.hotmoka.examples.voting.Ballot).
% Voters vote for a proposal or delegate their vote; the winner has the fewest votes.
% Pa: papers, tree map kv(Voter, paper(Weight, HasVoted, Delegate, VotedProposal)); Pr: proposals, list.
% Objects are mutated in place in Java: map_set/list_set after the field writes, no gas.

:- module(_, [init/4, give_right/5, vote/6, delegate/6, winner/2, goal/1, goal_chain/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- class(paper(weight, hasVoted, delegate, votedProposal)).
:- class(proposal(index, name, voteCount)).  % index is not a Java field: finds the proposal without gas
:- storage(Pa, map(object)).  % default only in give_right
:- storage(Pr, list).

:- regtype paper_obj/1.
paper_obj(paper(W, HV, D, VP)) :- int(W), int(HV), atm(D), int(VP).

% Reading paper fields needs a known type. The default of give_right is a paper (weight -1 if
% absent); an atom default makes the CiaoPP analysis run for minutes.
:- trust success map_get(_, _, _, P) => paper_obj(P).
:- trust success list_get(_, _, P) => proposal(P).

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
    new_obj(paper),
    Props = ~init_props(Names, 0).

init_props([], _, []).
init_props([N|T], I, [proposal(I, N, 0)|RT]) :-
    new_obj(proposal),
    I1 = I + 1,
    RT = ~init_props(T, I1).

% @FromContract giveRightToVote(to)
give_right(Caller, Chair, To, !Pa) :-
    require(Caller == Chair),
    P0 = Pa[To, paper(-1, 0, null, -1)],  % sentinel default
    if (P0 == paper(-1, 0, null, -1)) {
        new_obj(paper),
        Pa[To] := paper(1, 0, null, -1)
    } else {
        require(P0[hasVoted] =:= 0),
        require(P0[weight] =:= 0),
        P0[weight] := 1,
        map_set(To, P0, !Pa)  % in place in Java: no gas
    }.

% @FromContract voteFor(proposalIndex)
vote(Caller, Index, !Pa, !Pr) :-
    P = Pa[Caller, none],
    require(P[hasVoted] =:= 0),
    require(P[weight] > 0),
    Prop = Pr[Index],
    Prop[voteCount] += P[weight],
    P[hasVoted] := 1,
    P[votedProposal] := Index,
    list_set(Index, Prop, !Pr),
    map_set(Caller, P, !Pa).

% @FromContract delegate(to)
delegate(To, Caller, !Pa, !Pr) :-
    PTo = Pa[To, none],
    require(PTo[weight] > 0),
    PC = Pa[Caller, none],
    require(PC[hasVoted] =:= 0),
    W = PC[weight],
    require(W > 0),
    require(To \== Caller),
    PTo = Pa[To, none],  % second get, as in Java
    Del = PTo[delegate],
    Fin = ~follow(Pa, Del, Pa, [], To),
    % the papers are rebuilt with map_set after the costly goals
    PF = Pa[Fin, none],
    PF = paper(WF, HVF, _, VPF),  % already loaded
    if (HVF =:= 1) {
        set_proposal(VPF, W, !Pr)
    } else {
        WF1 = WF + W,
        PF[weight] := WF1,
        map_set(Fin, PF, !Pa)
    },
    PC[hasVoted] := 1,
    PC[delegate] := Fin,
    map_set(Caller, PC, !Pa).

% computeFinalDelegate: walk of the chain, at most one hop per paper (recursion on the papers list).
% Addresses are not measured (size_metric void).
:- trust comp follow(Ps, Del, Pa, Seen, Last, Final)
   + (size_metric(Ps, length), size_metric(Del, void), size_metric(Pa, length), size_metric(Seen, length),
      size_metric(Last, void), size_metric(Final, void), is_det).
:- trust comp differ(A, B) + (size_metric(A, void), size_metric(B, void)).

follow([], _, _, _, Last, Last).  % never reached
follow([_|Rest], Del, Pa, Seen, _, Final) :-
    differ(Del, null),
    InSeen = ~tmp_get(Del, Seen, 0),  % seen is a temporary set
    require(InSeen =:= 0),
    tmp_put(Del, 1, Seen, Seen1),
    From = Pa[Del, none],
    Del1 = ~delegate_of(From),
    Final = ~follow(Rest, Del1, Pa, Seen1, Del).
follow([_|_], null, _, _, Last, Last).

differ(A, B) :- A \== B.

% In its own predicate: inline, the unification of From makes the size analysis of follow give inf.
delegate_of(P, D) :-
    D = P[delegate].

% winnerName(): first proposal with the fewest votes; the best of the rest is computed on the way back.
winner(Pr, Name) :-
    best(Pr, Name, _).

best([], 'no winner', -1).
best([P|T], Name, Count) :-
    best(T, N1, C1),
    load(P),  % list node
    load(P),  % the Proposal
    P = proposal(_, N, C),
    if (C1 =:= -1) { Name = N, Count = C }
    else if (C =< C1) { Name = N, Count = C }
    else { Name = N1, Count = C1 }.

% votedProposal.voteCount += weight: found by index in the Prolog list, no cost besides the steps.
set_proposal(I0, W, [P|T], [P1|T]) :-
    P = proposal(I, _, _),
    I =:= I0,
    P[voteCount] += W,
    P1 = P.
set_proposal(I0, W, [P|T], [P|T1]) :-
    P = proposal(I, _, _),
    I =\= I0,
    set_proposal(I0, W, T, T1).

% Test: alice, bob and charlie can vote; alice votes prop_a, bob delegates to alice, charlie votes prop_b,
% admin votes prop_a. Expected winner (fewest votes): prop_c.
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

% Test: bob delegates to alice, then dan to bob: alice gets weight 3 and votes prop_b. Expected [prop_a, 3].
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
