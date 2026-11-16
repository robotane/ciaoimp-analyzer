% CiaoPP cost spec of ballot (build/executable/ballot.pl). The contract has
% no balances: the data are the table of papers (voters) and the list of
% proposals. Cost model, as for the other lists: one gas per paper scanned by
% get_paper/3 (a full scan); set_paper/4 and the rest are free (set_paper/4
% is analyzed from its clauses, which cost 0).

:- module(_, [init/3, give_right/4, delegate/4, vote/4, winner/2, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Chair, Proposals, Papers); Proposals is a list of
% proposal(Name, Votes); Papers a list of paper(Voter, Weight, Voted,
% Delegate, VoteIndex), the delegate being the atom null and the vote -1
% when there is none.
:- regtype proposals/1.
proposals([]).
proposals([proposal(N, V)|T]) :- atm(N), int(V), proposals(T).

:- regtype papers/1.
papers([]).
papers([P|T]) :- paper(P), papers(T).

:- regtype paper/1.
paper(paper(V, W, Voted, D, I)) :- atm(V), int(W), int(Voted), atm(D), int(I).

:- regtype ballotstate/1.
ballotstate(state(Chair, Props, Papers)) :- atm(Chair), proposals(Props), papers(Papers).

:- regtype names/1.
names([]).
names([X|T]) :- atm(X), names(T).

% get_paper/3 always scans the whole table.
:- trust pred get_paper(Voter, Papers, Paper)
   + ( not_fails, is_det, cost(lb, gas, length(Papers)), cost(ub, gas, length(Papers)) ).

:- entry init(Names, Chair, S) : (names(Names), atm(Chair), var(S)).
:- entry give_right(Voter, Caller, S1, S2) :
    (atm(Voter), atm(Caller), ballotstate(S1), var(S2)).
:- entry delegate(Caller, To, S1, S2) : (atm(Caller), atm(To), ballotstate(S1), var(S2)).
:- entry vote(Proposal, Caller, S1, S2) :
    (int(Proposal), atm(Caller), ballotstate(S1), var(S2)).
:- entry winner(W, S) : (var(W), ballotstate(S)).
:- entry goal(R) : var(R).
