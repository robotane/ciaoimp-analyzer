% Gradual Ponzi (Java: io.hotmoka.examples.ponzi.GradualPonzi).
% Each investment (at least 1000) is split equally among all previous investors;
% the new investor then joins the list (an investor can appear many times).
% State: Inv = investors, StorageLinkedList<PayableContract>, list of addresses.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/2, invest/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, .(hotmoka_gas)]).

:- regtype addrs/1.
addrs([]).
addrs([A|T]) :- atm(A), addrs(T).

:- entry invest(Caller, Amount, Inv0, Inv, B0, B) :
    (atm(Caller), int(Amount), addrs(Inv0), var(Inv),
     balances(B0), var(B)).

% GradualPonzi(): the creator is the first investor
init(Creator, [Creator]) :-                      % investors.add(caller())
    new_obj(node).

:- payable(invest).                             % @Payable: the amount sent is received first

% @FromContract invest(amount)
invest(Caller, Amount, !Inv, !B) :-
    Amount >= 1000,                                 % require(amount >= MINIMUM_INVESTMENT)
    list_size(Inv, N),                              % investors.size()
    Each is Amount // N,                            % eachInvestorGets = amount / investors.size()
    pay_all(Inv, Each, !B),                         % investors.forEach(investor -> investor.receive(each))
    list_add(Caller, !Inv).                         % investors.add(caller()): one new list node

% investors.forEach(investor -> investor.receive(each)): one node load and one payment per investor.
pay_all([], _, !B).
pay_all([P|T], Each, !B) :-
    load(P),                                        % the node of the list
    transfer(this, P, Each, !B),                    % investor.receive(each)
    pay_all(T, Each, !B).

% --- Test: alice creates the contract; bob invests 1000, carol invests 2000 ---
% Expected: bob's 1000 goes to alice; carol's 2000 is split between alice and bob (1000 each):
% [alice, bob, carol, this] = [4000, 2000, 0, 0].
goal([A, Bo, C, T]) :-
    B0 = [bal(alice, 2000), bal(bob, 2000), bal(carol, 2000), bal(this, 0)],
    init(alice, Inv0),
    invest(bob, 1000, Inv0, Inv1, B0, B1),
    Inv1 == [alice, bob],
    Inv1b = [alice, bob],                           % (the literal keeps the call types of the analysis typed)
    invest(carol, 2000, Inv1b, _, B1, B2),
    balance(alice, B2, A),
    balance(bob, B2, Bo),
    balance(carol, B2, C),
    balance(this, B2, T).
