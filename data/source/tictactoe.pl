% TicTacToe : deux joueurs s'affrontent sur une grille 3x3.
% Le gagnant remporte le dépôt de l'adversaire.
% Etat : state(Cross, Circle, Tour, Gagnant, Board)
:- module(_, [goal/1], [fsyntax, statevars, hiord, loops]).
:- fun_eval arith(true).

% --- Infrastructure Blockchain ---

:- fun_eval get_bal/2.
get_bal(Addr, B) := Result :-
    Result := 0,
    for (Entry in list(B)) {
        Entry = bal(A, Val),
        if (A == Addr) { Result := Val }
    }.

set_bal(Addr, NewVal, !B) :-
    Acc := [],
    for (Entry in list(B)) {
        Entry = bal(A, V),
        if (A == Addr) {
            Acc := [bal(Addr, NewVal) | Acc]
        } else {
            Acc := [bal(A, V) | Acc]
        }
    },
    B := Acc.

transfer(From, To, Amount, !B) :-
    FB is ~get_bal(From, B),
    NewFB is FB - Amount,
    set_bal(From, NewFB, !B),
    TB is ~get_bal(To, B),
    NewTB is TB + Amount,
    set_bal(To, NewTB, !B).

% --- Helpers ---

get_board(Idx, Board, Res) :-
    Res := 0,
    for (Entry in list(Board)) {
        Entry = cell(I, V),
        if (I == Idx, Res == 0) { Res := V }
    }.

check_winner(Board, Winner) :-
    get_board(1, Board, B1), get_board(2, Board, B2), get_board(3, Board, B3),
    get_board(4, Board, B4), get_board(5, Board, B5), get_board(6, Board, B6),
    get_board(7, Board, B7), get_board(8, Board, B8), get_board(9, Board, B9),
    (   B1 =:= 1, B2 =:= 1, B3 =:= 1 -> Winner = 1
    ;   B4 =:= 1, B5 =:= 1, B6 =:= 1 -> Winner = 1
    ;   B7 =:= 1, B8 =:= 1, B9 =:= 1 -> Winner = 1
    ;   B1 =:= 1, B4 =:= 1, B7 =:= 1 -> Winner = 1
    ;   B2 =:= 1, B5 =:= 1, B8 =:= 1 -> Winner = 1
    ;   B3 =:= 1, B6 =:= 1, B9 =:= 1 -> Winner = 1
    ;   B1 =:= 1, B5 =:= 1, B9 =:= 1 -> Winner = 1
    ;   B3 =:= 1, B5 =:= 1, B7 =:= 1 -> Winner = 1
    ;   B1 =:= 2, B2 =:= 2, B3 =:= 2 -> Winner = 2
    ;   B4 =:= 2, B5 =:= 2, B6 =:= 2 -> Winner = 2
    ;   B7 =:= 2, B8 =:= 2, B9 =:= 2 -> Winner = 2
    ;   B1 =:= 2, B4 =:= 2, B7 =:= 2 -> Winner = 2
    ;   B2 =:= 2, B5 =:= 2, B8 =:= 2 -> Winner = 2
    ;   B3 =:= 2, B6 =:= 2, B9 =:= 2 -> Winner = 2
    ;   B1 =:= 2, B5 =:= 2, B9 =:= 2 -> Winner = 2
    ;   B3 =:= 2, B5 =:= 2, B7 =:= 2 -> Winner = 2
    ;   Winner = 0
    ).

% --- Contrat ---
% Les joueurs misent chacun 100 ETH en début de partie.

init(Cross, Circle, Bet, !S, !B) :-
    transfer(Cross,  this, Bet, !B),
    transfer(Circle, this, Bet, !B),
    S := state(Cross, Circle, 1, 0, []).

play(Pos, Caller, !S, !B) :-
    state(Cross, Circle, Turn, Winner, Board) = S,
    get_board(Pos, Board, CellVal),
    if (Winner == 0, CellVal == 0, Pos >= 1, Pos =< 9) {
        if (Turn == 1, Caller == Cross) {
            Board1 := [cell(Pos, 1) | Board],
            check_winner(Board1, NewWinner),
            if (NewWinner == 1) { transfer(this, Cross, 200, !B) },
            S := state(Cross, Circle, 2, NewWinner, Board1)
        },
        if (Turn == 2, Caller == Circle) {
            Board1 := [cell(Pos, 2) | Board],
            check_winner(Board1, NewWinner),
            if (NewWinner == 2) { transfer(this, Circle, 200, !B) },
            S := state(Cross, Circle, 1, NewWinner, Board1)
        }
    }.

% --- Test ---
% Scenario : alice (X) vs bob (O), mise 100 chacun.
%   alice joue 1,5,9 (diagonale) -> alice gagne.
% Attendu : alice=1100, bob=900, this=0

goal(Results) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(this, 0)],
    init(alice, bob, 100, _, S1, B0, B1),
    play(1, alice, S1, S2, B1, B2),
    play(2, bob,   S2, S3, B2, B3),
    play(5, alice, S3, S4, B3, B4),
    play(3, bob,   S4, S5, B4, B5),
    play(9, alice, S5, _S6, B5, B6),
    AliceBal is ~get_bal(alice, B6),
    BobBal   is ~get_bal(bob,   B6),
    ThisBal  is ~get_bal(this,  B6),
    Results = [AliceBal, BobBal, ThisBal].
