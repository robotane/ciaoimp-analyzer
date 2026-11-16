% CiaoPP cost spec of simple_ponzi: module, entries and types. The clauses
% come unchanged from build/executable/simple_ponzi.pl.
%! prelude: balances

:- module(_, [init/2, invest/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs]).

% State: state(LastInvestor, LastAmount) (types as in interreg-imdea,
% march2026/simple_ponzi.pl).
:- regtype ponzistate/1.
ponzistate(state(A, B)) :- atm(A), int(B).

:- entry init(Caller, S) : (atm(Caller), var(S)).
:- entry invest(Caller, Amount, S1, S2, B1, B2) :
    (atm(Caller), int(Amount), ponzistate(S1), var(S2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
