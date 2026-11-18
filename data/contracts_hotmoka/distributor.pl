% Distributor (Java: io.hotmoka.examples.distributor.Distributor).
% Payees register; whoever calls distribute splits the amount among them, then the
% rest of the balance goes to the owner.
% State: Payees = StorageLinkedList<PayableContract>, list of addresses;
%        Owner (the creator).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [add_as_payee/3, distribute/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, .(hotmoka_gas)]).

:- regtype addrs/1.
addrs([]).
addrs([A|T]) :- atm(A), addrs(T).

:- entry add_as_payee(Caller, Payees0, Payees) :
    (atm(Caller), addrs(Payees0), var(Payees)).
:- entry distribute(Caller, Amount, Owner, Payees, B0, B) :
    (atm(Caller), int(Amount), atm(Owner), addrs(Payees), balances(B0), var(B)).

% @FromContract addAsPayee()
add_as_payee(Caller, !Payees) :-
    list_add(Caller, !Payees).                      % payees.add(caller()): one new list node

:- payable(distribute).                             % @Payable: the amount sent is received first

% @FromContract distribute(amount)
distribute(Caller, Amount, Owner, Payees, !B) :-
    list_size(Payees, N),                           % int size = payees.size()
    ( N > 0 ->                                      % if (size > 0)
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
    add_as_payee(alice, [], P1),
    P1 == [alice],
    add_as_payee(bob, [alice], P2),                 % (the literal keeps the call types of the analysis typed)
    P2 == [alice, bob],
    distribute(carol, 300, owner, [alice, bob], B0, B1),
    balance(alice, B1, A),
    balance(bob, B1, Bo),
    balance(carol, B1, C),
    balance(owner, B1, O),
    balance(this, B1, T).
