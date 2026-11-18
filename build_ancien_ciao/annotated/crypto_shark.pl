:- mode(get_owner/3, [+, +, -]).
:- measure(get_owner/3, [void, length, void]).

:- mode(get_nft_bal/3, [+, +, -]).
:- measure(get_nft_bal/3, [void, length, void]).

:- mode(get_appr/3, [+, +, -]).
:- measure(get_appr/3, [void, length, void]).

:- mode(get_op_appr/4, [+, +, +, -]).
:- measure(get_op_appr/4, [void, void, length, void]).

:- mode(init/9, [+, +, +, +, +, +, +, +, -]).
:- measure(init/9, [void, void, void, void, void, length, length, length, length]).

:- mode(mint/14, [+, +, +, +, +, +, +, +, -, -, -, -, -, -]).
:- measure(mint/14, [void, void, void, void, length, length, void, void, void, void, length, length, void, void]).

:- mode(aux_cond_1/21, [+, +, +, +, +, -, -, -, -, -, -, +, +, +, +, +, +, +, +, +, +]).
:- measure(aux_cond_1/21, [void, void, void, length, length, void, void, length, length, void, void, void, void, void, void, void, void, length, length, void, void]).

:- mode(approve/15, [+, +, +, +, +, +, +, +, +, -, -, -, -, -, -]).
:- measure(approve/15, [void, void, void, void, void, length, void, length, void, void, void, void, void, length, void]).

:- mode(aux_cond_2/22, [+, +, +, +, +, -, -, -, -, -, -, +, +, +, +, +, +, +, +, +, +, +]).
:- measure(aux_cond_2/22, [void, void, void, void, length, void, void, void, void, length, void, void, void, void, void, void, void, void, void, void, length, void]).

:- mode(setApprovalForAll/15, [+, +, +, +, +, +, +, +, +, +, +, +, +, +, -]).
:- measure(setApprovalForAll/15, [void, void, void, void, void, void, void, void, length, void, void, void, void, void, length]).

:- mode(transferFrom/16, [+, +, +, -, +, +, +, +, +, +, -, -, -, -, -, -]).
:- measure(transferFrom/16, [void, void, void, void, void, void, length, length, length, length, void, void, length, length, length, void]).

:- mode(aux_cond_3/23, [+, +, +, +, -, +, +, +, +, -, -, -, -, -, -, +, +, +, +, +, +, +, +]).
:- measure(aux_cond_3/23, [void, void, void, length, void, length, length, void, length, void, void, length, length, length, void, void, void, void, void, length, length, length, void]).

:- mode(aux_cond_4/25, [-, +, +, -, +, +, +, +, +, +, -, -, -, -, -, -, +, +, +, +, +, +, +, +, +]).
:- measure(aux_cond_4/25, [void, void, void, void, void, length, void, length, void, length, void, void, length, length, length, void, void, void, void, void, void, length, length, length, void]).

:- mode(aux_cond_5/4, [-, +, +, -]).
:- measure(aux_cond_5/4, [void, void, void, void]).

:- mode(aux_cond_6/3, [+, +, -]).
:- measure(aux_cond_6/3, [void, void, void]).

:- mode(loop_aux_1/4, [+, +, +, -]).
:- measure(loop_aux_1/4, [length, void, void, void]).

:- mode(aux_cond_7/5, [+, +, +, -, +]).
:- measure(aux_cond_7/5, [void, void, void, void, void]).

:- mode(loop_aux_2/4, [+, +, +, -]).
:- measure(loop_aux_2/4, [length, void, void, void]).

:- mode(aux_cond_8/5, [+, +, +, -, +]).
:- measure(aux_cond_8/5, [void, void, void, void, void]).

:- mode(loop_aux_3/4, [+, +, +, -]).
:- measure(loop_aux_3/4, [length, void, void, void]).

:- mode(aux_cond_9/5, [+, +, +, -, +]).
:- measure(aux_cond_9/5, [void, void, void, void, void]).

:- mode(loop_aux_4/5, [+, +, +, +, -]).
:- measure(loop_aux_4/5, [length, void, void, void, void]).

:- mode(aux_cond_10/7, [+, +, +, +, +, -, +]).
:- measure(aux_cond_10/7, [void, void, void, void, void, void, void]).


get_owner(A, B, C) :-
    loop_aux_1(B, A, null, C).
get_nft_bal(A, B, C) :-
    loop_aux_2(B, A, 0, C).
get_appr(A, B, C) :-
    loop_aux_3(B, A, null, C).
get_op_appr(A, B, C, D) :-
    loop_aux_4(C, B, A, 0, D).
