:- mode(get_bal/3, [+, +, -]).
:- measure(get_bal/3, [void, length, void]).

:- mode(set_bal/4, [+, +, +, -]).
:- measure(set_bal/4, [void, void, length, length]).

:- mode(transfer/5, [+, +, +, +, -]).
:- measure(transfer/5, [void, void, int, length, length]).

:- mode(init/11, [+, +, +, +, +, +, +, +, +, +, -]).
:- measure(init/11, [int, int, void, int, void, void, int, int, void, int, length]).

:- mode(bid/18, [+, +, +, +, +, +, +, +, +, +, -, -, -, -, -, -, +, -]).
:- measure(bid/18, [void, void, void, void, void, void, void, void, void, length, void, void, void, void, void, length, length, length]).

:- mode(aux_cond_1/24, [+, +, +, +, +, -, -, -, -, -, -, -, +, +, +, +, +, +, +, +, +, +, +, +]).
:- measure(aux_cond_1/24, [void, void, void, void, length, length, void, void, void, void, void, length, void, void, void, void, void, length, void, void, void, void, void, length]).

:- mode(reveal/19, [+, +, +, +, +, +, +, +, +, +, +, -, -, -, -, -, -, +, -]).
:- measure(reveal/19, [void, void, void, void, void, void, void, void, void, void, length, void, void, void, void, void, void, length, length]).

:- mode(aux_cond_2/25, [+, +, +, +, +, +, +, +, +, +, +, -, -, -, -, -, -, +, -, +, +, +, +, +, +]).
:- measure(aux_cond_2/25, [void, void, void, length, void, void, void, void, void, void, length, void, void, void, void, void, void, void, length, void, void, void, void, void, void]).

:- mode(aux_cond_3/27, [+, +, +, +, +, +, +, +, +, +, -, -, -, -, -, -, +, +, +, +, -, +, +, +, +, +, +]).
:- measure(aux_cond_3/27, [void, void, void, void, void, void, void, void, length, void, void, void, void, void, void, void, void, void, void, void, length, void, void, void, void, void, void]).

:- mode(aux_cond_4/18, [+, +, +, +, +, +, +, +, +, +, +, -, +, +, +, +, +, -]).
:- measure(aux_cond_4/18, [void, void, void, void, void, length, void, void, void, void, void, void, void, void, void, void, void, length]).

:- mode(aux_cond_5/4, [+, +, +, -]).
:- measure(aux_cond_5/4, [void, void, length, length]).

:- mode(aux_cond_6/4, [+, +, +, -]).
:- measure(aux_cond_6/4, [void, void, length, length]).

:- mode(auction_end/15, [+, +, +, +, +, +, +, -, -, -, -, -, -, +, -]).
:- measure(auction_end/15, [void, void, void, void, void, void, length, void, void, void, void, void, length, length, length]).

:- mode(aux_cond_7/20, [+, +, +, +, +, +, -, -, -, -, -, -, -, +, +, +, +, +, +, +]).
:- measure(aux_cond_7/20, [void, void, void, void, void, length, length, void, void, void, void, void, length, void, void, void, void, void, void, length]).

:- mode(aux_cond_8/5, [+, +, +, +, -]).
:- measure(aux_cond_8/5, [void, void, void, length, length]).

:- mode(loop_aux_1/4, [+, +, +, -]).
:- measure(loop_aux_1/4, [length, void, void, void]).

:- mode(aux_cond_9/5, [+, +, -, +, +]).
:- measure(aux_cond_9/5, [void, void, void, void, void]).

:- mode(loop_aux_2/4, [+, +, +, -]).
:- measure(loop_aux_2/4, [length, void, void, length]).

:- mode(aux_cond_10/5, [+, +, -, +, +]).
:- measure(aux_cond_10/5, [void, void, void, void, void]).

:- mode(loop_aux_3/10, [+, +, +, -, +, +, -, +, +, -]).
:- measure(loop_aux_3/10, [length, void, void, void, void, void, length, void, void, void]).

:- mode(aux_cond_11/13, [+, +, +, -, -, +, -, +, +, +, -, +, +]).
:- measure(aux_cond_11/13, [void, void, void, void, void, void, void, void, length, void, length, void, void]).

:- mode(neq/2, [+, +]).
:- measure(neq/2, [void, void]).


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
init(A, B, C, D, _, C, E, F, null, 0, []) :-
    G is D+A,
    E is G,
    H is E+B,
    F is H.
bid(A, B, C, D, E, F, G, H, I, J, K_1, K_2, K_3, K_4, K_5, K_6, L, M) :-
    aux_cond_1(C, F, A, B, L, M, K_1, K_2, K_3, K_4, K_5, K_6, E, G, H, I, D, J, E, F, G, H, I, J).
