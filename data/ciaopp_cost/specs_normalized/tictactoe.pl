% CiaoPP cost spec of tictactoe on build/normalized/tictactoe.pl (the CasLog
% input: the fields of state(P1, P2, Turn, Winner, Board) are arguments).

:- module(_, [init/11, play/14, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% Board: list of cell(Position, Player), newest first.
:- regtype cells/1.
cells([]).
cells([cell(P, Pl)|T]) :- nnegint(P), nnegint(Pl), cells(T).

% init(P1, P2, Bet, S0, P1', P2', Turn', Winner', Board', B1, B2).
:- entry init(P1, P2, Bet, S0, Q1, Q2, T2, W2, Bd2, B1, B2) :
    (atm(P1), atm(P2), nnegint(Bet), var(S0), var(Q1), var(Q2), var(T2),
     var(W2), var(Bd2), balances(B1), var(B2)).
% play(Pos, Caller, P1, P2, Turn, Winner, Board, <5 fields out>, B1, B2).
:- entry play(Pos, Caller, P1, P2, Turn, Winner, Board, Q1, Q2, T2, W2, Bd2,
              B1, B2) :
    (int(Pos), atm(Caller), atm(P1), atm(P2), nnegint(Turn), nnegint(Winner),
     cells(Board), var(Q1), var(Q2), var(T2), var(W2), var(Bd2),
     balances(B1), var(B2)).
:- entry goal(R) : var(R).
