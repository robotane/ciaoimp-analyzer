% Tic tac toe (Java: io.hotmoka.examples.tictactoe.TicTacToe).
% Two players put crosses and circles on a 3x3 board; bets; the winner gets 90% of the
% jackpot and the creator the rest; a draw gives everything to the creator.
% State: Cross, Circle = the players (null while not set); Turn (1 = cross, 2 = circle);
%        Over = gameOver (0/1); Board = StorageTreeArray<Tile>(9), list of 9 cells
%        (0 = empty, 1 = cross, 2 = circle); Creator (read only).
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

:- payable(play).                             % @Payable: the amount sent is received first

% @FromContract play(amount, x, y)
play(Caller, Amount, X, Y, Creator, !Cross, !Circle, !Turn, !Over, !Board, !B) :-
    Over =:= 0,                                     % require(!gameOver)
    X >= 1, X =< 3, Y >= 1, Y =< 3,                 % require(1 <= x && x <= 3 && 1 <= y && y <= 3)
    Idx is (Y - 1) * 3 + X - 1,
    arr_get(Idx, Board, Cell),                      % require(at(x, y) == EMPTY): board.get
    Cell =:= 0,
    if (Turn =:= 1) {                               % if (turn == CROSS)
        if (Cross == null) {
            Amount >= 100,                          % require(amount >= MINIMUM_BET)
            Cross := Caller                         % crossPlayer = player
        } else {
            Caller == Cross                         % require(player == crossPlayer)
        }
    } else {
        if (Circle == null) {
            Caller \== Cross,                       % require(crossPlayer != player)
            balance(this, B, Bal),                  % balance()
            Prev is Bal - Amount,                   % previousBet
            Amount >= Prev,                         % require(amount >= previousBet)
            Circle := Caller                        % circlePlayer = player
        } else {
            Caller == Circle                        % require(player == circlePlayer)
        }
    },
    arr_set(Idx, Turn, !Board),                     % set(x, y, turn): board.set
    game_over(X, Y, Turn, Board, Over1),            % isGameOver(x, y)
    Over := Over1,                                  % gameOver = ...
    if (Over1 =:= 1) {
        balance(this, B, Bal1),                     % balance()
        Win is Bal1 * 9 // 10,                      % 90% goes to the winner
        transfer(this, Caller, Win, !B),            % player.receive(...)
        balance(this, B, Bal2),                     % balance()
        transfer(this, Creator, Bal2, !B)           % creator.receive(balance())
    } else {
        is_full(Board, Full),                       % isDraw()
        if (Full =:= 1) {
            balance(this, B, Bal3),                 % balance()
            transfer(this, Creator, Bal3, !B)       % creator.receive(balance())
        } else {
            NT is 3 - Turn,
            Turn := NT                              % turn = turn.nextTurn()
        }
    }.

% isGameOver(x, y). Java evaluates its tests with short-circuit (at most 12 reads of the board);
% the 12 reads are all done here (an upper bound of every path: CiaoPP does not charge the reads
% of a test that fails half-way), then the tests are evaluated in the order of Java.
game_over(X, Y, T, B, Over) :-
    at(X, 1, B, A1), at(X, 2, B, A2), at(X, 3, B, A3),            % column x
    at(1, Y, B, R1), at(2, Y, B, R2), at(3, Y, B, R3),            % row y
    at(1, 1, B, D1), at(2, 2, B, D2), at(3, 3, B, D3),            % first diagonal
    at(1, 3, B, E1), at(2, 2, B, E2), at(3, 1, B, E3),            % second diagonal
    if ((A1 =:= T, A2 =:= T, A3 =:= T)) { Over = 1 }
    else if ((R1 =:= T, R2 =:= T, R3 =:= T)) { Over = 1 }
    else if ((X =:= Y, D1 =:= T, D2 =:= T, D3 =:= T)) { Over = 1 }
    else if ((X + Y =:= 4, E1 =:= T, E2 =:= T, E3 =:= T)) { Over = 1 }
    else { Over = 0 }.

% at(x, y)
at(X, Y, Board, V) :-
    I is (Y - 1) * 3 + X - 1,
    arr_get(I, Board, V).

% isDraw(): for (tile: board) if (tile == EMPTY) return false; the 9 reads of the loop over the
% constant-size board are written out, all done (CiaoPP has no bound for numeric loops).
is_full(B, Full) :-
    arr_get(0, B, V0), arr_get(1, B, V1), arr_get(2, B, V2),
    arr_get(3, B, V3), arr_get(4, B, V4), arr_get(5, B, V5),
    arr_get(6, B, V6), arr_get(7, B, V7), arr_get(8, B, V8),
    if ((V0 =\= 0, V1 =\= 0, V2 =\= 0, V3 =\= 0, V4 =\= 0, V5 =\= 0, V6 =\= 0, V7 =\= 0, V8 =\= 0)) {
        Full = 1
    } else { Full = 0 }.

% --- Test: alice (cross) bets 100, bob (circle) 100; alice plays (1,1), bob (2,1),
% alice (2,2), bob (3,1), alice (3,3): the diagonal ---
% Expected: [alice, bob, owner, this] = [1080, 900, 20, 0].
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
