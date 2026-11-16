% CiaoPP cost spec of distributor (entries and types, as in interreg-imdea,
% march2026/distributor.pl, but typed against the clauses of
% build/executable/distributor.pl).

:- module(_, [init/3, add_as_payee/3, distribute/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Owner, Payees), Payees newest first.
:- regtype payees/1.
payees([]).
payees([X|T]) :- atm(X), payees(T).

:- regtype diststate/1.
diststate(state(Owner, Payees)) :- atm(Owner), payees(Payees).

:- entry init(Caller, S0, S) : (atm(Caller), var(S0), var(S)).
:- entry add_as_payee(Caller, S1, S2) : (atm(Caller), diststate(S1), var(S2)).
% inf upper bound of distribute/6: the cost depends on length(Payees), a list
% inside the state, which the analysis measures by term size only.
:- entry distribute(Caller, Amount, S1, S2, B1, B2) :
    (atm(Caller), int(Amount), diststate(S1), var(S2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
