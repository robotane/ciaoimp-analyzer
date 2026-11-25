% Distributor (Java: io.hotmoka.examples.distributor.Distributor).
% Payees register; distribute splits an amount among them, the rest of the balance goes to the owner.
% Payees: list of addresses. B: coin balances, list of bal(Address, Amount).

:- module(_, [add_as_payee/3, distribute/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- regtype addrs/1.
addrs([]).
addrs([A|T]) :- atm(A), addrs(T).

:- entry add_as_payee(Caller, Payees0, Payees) :
    (atm(Caller), addrs(Payees0), var(Payees)).
:- entry distribute(Caller, Amount, Owner, Payees, B0, B) :
    (atm(Caller), int(Amount), atm(Owner), addrs(Payees), balances(B0), var(B)).

% @FromContract addAsPayee()
add_as_payee(Caller, !Payees) :-
    list_add(Caller, !Payees).

:- payable(distribute).

% @FromContract distribute(amount)
distribute(Caller, Amount, Owner, Payees, !B) :-
    N = ~list_size(Payees),
    if (N > 0) {
        Each = Amount // N,
        for (P in list(Payees)) {
            transfer(this, P, Each, !B)
        },
        Rest = ~balance(this, B),
        transfer(this, Owner, Rest, !B)
    }.

% Test: alice and bob register; carol distributes 300. Expected [1150, 1150, 700, 1000, 0].
goal([A, Bo, C, O, T]) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(carol, 1000), bal(owner, 1000), bal(this, 0)],
    add_as_payee(alice, [], P1),
    P1 == [alice],
    add_as_payee(bob, [alice], P2),  % literal copy: keeps the call types
    P2 == [alice, bob],
    distribute(carol, 300, owner, [alice, bob], B0, B1),
    balance(alice, B1, A),
    balance(bob, B1, Bo),
    balance(carol, B1, C),
    balance(owner, B1, O),
    balance(this, B1, T).
