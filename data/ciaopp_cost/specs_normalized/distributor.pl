% CiaoPP cost spec of distributor on build/normalized/distributor.pl (the
% CasLog input: the fields of state(Owner, Payees) are arguments).

:- module(_, [init/4, add_as_payee/5, distribute/8, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% Payees, newest first.
:- regtype payees/1.
payees([]).
payees([X|T]) :- atm(X), payees(T).

% init(Caller, S0, Owner2, Payees2).
:- entry init(Caller, S0, O2, P2) : (atm(Caller), var(S0), var(O2), var(P2)).
% add_as_payee(Caller, Owner, Payees, Owner2, Payees2).
:- entry add_as_payee(Caller, Owner, P, O2, P2) :
    (atm(Caller), atm(Owner), payees(P), var(O2), var(P2)).
% distribute(Caller, Amount, Owner, Payees, Owner2, Payees2, B1, B2).
:- entry distribute(Caller, Amount, Owner, P, O2, P2, B1, B2) :
    (atm(Caller), int(Amount), atm(Owner), payees(P), var(O2), var(P2),
     balances(B1), var(B2)).
:- entry goal(R) : var(R).
