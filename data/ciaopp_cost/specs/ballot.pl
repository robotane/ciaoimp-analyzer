% CiaoPP cost spec of ballot (build/executable/ballot.pl). The contract has
% no balances: the data are the table of papers (voters) and the list of
% proposals. get_paper/3 is a primitive of
% blockchain.pl, its cost (one gas per paper) is in gas_model.pl; set_paper/4
% and the rest are free (set_paper/4 is analyzed from its clauses).

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

:- entry init(Names, Chair, S) : (names(Names), atm(Chair), var(S)).
:- entry give_right(Voter, Caller, S1, S2) :
    (atm(Voter), atm(Caller), ballotstate(S1), var(S2)).
:- entry delegate(Caller, To, S1, S2) : (atm(Caller), atm(To), ballotstate(S1), var(S2)).
:- entry vote(Proposal, Caller, S1, S2) :
    (int(Proposal), atm(Caller), ballotstate(S1), var(S2)).
:- entry winner(W, S) : (var(W), ballotstate(S)).
:- entry goal(R) : var(R).

% Inner entry (the operations above keep their bound: the papers and
% proposals are inside the state).
% vote/4: aux_disj_11 is its body after get_paper, with the proposals and the
% papers as arguments of their own; only get_paper costs, so it is 0.
:- entry aux_disj_11(Proposal, Caller, S1, S2, Chair, Props, Papers, Paper) :
    (int(Proposal), atm(Caller), ballotstate(S1), var(S2), atm(Chair),
     proposals(Props), papers(Papers), paper(Paper)).
% Tried without a finite bound (entries removed): aux_disj_8 (give_right/4,
% papers as an argument), aux_disj_1 (delegate/4, find_final_delegate has no
% bound on the length of a delegation chain) and best_proposal/4 (winner/2,
% clauses 2 and 3 are not mutually exclusive for the analysis, and the
% recursion in both gives inf).