aux_cond_1(A, B, C, D, E, F, G, B, H, I, J, [bid(C, K, D)|L], G, H, I, J, K, L, _, _, _, _, _, _) :-
    A<B,
    !,
    transfer(C, this, D, E, F).
aux_cond_1(_, _, _, _, A, A, B_1, B_2, B_3, B_4, B_5, B_6, _, _, _, _, _, _, B_1, B_2, B_3, B_4, B_5, B_6).
reveal(A, B, C, D, E, F, G, H, I, J, K, L_1, L_2, L_3, L_4, L_5, L_6, M, N) :-
    aux_cond_2(B, G, H, K, A, C, E, D, J, I, M, L_1, L_2, L_3, L_4, L_5, L_6, F, N, F, G, H, I, J, K).
aux_cond_2(A, B, C, D, E, F, G, H, I, J, K, L_1, L_2, L_3, L_4, L_5, L_6, M, N, O_1, O_2, O_3, O_4, O_5, O_6) :-
    A>=B,
    A<C,
    !,
    loop_aux_3(D, E, =, 0, null, 0, P, Q, R, S),
    aux_cond_3(Q, R, F, G, S, H, I, J, K, E, L_1, L_2, L_3, L_4, L_5, L_6, M, B, C, P, N, O_1, O_2, O_3, O_4, O_5, O_6).
aux_cond_2(_, _, _, _, _, _, _, _, _, _, A, B_1, B_2, B_3, B_4, B_5, B_6, _, A, B_1, B_2, B_3, B_4, B_5, B_6).
aux_cond_3(1, A, A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5, I_6, J, K, L, M, N, _, _, _, _, _, _) :-
    !,
    aux_cond_4(B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5, I_6, J, K, L, M, N).
aux_cond_3(_, _, _, _, _, _, _, _, A, _, B_1, B_2, B_3, B_4, B_5, B_6, _, _, _, _, A, B_1, B_2, B_3, B_4, B_5, B_6).
aux_cond_4(0, A, B, C, D, E, F, G, H, I, F, B, J, G, H, I, J, K) :-
    A>=B,
    B>C,
    !,
    aux_cond_5(D, C, E, L),
    M is A-B,
    N is M,
    aux_cond_6(N, F, L, K).
aux_cond_4(_, A, _, B, C, D, E, F, G, H, C, B, I, F, G, H, I, J) :-
    transfer(this, E, A, D, J).
aux_cond_5(A, B, C, D) :-
    neq(A, null),
    !,
    transfer(this, A, B, C, D).
aux_cond_5(_, _, A, A).
aux_cond_6(A, B, C, D) :-
    A>0,
    !,
    transfer(this, B, A, C, D).
aux_cond_6(_, _, A, A).
auction_end(A, B, C, D, E, F, G, H_1, H_2, H_3, H_4, H_5, H_6, I, J) :-
    aux_cond_7(A, D, E, B, F, I, J, H_1, H_2, H_3, H_4, H_5, H_6, C, B, C, D, E, F, G).
aux_cond_7(A, B, C, D, E, F, G, D, H, B, C, E, [], H, _, _, _, _, _, _) :-
    A>=B,
    !,
    aux_cond_8(C, D, E, F, G).
aux_cond_7(_, _, _, _, _, A, A, B_1, B_2, B_3, B_4, B_5, B_6, _, B_1, B_2, B_3, B_4, B_5, B_6).
aux_cond_8(A, B, C, D, E) :-
    neq(A, null),
    !,
    transfer(this, B, C, D, E).
aux_cond_8(_, _, _, A, A).
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_9(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_9(A, A, B, B, _) :-
    !.
aux_cond_9(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, [Elem_1|F]) :-
    aux_cond_10(A, D, Elem_1, E, B),
    loop_aux_2(C, D, E, F).
aux_cond_10(A, A, bal(A, B), B, _) :-
    !.
aux_cond_10(A, _, bal(A, B), _, B).
loop_aux_3([], _, _, A, B, C, [], A, B, C).
loop_aux_3([bid(A, B, C)|D], E, F, G, H, I, J, K, L, M) :-
    aux_cond_11(A, E, G, N, O, B, P, C, J, bid(A, B, C), Q, H, I),
    loop_aux_3(D, E, F, N, O, P, Q, K, L, M).
aux_cond_11(A, A, 0, 1, B, B, C, C, _, _, _, _, _) :-
    !.
aux_cond_11(_, _, A, A, B, _, C, _, [D|E], D, E, B, C).
neq(A, B) :-
    A\==B.