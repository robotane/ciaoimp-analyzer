% Simple pyramid (Java: io.hotmoka.examples.ponzi.SimplePyramid).
% Each investment must be 10% above the previous one; it is split among the previous investors, then the new one joins.
% Inv: investors, list of addresses; Prev: previousInvestment. B: coin balances.

:- module(_, [init/3, invest/8, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- regtype addrs/1.
addrs([]).
addrs([A|T]) :- atm(A), addrs(T).

:- entry invest(Caller, Amount, Inv0, Inv, Prev0, Prev, B0, B) :
    (atm(Caller), int(Amount), addrs(Inv0), var(Inv),
     int(Prev0), var(Prev), balances(B0), var(B)).

% SimplePyramid(): the creator is the first investor
init(Creator, Inv, 1000) :-
    Inv = ~list_add(Creator, []).

:- payable(invest).

% @FromContract invest(amount)
invest(Caller, Amount, !Inv, !Prev, !B) :-
    Min = Prev * 11 // 10,
    require(Amount >= Min),
    N = ~list_size(Inv),
    Each = Amount // N,
    for (P in list(Inv)) {
        transfer(this, P, Each, !B)
    },
    list_add(Caller, !Inv),  % addFirst in Java
    Prev := Amount.

% Test: alice creates; bob invests 1100, carol 1210. Expected [3705, 1505, 790, 0].
goal([A, Bo, C, T]) :-
    B0 = [bal(alice, 2000), bal(bob, 2000), bal(carol, 2000), bal(this, 0)],
    init(alice, Inv0, P0),
    Inv0 == [alice],
    Inv0b = [alice],  % literal copy: keeps the call types
    invest(bob, 1100, Inv0b, Inv1, P0, P1, B0, B1),
    Inv1 == [alice, bob],
    Inv1b = [alice, bob],
    invest(carol, 1210, Inv1b, _, P1, _, B1, B2),
    balance(alice, B2, A),
    balance(bob, B2, Bo),
    balance(carol, B2, C),
    balance(this, B2, T).
