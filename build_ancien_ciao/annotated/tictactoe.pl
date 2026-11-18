:- mode(get_bal/3, [+, +, -]).
:- measure(get_bal/3, [void, length, void]).

:- mode(set_bal/4, [+, +, +, -]).
:- measure(set_bal/4, [void, void, length, length]).

:- mode(transfer/5, [+, +, +, +, -]).
:- measure(transfer/5, [void, void, int, length, length]).

:- mode(get_board/3, [+, +, -]).
:- measure(get_board/3, [void, length, void]).

:- mode(check_winner/2, [+, -]).
:- measure(check_winner/2, [length, int]).

:- mode(aux_disj_1/10, [-, +, +, +, +, +, +, +, +, +]).
:- measure(aux_disj_1/10, [int, int, int, int, int, int, int, int, int, int]).

:- mode(init/11, [+, +, +, +, +, +, +, +, +, +, -]).
:- measure(init/11, [void, void, int, void, void, void, int, int, length, length, length]).

:- mode(play/14, [+, +, +, +, +, +, +, -, -, -, -, -, +, -]).
:- measure(play/14, [void, void, void, void, void, void, length, void, void, void, void, length, length, length]).

:- mode(aux_cond_1/20, [+, +, +, +, +, +, +, +, +, +, +, +, +, +, -, -, -, -, -, -]).
:- measure(aux_cond_1/20, [void, void, void, void, void, void, length, length, void, void, void, void, void, length, length, void, void, void, void, length]).

:- mode(aux_cond_2/20, [+, +, +, +, +, +, -, +, -, -, -, -, -, -, +, +, +, +, +, +]).
:- measure(aux_cond_2/20, [void, void, void, length, void, length, void, length, length, void, void, void, void, length, void, void, void, void, void, length]).

:- mode(aux_cond_3/4, [+, +, +, -]).
:- measure(aux_cond_3/4, [void, void, length, length]).

:- mode(aux_cond_4/20, [+, +, +, +, +, -, +, -, -, -, -, -, -, +, +, +, +, +, +, +]).
:- measure(aux_cond_4/20, [void, void, void, void, length, void, length, length, void, void, void, void, length, void, void, void, void, void, length, void]).

:- mode(aux_cond_5/4, [+, +, +, -]).
:- measure(aux_cond_5/4, [void, void, length, length]).

:- mode(loop_aux_1/4, [+, +, +, -]).
:- measure(loop_aux_1/4, [length, void, void, void]).

:- mode(aux_cond_6/5, [+, +, -, +, +]).
:- measure(aux_cond_6/5, [void, void, void, void, void]).

:- mode(loop_aux_2/4, [+, +, +, -]).
:- measure(loop_aux_2/4, [length, void, void, length]).

:- mode(aux_cond_7/5, [+, +, -, +, +]).
:- measure(aux_cond_7/5, [void, void, void, void, void]).

:- mode(loop_aux_3/4, [+, +, +, -]).
:- measure(loop_aux_3/4, [length, void, void, void]).

:- mode(aux_cond_8/5, [+, +, +, -, +]).
:- measure(aux_cond_8/5, [void, void, void, void, void]).


get_bal(A, B, C) :-
    loop_aux_1(B, A, 0, C).
set_bal(A, B, C, D) :-
    loop_aux_2(C, A, B, D).
transfer(A, B, C, D, E) :-
    get_bal(A, D, F),
    G is F,
    H is G-C,
    I is H,
    set_bal(A, I, D, J),
    get_bal(B, J, K),
    L is K,
    M is L+C,
    N is M,
    set_bal(B, N, J, E).
get_board(A, B, C) :-
    loop_aux_3(B, A, 0, C).
check_winner(A, B) :-
    get_board(1, A, C),
    get_board(2, A, D),
    get_board(3, A, E),
    get_board(4, A, F),
    get_board(5, A, G),
    get_board(6, A, H),
    get_board(7, A, I),
    get_board(8, A, J),
    get_board(9, A, K),
    aux_disj_1(B, C, D, E, F, G, H, I, J, K).
