% Gradual Ponzi (Java: io.hotmoka.examples.ponzi.GradualPonzi).
% Each investment (at least 1000) is split equally among all previous investors;
% the new investor then joins the list (an investor can appear many times).
% State: Inv = investors, StorageLinkedList<PayableContract>, list of addresses;
%        N = the size field of that list.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/3, invest/8, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, .(hotmoka_gas)]).

:- regtype addrs/1.
addrs([]).
addrs([A|T]) :- atm(A), addrs(T).

:- entry invest(Caller, Amount, Inv0, Inv, N0, N, B0, B) :
    (atm(Caller), int(Amount), addrs(Inv0), var(Inv), int(N0), var(N),
     balances(B0), var(B)).

% GradualPonzi(): the creator is the first investor
init(Creator, [Creator], 1) :-                      % investors.add(caller())
    new_obj(node).

% @Payable @FromContract invest(amount)
invest(Caller, Amount, !Inv, !N, !B) :-
    transfer(Caller, this, Amount, !B),             % the amount sent with the call
    Amount >= 1000,                                 % require(amount >= MINIMUM_INVESTMENT)
    Each is Amount // N,                            % eachInvestorGets = amount / investors.size()
    pay_all(Inv, Each, !B),                         % investors.forEach(investor -> investor.receive(each))
    list_add(Caller, !Inv),                         % investors.add(caller()): one new list node
    N := N + 1.                                     % (size field of the list)

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
    init(alice, Inv0, N0),
    invest(bob, 1000, Inv0, Inv1, N0, N1, B0, B1),
    Inv1 == [alice, bob],
    Inv1b = [alice, bob],                           % (the literal keeps the call types of the analysis typed)
    invest(carol, 2000, Inv1b, _, N1, _, B1, B2),
    balance(alice, B2, A),
    balance(bob, B2, Bo),
    balance(carol, B2, C),
    balance(this, B2, T).
