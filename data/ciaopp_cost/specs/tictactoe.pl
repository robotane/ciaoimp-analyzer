% CiaoPP cost spec of tictactoe (build/executable/tictactoe.pl). Besides the
% balance primitives, get_board/3 (blockchain.pl) reads the board; its cost,
% one gas per cell scanned, is in gas_model.pl.

:- module(_, [init/7, play/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Player1, Player2, Turn, Winner, Board); Board is a list of
% cell(Position, Player), newest first.
:- regtype cells/1.
cells([]).
cells([cell(P, Pl)|T]) :- nnegint(P), nnegint(Pl), cells(T).

:- regtype gamestate/1.
gamestate(state(P1, P2, Turn, Winner, Board)) :-
    atm(P1), atm(P2), nnegint(Turn), nnegint(Winner), cells(Board).


:- entry init(P1, P2, Bet, S0, S, B1, B2) :
    (atm(P1), atm(P2), nnegint(Bet), var(S0), var(S), balances(B1), var(B2)).
% inf upper bound of play/6: the cost depends on length(Board), a list
% inside the state, which the analysis measures by term size only.
:- entry play(Pos, Caller, S1, S2, B1, B2) :
    (int(Pos), atm(Caller), gamestate(S1), var(S2), balances(B1), var(B2)).
:- entry goal(R) : var(R).

% Inner entries (play/6 keeps its bound: the board is inside the state).
% play/6: aux_cond_1 is its body after the first get_board, with the board as
% an argument of its own (it calls check_winner on the board, 9 scans).
:- entry aux_cond_1(Winner, Cell, Pos, Turn, Caller, P1, Board, B1, P2, S1,
                    B2, S2) :
    (nnegint(Winner), nnegint(Cell), int(Pos), nnegint(Turn), atm(Caller),
     atm(P1), cells(Board), balances(B1), atm(P2), gamestate(S1), var(B2),
     var(S2)).
% play/6: check_winner/2 alone, 9 get_board over the list of cells.
:- entry check_winner(Board, Winner) : (cells(Board), var(Winner)).
