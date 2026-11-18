% Simple pyramid (Java: io.hotmoka.examples.ponzi.SimplePyramid).
% Each new investment must be at least 10% greater than the previous one; it is
% split equally among all the previous investors, then the new investor joins them.
% State: Inv = investors, StorageLinkedList<PayableContract>, list of addresses;
%        Prev = previousInvestment.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/3, invest/8, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- regtype addrs/1.
addrs([]).
addrs([A|T]) :- atm(A), addrs(T).

:- entry invest(Caller, Amount, Inv0, Inv, Prev0, Prev, B0, B) :
    (atm(Caller), int(Amount), addrs(Inv0), var(Inv),
     int(Prev0), var(Prev), balances(B0), var(B)).

% SimplePyramid(): the creator is the first investor
init(Creator, [Creator], 1000) :-                % investors.add(caller()), previousInvestment = 1000
    new_obj(node).

:- payable(invest).                             % @Payable: the amount sent is received first

% @FromContract invest(amount)
invest(Caller, Amount, !Inv, !Prev, !B) :-
    Min is Prev * 11 // 10,                         % minimumInvestment = previousInvestment * 11 / 10
    Amount >= Min,                                  % require(amount >= minimumInvestment)
    list_size(Inv, N),                              % investors.size()
    Each is Amount // N,                            % eachInvestorGets = amount / investors.size()
    for (P in list(Inv)) {                          % investors.forEach(investor -> investor.receive(each))
        load(P),                                    % the node of the list
        transfer(this, P, Each, !B)                 % investor.receive(each)
    },
    list_add(Caller, !Inv),                         % investors.addFirst(caller()): one new list node
    Prev := Amount.                                 % previousInvestment = amount

% --- Test: alice creates the pyramid; bob invests 1100, carol invests 1210 ---
% Expected: [alice, bob, carol, this] = [2000 + 1100 + 605, 2000 - 1100 + 605, 2000 - 1210, 0]
%         = [3705, 1505, 790, 0].
goal([A, Bo, C, T]) :-
    B0 = [bal(alice, 2000), bal(bob, 2000), bal(carol, 2000), bal(this, 0)],
    init(alice, Inv0, P0),
    invest(bob, 1100, Inv0, Inv1, P0, P1, B0, B1),
    Inv1 == [alice, bob],
    Inv1b = [alice, bob],                           % (the literal keeps the call types of the analysis typed)
    invest(carol, 1210, Inv1b, _, P1, _, B1, B2),
    balance(alice, B2, A),
    balance(bob, B2, Bo),
    balance(carol, B2, C),
    balance(this, B2, T).
