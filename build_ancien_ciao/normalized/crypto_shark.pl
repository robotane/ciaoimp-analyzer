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
goal([A, B, C]) :-
    init(shark, s, _, D_1, D_2, D_3, D_4, D_5, D_6),
    mint(alice, 1, D_1, D_2, D_3, D_4, D_5, D_6, E_1, E_2, E_3, E_4, E_5, E_6),
    approve(bob, 1, alice, E_1, E_2, E_3, E_4, E_5, E_6, F_1, F_2, F_3, F_4, F_5, F_6),
    transferFrom(alice, charlie, 1, bob, F_1, F_2, F_3, F_4, F_5, F_6, _, _, G, H, _, _),
    get_owner(1, G, A),
    get_nft_bal(alice, H, B),
    get_nft_bal(charlie, H, C).
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