init(A, B, _, A, B, [], [], [], []).
mint(A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5, I_6) :-
    get_owner(B, E, J),
    aux_cond_1(J, B, A, E, F, I_1, I_2, I_3, I_4, I_5, I_6, C, D, G, H, C, D, E, F, G, H).
aux_cond_1(null, A, B, C, D, E, F, [t_o(A, B)|C], [n_b(B, G)|D], H, I, E, F, H, I, _, _, _, _, _, _) :-
    !,
    get_nft_bal(B, D, J),
    K is J+1,
    G is K.
aux_cond_1(_, _, _, _, _, A_1, A_2, A_3, A_4, A_5, A_6, _, _, _, _, A_1, A_2, A_3, A_4, A_5, A_6).
approve(A, B, C, D, E, F, G, H, I, J_1, J_2, J_3, J_4, J_5, J_6) :-
    get_owner(B, F, K),
    aux_cond_2(C, K, B, A, H, J_1, J_2, J_3, J_4, J_5, J_6, D, E, F, G, I, D, E, F, G, H, I).
aux_cond_2(A, A, B, C, D, E, F, G, H, [app(B, C)|D], I, E, F, G, H, I, _, _, _, _, _, _) :-
    !.
aux_cond_2(_, _, _, _, _, A_1, A_2, A_3, A_4, A_5, A_6, _, _, _, _, _, A_1, A_2, A_3, A_4, A_5, A_6).
setApprovalForAll(A, B, C, D, E, F, G, H, I, D, E, F, G, H, [op(C, A, B)|I]).
transferFrom(A, B, C, D, E, F, G, H, I, J, K_1, K_2, K_3, K_4, K_5, K_6) :-
    get_owner(C, G, L),
    aux_cond_3(L, A, C, I, D, J, H, B, G, K_1, K_2, K_3, K_4, K_5, K_6, E, F, E, F, G, H, I, J).
aux_cond_3(A, A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5, I_6, J, K, L_1, L_2, L_3, L_4, L_5, L_6) :-
    !,
    get_appr(B, C, M),
    get_op_appr(A, D, E, N),
    aux_cond_4(D, A, M, N, B, C, A, F, G, H, I_1, I_2, I_3, I_4, I_5, I_6, J, K, E, L_1, L_2, L_3, L_4, L_5, L_6).
aux_cond_3(_, _, _, _, _, _, _, _, _, A_1, A_2, A_3, A_4, A_5, A_6, _, _, A_1, A_2, A_3, A_4, A_5, A_6).
aux_cond_4(A, B, C, D, E, F, G, H, I, J, K, L, [t_o(E, I)|J], [n_b(I, M), n_b(G, N)|H], [app(E, null)|F], O, K, L, O, _, _, _, _, _, _) :-
    aux_cond_5(A, B, C, D),
    !,
    get_nft_bal(G, H, P),
    Q is P-1,
    N is Q,
    get_nft_bal(I, [n_b(G, N)|H], R),
    S is R+1,
    M is S.
aux_cond_4(_, _, _, _, _, _, _, _, _, _, A_1, A_2, A_3, A_4, A_5, A_6, _, _, _, A_1, A_2, A_3, A_4, A_5, A_6).
aux_cond_5(A, A, _, _).
aux_cond_5(A, _, B, C) :-
    aux_cond_6(B, A, C).
aux_cond_6(A, A, _).
aux_cond_6(_, _, 1).
loop_aux_1([], _, A, A).
loop_aux_1([t_o(A, B)|C], D, E, F) :-
    aux_cond_7(A, D, E, G, B),
    loop_aux_1(C, D, G, F).
aux_cond_7(A, A, null, B, B) :-
    !.
aux_cond_7(_, _, A, A, _).
loop_aux_2([], _, A, A).
loop_aux_2([n_b(A, B)|C], D, E, F) :-
    aux_cond_8(A, D, E, G, B),
    loop_aux_2(C, D, G, F).
aux_cond_8(A, A, 0, B, B) :-
    !.
aux_cond_8(_, _, A, A, _).
loop_aux_3([], _, A, A).
loop_aux_3([app(A, B)|C], D, E, F) :-
    aux_cond_9(A, D, E, G, B),
    loop_aux_3(C, D, G, F).
aux_cond_9(A, A, null, B, B) :-
    !.
aux_cond_9(_, _, A, A, _).
loop_aux_4([], _, _, A, A).
loop_aux_4([op(A, B, C)|D], E, F, G, H) :-
    aux_cond_10(A, F, B, E, G, I, C),
    loop_aux_4(D, E, F, I, H).
aux_cond_10(A, A, B, B, 0, C, C) :-
    !.
aux_cond_10(_, _, _, _, A, A, _).