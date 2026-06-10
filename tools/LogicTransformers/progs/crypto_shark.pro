get_owner(A, B, C) :-
    loop_aux_1(B, A, null, C).
get_nft_bal(A, B, C) :-
    loop_aux_2(B, A, 0, C).
get_appr(A, B, C) :-
    loop_aux_3(B, A, null, C).
get_op_appr(A, B, C, D) :-
    loop_aux_4(C, B, A, 0, D).
init(A, B, _, shark_state(A, B, [], [], [], [])).
mint(A, B, shark_state(C, D, E, F, G, H), I) :-
    get_owner(B, E, J),
    aux_cond_1(J,
               B,
               A,
               E,
               F,
               I,
               C,
               D,
               G,
               H,
               shark_state(C, D, E, F, G, H)).
aux_cond_1(null, A, B, C, D, shark_state(E, F, [t_o(A, B)|C], [n_b(B, G)|D], H, I), E, F, H, I, _) :-
    !,
    get_nft_bal(B, D, J),
    K is J+1,
    G is K.
aux_cond_1(_, _, _, _, _, A, _, _, _, _, A).
approve(A, B, C, shark_state(D, E, F, G, H, I), J) :-
    get_owner(B, F, K),
    aux_cond_2(C,
               K,
               B,
               A,
               H,
               J,
               D,
               E,
               F,
               G,
               I,
               shark_state(D, E, F, G, H, I)).
aux_cond_2(A, A, B, C, D, shark_state(E, F, G, H, [app(B, C)|D], I), E, F, G, H, I, _) :-
    !.
aux_cond_2(_, _, _, _, _, A, _, _, _, _, _, A).
setApprovalForAll(A, B, C, shark_state(D, E, F, G, H, I), shark_state(D, E, F, G, H, [op(C, A, B)|I])).
transferFrom(A, B, C, D, shark_state(E, F, G, H, I, J), K) :-
    get_owner(C, G, L),
    aux_cond_3(L,
               A,
               C,
               I,
               D,
               J,
               H,
               B,
               G,
               K,
               E,
               F,
               shark_state(E, F, G, H, I, J)).
aux_cond_3(A, A, B, C, D, E, F, G, H, I, J, K, L) :-
    !,
    get_appr(B, C, M),
    get_op_appr(A, D, E, N),
    aux_cond_4(D,
               A,
               M,
               N,
               B,
               C,
               A,
               F,
               G,
               H,
               I,
               J,
               K,
               E,
               L).
aux_cond_3(_, _, _, _, _, _, _, _, _, A, _, _, A).
aux_cond_4(A, B, C, D, E, F, G, H, I, J, shark_state(K, L, [t_o(E, I)|J], [n_b(I, M), n_b(G, N)|H], [app(E, null)|F], O), K, L, O, _) :-
    aux_cond_5(A, B, C, D),
    !,
    get_nft_bal(G, H, P),
    Q is P-1,
    N is Q,
    get_nft_bal(I, [n_b(G, N)|H], R),
    S is R+1,
    M is S.
aux_cond_4(_, _, _, _, _, _, _, _, _, _, A, _, _, _, A).
aux_cond_5(A, A, _, _).
aux_cond_5(A, _, B, C) :-
    aux_cond_6(B, A, C).
aux_cond_6(A, A, _).
aux_cond_6(_, _, 1).
goal([A, B, C]) :-
    init(shark, s, _, D),
    mint(alice, 1, D, E),
    approve(bob, 1, alice, E, F),
    transferFrom(alice,
                 charlie,
                 1,
                 bob,
                 F,
                 shark_state(_, _, G, H, _, _)),
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
