% Gradual Ponzi (Java: io.hotmoka.examples.ponzi.GradualPonzi).
% Each investment (at least 1000) is split equally among all previous investors;
% the new investor then joins the list (an investor can appear many times).
% State: Inv = investors, StorageLinkedList<PayableContract>, list of addresses.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/2, invest/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- regtype addrs/1.
addrs([]).
addrs([A|T]) :- atm(A), addrs(T).

:- entry invest(Caller, Amount, Inv0, Inv, B0, B) :
    (atm(Caller), int(Amount), addrs(Inv0), var(Inv),
     balances(B0), var(B)).

% GradualPonzi(): the creator is the first investor
init(Creator, Inv) :-
    Inv = ~list_add(Creator, []).                   % investors.add(caller())

:- bigint_cost.                                  % gas of the BigInteger operations by bit length

:- payable(invest).                             % @Payable: the amount sent is received first

% @FromContract invest(amount)
invest(Caller, Amount, !Inv, !B) :-
    require(big_ge(Amount, 1000)),                  % require(compareTo(amount, MINIMUM_INVESTMENT) >= 0)
    N = ~list_size(Inv),                            % investors.size()
    big_div(Amount, N, Each),                       % eachInvestorGets = divide(amount, valueOf(size))
    Held is Amount + Amount,                        % the contract holds the amount received plus its rests (< Amount)
    for (P in list(Inv)) {                          % investors.forEach(investor -> ...)
        transfer(this, P, Each, !B),                % investor.receive(each)
        big_pay(Each, Held)                         % its BigInteger operations (compareTo, subtract, add)
    },
    list_add(Caller, !Inv).                         % investors.add(caller()): one new list node

% --- Test: alice creates the contract; bob invests 1000, carol invests 2000 ---
% Expected: bob's 1000 goes to alice; carol's 2000 is split between alice and bob (1000 each):
% [alice, bob, carol, this] = [4000, 2000, 0, 0].
goal([A, Bo, C, T]) :-
    B0 = [bal(alice, 2000), bal(bob, 2000), bal(carol, 2000), bal(this, 0)],
    init(alice, Inv0),
    Inv0 == [alice],
    Inv0b = [alice],                                % (the literal keeps the call types of the analysis typed)
    invest(bob, 1000, Inv0b, Inv1, B0, B1),
    Inv1 == [alice, bob],
    Inv1b = [alice, bob],                           % (the literal keeps the call types of the analysis typed)
    invest(carol, 2000, Inv1b, _, B1, B2),
    balance(alice, B2, A),
    balance(bob, B2, Bo),
    balance(carol, B2, C),
    balance(this, B2, T).
