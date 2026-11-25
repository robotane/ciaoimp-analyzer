% Simple Ponzi (Java: io.hotmoka.examples.ponzi.SimplePonzi).
% A new investor must invest more than 110% of the current investment; the previous investor gets it all.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/2, invest/8, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- entry invest(Caller, Value, Last0, Last, Amt0, Amt, B0, B) :
    (atm(Caller), int(Value), atm(Last0), var(Last), int(Amt0), var(Amt),
     balances(B0), var(B)).

init(null, 0).

:- bigint_cost.  % gas of the BigInteger operations by bit length

:- payable(invest).

% @FromContract invest(amount)
invest(Caller, Value, !Last, !Amt, !B) :-
    big_mul(Amt, 11, Prod),
    big_div(Prod, 10, Min),
    require(big_gt(Value, Min)),
    if (Last \== null) {
        Held is Value + Amt,  % bound: first investment (<= Amt) plus Value
        transfer(this, Last, Value, !B),
        big_pay(Value, Held)
    },
    Last := Caller,
    Amt := Value.

% Test: alice invests 100, then bob 120. Expected [1020, 880, 100].
goal([A, Bo, T]) :-
    init(L0, A0),
    invest(alice, 100, L0, L1, A0, A1, [bal(alice, 1000), bal(bob, 1000), bal(this, 0)], B1),
    invest(bob, 120, L1, _, A1, _, B1, B2),
    balance(alice, B2, A),
    balance(bob, B2, Bo),
    balance(this, B2, T).
