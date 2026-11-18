% Simple pyramid (Java: io.hotmoka.examples.ponzi.SimplePyramid).
% Each new investment must be at least 10% greater than the previous one; it is
% split equally among all the previous investors, then the new investor joins them.
% State: Inv = investors, StorageLinkedList<PayableContract>, list of addresses;
%        N = the size field of that list; Prev = previousInvestment.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/4, invest/10, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, .(hotmoka_gas)]).

:- regtype addrs/1.
addrs([]).
addrs([A|T]) :- atm(A), addrs(T).

:- entry invest(Caller, Amount, Inv0, Inv, N0, N, Prev0, Prev, B0, B) :
    (atm(Caller), int(Amount), addrs(Inv0), var(Inv), int(N0), var(N),
     int(Prev0), var(Prev), balances(B0), var(B)).

% SimplePyramid(): the creator is the first investor
init(Creator, [Creator], 1, 1000) :-                % investors.add(caller()), previousInvestment = 1000
    new_obj(node).

% @Payable @FromContract invest(amount)
invest(Caller, Amount, !Inv, !N, !Prev, !B) :-
    transfer(Caller, this, Amount, !B),             % the amount sent with the call
    Min is Prev * 11 // 10,                         % minimumInvestment = previousInvestment * 11 / 10
    Amount >= Min,                                  % require(amount >= minimumInvestment)
    Each is Amount // N,                            % eachInvestorGets = amount / investors.size()
    pay_all(Inv, Each, !B),                         % investors.forEach(investor -> investor.receive(each))
    list_add(Caller, !Inv),                         % investors.addFirst(caller()): one new list node
    N := N + 1,                                     % (size field of the list)
    store(previousInvestment),                      % Java: previousInvestment = amount
    Prev := Amount.                                 % previousInvestment = amount

% investors.forEach(investor -> investor.receive(each)): one node load and one payment per investor.
pay_all([], _, !B).
pay_all([P|T], Each, !B) :-
    load(P),                                        % the node of the list
    transfer(this, P, Each, !B),                    % investor.receive(each)
    pay_all(T, Each, !B).

% --- Test: alice creates the pyramid; bob invests 1100, carol invests 1210 ---
% Expected: [alice, bob, carol, this] = [2000 + 1100 + 605, 2000 - 1100 + 605, 2000 - 1210, 0]
%         = [3705, 1505, 790, 0].
goal([A, Bo, C, T]) :-
    B0 = [bal(alice, 2000), bal(bob, 2000), bal(carol, 2000), bal(this, 0)],
    init(alice, Inv0, N0, P0),
    invest(bob, 1100, Inv0, Inv1, N0, N1, P0, P1, B0, B1),
    Inv1 == [alice, bob],
    Inv1b = [alice, bob],                           % (the literal keeps the call types of the analysis typed)
    invest(carol, 1210, Inv1b, _, N1, _, P1, _, B1, B2),
    balance(alice, B2, A),
    balance(bob, B2, Bo),
    balance(carol, B2, C),
    balance(this, B2, T).
