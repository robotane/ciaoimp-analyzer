% CiaoPP cost spec of ballot on build/normalized/ballot.pl (the CasLog input:
% the fields of state(Chair, Proposals, Papers) are arguments).

:- module(_, [init/5, give_right/8, delegate/8, vote/8, winner/4, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% Proposals: list of proposal(Name, Votes). Papers: list of paper(Voter,
% Weight, Voted, Delegate, VoteIndex), delegate null and vote -1 if none.
:- regtype proposals/1.
proposals([]).
proposals([proposal(N, V)|T]) :- atm(N), int(V), proposals(T).

:- regtype papers/1.
papers([]).
papers([P|T]) :- paper(P), papers(T).

:- regtype paper/1.
paper(paper(V, W, Voted, D, I)) :- atm(V), int(W), int(Voted), atm(D), int(I).

:- regtype names/1.
names([]).
names([X|T]) :- atm(X), names(T).

% init(Names, Caller, Chair2, Props2, Papers2).
:- entry init(Names, Caller, C2, P2, Pa2) :
    (names(Names), atm(Caller), var(C2), var(P2), var(Pa2)).
% give_right(Voter, Caller, Chair, Props, Papers, Chair2, Props2, Papers2).
:- entry give_right(Voter, Caller, C, P, Pa, C2, P2, Pa2) :
    (atm(Voter), atm(Caller), atm(C), proposals(P), papers(Pa), var(C2),
     var(P2), var(Pa2)).
% delegate(Caller, To, Chair, Props, Papers, Chair2, Props2, Papers2).
:- entry delegate(Caller, To, C, P, Pa, C2, P2, Pa2) :
    (atm(Caller), atm(To), atm(C), proposals(P), papers(Pa), var(C2),
     var(P2), var(Pa2)).
% vote(Proposal, Caller, Chair, Props, Papers, Chair2, Props2, Papers2).
:- entry vote(Prop, Caller, C, P, Pa, C2, P2, Pa2) :
    (int(Prop), atm(Caller), atm(C), proposals(P), papers(Pa), var(C2),
     var(P2), var(Pa2)).
% winner(Winner, Chair, Props, Papers).
:- entry winner(W, C, P, Pa) : (var(W), atm(C), proposals(P), papers(Pa)).
:- entry goal(R) : var(R).