aux_disj_1(1, A, B, C, _, _, _, _, _, _) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, _, _, _, A, B, C, _, _, _) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, _, _, _, _, _, _, A, B, C) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, A, _, _, B, _, _, C, _, _) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, _, A, _, _, B, _, _, C, _) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, _, _, A, _, _, B, _, _, C) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, A, _, _, _, B, _, _, _, C) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, _, _, A, _, B, _, C, _, _) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(2, A, B, C, _, _, _, _, _, _) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, _, _, _, A, B, C, _, _, _) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, _, _, _, _, _, _, A, B, C) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, A, _, _, B, _, _, C, _, _) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, _, A, _, _, B, _, _, C, _) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, _, _, A, _, _, B, _, _, C) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, A, _, _, _, B, _, _, _, C) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, _, _, A, _, B, _, C, _, _) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(0, _, _, _, _, _, _, _, _, _).
init(A, B, C, _, A, B, 1, 0, [], D, E) :-
    transfer(A, this, C, D, F),
    transfer(B, this, C, F, E).
play(A, B, C, D, E, F, G, H_1, H_2, H_3, H_4, H_5, I, J) :-
    get_board(A, G, K),
    aux_cond_1(F, K, A, E, B, C, G, I, D, C, D, E, F, G, J, H_1, H_2, H_3, H_4, H_5).
aux_cond_1(0, 0, A, B, C, D, E, F, G, H_1, H_2, H_3, H_4, H_5, I, J_1, J_2, J_3, J_4, J_5) :-
    A>=1,
    A=<9,
    !,
    aux_cond_2(B, C, D, K, A, E, L, F, M, N_1, N_2, N_3, N_4, N_5, G, H_1, H_2, H_3, H_4, H_5),
    aux_cond_4(B, C, G, A, E, L, M, I, J_1, J_2, J_3, J_4, J_5, D, N_1, N_2, N_3, N_4, N_5, K).
aux_cond_1(_, _, _, _, _, _, _, A, _, B_1, B_2, B_3, B_4, B_5, A, B_1, B_2, B_3, B_4, B_5).
aux_cond_2(1, A, A, [cell(B, 1)|C], B, C, D, E, F, A, G, 2, D, [cell(B, 1)|C], G, _, _, _, _, _) :-
    !,
    check_winner([cell(B, 1)|C], D),
    aux_cond_3(D, A, E, F).
aux_cond_2(_, _, _, _, _, _, _, A, A, B_1, B_2, B_3, B_4, B_5, _, B_1, B_2, B_3, B_4, B_5).
aux_cond_3(1, A, B, C) :-
    !,
    transfer(this, A, 200, B, C).
aux_cond_3(_, _, A, A).
aux_cond_4(2, A, A, B, C, D, E, F, G, A, 1, D, [cell(B, 2)|C], G, _, _, _, _, _, _) :-
    !,
    check_winner([cell(B, 2)|C], D),
    aux_cond_5(D, A, E, F).
aux_cond_4(_, _, _, _, _, _, A, A, B_1, B_2, B_3, B_4, B_5, _, B_1, B_2, B_3, B_4, B_5, _).
aux_cond_5(2, A, B, C) :-
    !,
    transfer(this, A, 200, B, C).
aux_cond_5(_, _, A, A).
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_6(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_6(A, A, B, B, _) :-
    !.
aux_cond_6(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, [Elem_1|F]) :-
    aux_cond_7(A, D, Elem_1, E, B),
    loop_aux_2(C, D, E, F).
aux_cond_7(A, A, bal(A, B), B, _) :-
    !.
aux_cond_7(A, _, bal(A, B), _, B).
loop_aux_3([], _, A, A).
loop_aux_3([cell(A, B)|C], D, E, F) :-
    aux_cond_8(A, D, E, G, B),
    loop_aux_3(C, D, G, F).
aux_cond_8(A, A, 0, B, B) :-
    !.
aux_cond_8(_, _, A, A, _).