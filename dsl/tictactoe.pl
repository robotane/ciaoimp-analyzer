% Tic tac toe (Java: io.hotmoka.examples.tictactoe.TicTacToe).
% Two players bet and play on a 3x3 board; the winner gets 90% of the jackpot, the creator the rest.
% Turn: 1 = cross, 2 = circle; Over: gameOver (0/1); Board: list of 9 cells (0 empty, 1 cross, 2 circle).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [play/17, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- regtype cells/1.
cells([]).
cells([C|T]) :- int(C), cells(T).

:- entry play(Caller, Amount, X, Y, Creator, Cross0, Cross, Circle0, Circle, Turn0, Turn, Over0, Over, Board0, Board, B0, B) :
    (atm(Caller), int(Amount), int(X), int(Y), atm(Creator), atm(Cross0), var(Cross),
     atm(Circle0), var(Circle), int(Turn0), var(Turn), int(Over0), var(Over),
     cells(Board0), var(Board), balances(B0), var(B)).

:- payable(play).

% @FromContract play(amount, x, y)
play(Caller, Amount, X, Y, Creator, !Cross, !Circle, !Turn, !Over, !Board, !B) :-
    require(Over =:= 0),
    require((X >= 1, X =< 3, Y >= 1, Y =< 3)),
    Idx is (Y - 1) * 3 + X - 1,
    Cell = ~arr_get(Idx, Board),
    require(Cell =:= 0),
    if (Turn =:= 1) {
        if (Cross == null) {
            require(Amount >= 100),
            Cross := Caller
        } else {
            require(Caller == Cross)
        }
    } else {
        if (Circle == null) {
            require(Caller \== Cross),
            Bal = ~balance(this, B),
            Prev is Bal - Amount,  % previousBet
            require(Amount >= Prev),
            Circle := Caller
        } else {
            require(Caller == Circle)
        }
    },
    arr_set(Idx, Turn, !Board),
    Over1 = ~game_over(X, Y, Turn, Board),
    Over := Over1,
    if (Over1 =:= 1) {
        Bal1 = ~balance(this, B),
        Win is Bal1 * 9 // 10,  % 90%
        transfer(this, Caller, Win, !B),
        Bal2 = ~balance(this, B),
        transfer(this, Creator, Bal2, !B)
    } else {
        Full = ~is_full(Board),
        if (Full =:= 1) {
            Bal3 = ~balance(this, B),
            transfer(this, Creator, Bal3, !B)
        } else {
            NT is 3 - Turn,
            Turn := NT
        }
    }.

% isGameOver(x, y). Java short-circuits (at most 12 reads); all 12 are done here, an upper bound
% of every path, then the tests run in Java's order.
game_over(X, Y, T, B, Over) :-
    A1 = ~at(X, 1, B), A2 = ~at(X, 2, B), A3 = ~at(X, 3, B),  % column x
    R1 = ~at(1, Y, B), R2 = ~at(2, Y, B), R3 = ~at(3, Y, B),  % row y
    D1 = ~at(1, 1, B), D2 = ~at(2, 2, B), D3 = ~at(3, 3, B),  % first diagonal
    E1 = ~at(1, 3, B), E2 = ~at(2, 2, B), E3 = ~at(3, 1, B),  % second diagonal
    if ((A1 =:= T, A2 =:= T, A3 =:= T)) { Over = 1 }
    else if ((R1 =:= T, R2 =:= T, R3 =:= T)) { Over = 1 }
    else if ((X =:= Y, D1 =:= T, D2 =:= T, D3 =:= T)) { Over = 1 }
    else if ((X + Y =:= 4, E1 =:= T, E2 =:= T, E3 =:= T)) { Over = 1 }
    else { Over = 0 }.

% at(x, y)
at(X, Y, Board, V) :-
    I is (Y - 1) * 3 + X - 1,
    V = ~arr_get(I, Board).

% isDraw(): the 9 reads of the loop are written out (CiaoPP has no bound for numeric loops).
is_full(B, Full) :-
    V0 = ~arr_get(0, B), V1 = ~arr_get(1, B), V2 = ~arr_get(2, B),
    V3 = ~arr_get(3, B), V4 = ~arr_get(4, B), V5 = ~arr_get(5, B),
    V6 = ~arr_get(6, B), V7 = ~arr_get(7, B), V8 = ~arr_get(8, B),
    if ((V0 =\= 0, V1 =\= 0, V2 =\= 0, V3 =\= 0, V4 =\= 0, V5 =\= 0, V6 =\= 0, V7 =\= 0, V8 =\= 0)) {
        Full = 1
    } else { Full = 0 }.

% Test: alice (cross) and bob (circle) bet 100; alice wins on the diagonal. Expected [1080, 900, 20, 0].
goal([A, Bo, O, T]) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(owner, 0), bal(this, 0)],
    Bd0 = [0, 0, 0, 0, 0, 0, 0, 0, 0],
    play(alice, 100, 1, 1, owner, null, C1, null, K1, 1, T1, 0, O1, Bd0, Bd1, B0, B1),
    play(bob, 100, 2, 1, owner, C1, C2, K1, K2, T1, T2, O1, O2, Bd1, Bd2, B1, B2),
    play(alice, 0, 2, 2, owner, C2, C3, K2, K3, T2, T3, O2, O3, Bd2, Bd3, B2, B3),
    play(bob, 0, 3, 1, owner, C3, C4, K3, K4, T3, T4, O3, O4, Bd3, Bd4, B3, B4),
    play(alice, 0, 3, 3, owner, C4, _, K4, _, T4, _, O4, _, Bd4, _, B4, B5),
    balance(alice, B5, A),
    balance(bob, B5, Bo),
    balance(owner, B5, O),
    balance(this, B5, T).
