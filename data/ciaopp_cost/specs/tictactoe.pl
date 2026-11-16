% CiaoPP cost spec of tictactoe (build/executable/tictactoe.pl). Besides the
% balance primitives, get_board/3 reads the board: one gas per cell scanned
% (its loop does not stop at the first match), as get_bal/3.

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

:- trust pred get_board(Pos, Board, Cell)
   + ( not_fails, is_det, cost(lb, gas, length(Board)), cost(ub, gas, length(Board)) ).

:- entry init(P1, P2, Bet, S0, S, B1, B2) :
    (atm(P1), atm(P2), nnegint(Bet), var(S0), var(S), balances(B1), var(B2)).
% inf upper bound of play/6: the cost depends on length(Board), a list
% inside the state, which the analysis measures by term size only.
:- entry play(Pos, Caller, S1, S2, B1, B2) :
    (int(Pos), atm(Caller), gamestate(S1), var(S2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
