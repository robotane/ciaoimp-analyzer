% Gradual Ponzi (Java: io.hotmoka.examples.ponzi.GradualPonzi).
% Each investment (at least 1000) is split equally among the previous investors, then the new one joins.
% Inv: investors, list of addresses. B: coin balances, list of bal(Address, Amount).

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
    Inv = ~list_add(Creator, []).

:- bigint_cost.  % gas of the BigInteger operations by bit length

:- payable(invest).

% @FromContract invest(amount)
invest(Caller, Amount, !Inv, !B) :-
    require(big_ge(Amount, 1000)),
    N = ~list_size(Inv),
    big_div(Amount, N, Each),
    Held is Amount + Amount,  % bound: amount received plus rests (< Amount)
    for (P in list(Inv)) {
        transfer(this, P, Each, !B),
        big_pay(Each, Held)
    },
    list_add(Caller, !Inv).

% Test: alice creates the contract; bob invests 1000, carol 2000. Expected [4000, 2000, 0, 0].
goal([A, Bo, C, T]) :-
    B0 = [bal(alice, 2000), bal(bob, 2000), bal(carol, 2000), bal(this, 0)],
    init(alice, Inv0),
    Inv0 == [alice],
    Inv0b = [alice],  % literal copy: keeps the call types
    invest(bob, 1000, Inv0b, Inv1, B0, B1),
    Inv1 == [alice, bob],
    Inv1b = [alice, bob],
    invest(carol, 2000, Inv1b, _, B1, B2),
    balance(alice, B2, A),
    balance(bob, B2, Bo),
    balance(carol, B2, C),
    balance(this, B2, T).
