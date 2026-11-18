% Distributor (Java: io.hotmoka.examples.distributor.Distributor).
% Payees register; whoever calls distribute splits the amount among them, then the
% rest of the balance goes to the owner.
% State: Payees = StorageLinkedList<PayableContract>, list of addresses;
%        N = the size field of that list; Owner (the creator).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [add_as_payee/5, distribute/7, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, .(hotmoka_gas)]).

:- regtype addrs/1.
addrs([]).
addrs([A|T]) :- atm(A), addrs(T).

:- entry add_as_payee(Caller, Payees0, Payees, N0, N) :
    (atm(Caller), addrs(Payees0), var(Payees), int(N0), var(N)).
:- entry distribute(Caller, Amount, Owner, Payees, N, B0, B) :
    (atm(Caller), int(Amount), atm(Owner), addrs(Payees), int(N), balances(B0), var(B)).

% @FromContract addAsPayee()
add_as_payee(Caller, !Payees, !N) :-
    list_add(Caller, !Payees),                      % payees.add(caller()): one new list node
    N := N + 1.                                     % (size field of the list)

% @Payable @FromContract distribute(amount)
distribute(Caller, Amount, Owner, Payees, N, !B) :-
    transfer(Caller, this, Amount, !B),             % the amount sent with the call (always)
    ( N > 0 ->                                      % int size = payees.size(); if (size > 0)
        Each is Amount // N,                        % eachGets = amount / size
        pay_all(Payees, Each, !B),                  % payees.forEach(payee -> payee.receive(eachGets))
        balance(this, B, Rest),                     % balance()
        transfer(this, Owner, Rest, !B)             % owner.receive(balance())
    ; true
    ).

% payees.forEach(payee -> payee.receive(each)): one node load and one payment per payee.
pay_all([], _, !B).
pay_all([P|T], Each, !B) :-
    load(P),                                        % the node of the list
    transfer(this, P, Each, !B),                    % payee.receive(each)
    pay_all(T, Each, !B).

% --- Test: alice and bob register; carol distributes 300; the owner gets the rest (0) ---
% Expected: [alice, bob, carol, owner, this] = [1150, 1150, 700, 1000, 0].
goal([A, Bo, C, O, T]) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(carol, 1000), bal(owner, 1000), bal(this, 0)],
    add_as_payee(alice, [], P1, 0, N1),
    P1 == [alice],
    add_as_payee(bob, [alice], P2, N1, N2),         % (the literal keeps the call types of the analysis typed)
    P2 == [alice, bob],
    distribute(carol, 300, owner, [alice, bob], N2, B0, B1),
    balance(alice, B1, A),
    balance(bob, B1, Bo),
    balance(carol, B1, C),
    balance(owner, B1, O),
    balance(this, B1, T).
