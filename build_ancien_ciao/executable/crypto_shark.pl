get_owner(A, B, C) :-
    aux_disj_11(null, C, _, _, B, A).
aux_disj_11(A, B, _, C, D, E) :-
    aux_disj_12(A, B, D, C, E).
aux_disj_12(A, B, [t_o(C, D)|E], F, G) :-
    !,
    aux_disj_13(G, A, C, D, H),
    aux_disj_12(H, B, E, F, G).
aux_disj_12(A, A, B, B, _).
aux_disj_13(A, null, A, B, B) :-
    !.
aux_disj_13(_, A, _, _, A).
get_nft_bal(A, B, C) :-
    aux_disj_5(0, C, _, _, B, A).
aux_disj_5(A, B, _, C, D, E) :-
    aux_disj_6(A, B, D, C, E).
aux_disj_6(A, B, [n_b(C, D)|E], F, G) :-
    !,
    aux_disj_7(G, A, C, D, H),
    aux_disj_6(H, B, E, F, G).
aux_disj_6(A, A, B, B, _).
aux_disj_7(A, 0, A, B, B) :-
    !.
aux_disj_7(_, A, _, _, A).
get_appr(A, B, C) :-
    aux_disj_2(null, C, _, _, B, A).
aux_disj_2(A, B, _, C, D, E) :-
    aux_disj_3(A, B, D, C, E).
aux_disj_3(A, B, [app(C, D)|E], F, G) :-
    !,
    aux_disj_4(G, A, C, D, H),
    aux_disj_3(H, B, E, F, G).
aux_disj_3(A, A, B, B, _).
aux_disj_4(A, null, A, B, B) :-
    !.
aux_disj_4(_, A, _, _, A).
get_op_appr(A, B, C, D) :-
    aux_disj_8(0, D, _, _, C, A, B).
aux_disj_8(A, B, _, C, D, E, F) :-
    aux_disj_9(A, B, D, C, E, F).
aux_disj_9(A, B, [op(C, D, E)|F], G, H, I) :-
    !,
    aux_disj_10(H, I, A, C, D, E, J),
    aux_disj_9(J, B, F, G, H, I).
aux_disj_9(A, A, B, B, _, _).
aux_disj_10(A, B, 0, A, B, C, C) :-
    !.
aux_disj_10(_, _, A, _, _, _, A).
init(A, B, _, state(A, B, [], [], [], [])).
mint(A, B, state(C, D, E, F, G, H), I) :-
    get_owner(B, E, J),
    aux_disj_14(A,
                B,
                state(C, D, E, F, G, H),
                I,
                C,
                D,
                E,
                F,
                G,
                H,
                J).
aux_disj_14(A, B, _, state(C, D, [t_o(B, A)|E], [n_b(A, F)|G], H, I), C, D, E, G, H, I, null) :-
    !,
    get_nft_bal(A, G, J),
    K is J+1,
    F is K.
aux_disj_14(_, _, A, A, _, _, _, _, _, _, _).
approve(A, B, C, state(D, E, F, G, H, I), J) :-
    get_owner(B, F, K),
    aux_disj_1(A,
               B,
               C,
               state(D, E, F, G, H, I),
               J,
               D,
               E,
               F,
               G,
               H,
               I,
               K).
aux_disj_1(A, B, C, _, state(D, E, F, G, [app(B, A)|H], I), D, E, F, G, H, I, C) :-
    !.
aux_disj_1(_, _, _, A, A, _, _, _, _, _, _, _).
setApprovalForAll(A, B, C, state(D, E, F, G, H, I), state(D, E, F, G, H, [op(C, A, B)|I])).
transferFrom(A, B, C, D, state(E, F, G, H, I, J), K) :-
    get_owner(C, G, L),
    aux_disj_15(A,
                B,
                C,
                D,
                state(E, F, G, H, I, J),
                K,
                E,
                F,
                G,
                H,
                I,
                J,
                L).
aux_disj_15(A, B, C, D, E, F, G, H, I, J, K, L, A) :-
    !,
    get_appr(C, K, M),
    get_op_appr(A, D, L, N),
    aux_disj_16(A,
                B,
                C,
                D,
                E,
                F,
                G,
                H,
                I,
                J,
                K,
                L,
                A,
                M,
                N).
aux_disj_15(_, _, _, _, A, A, _, _, _, _, _, _, _).
aux_disj_16(A, B, C, D, _, state(E, F, [t_o(C, B)|G], [n_b(B, H), n_b(A, I)|J], [app(C, null)|K], L), E, F, G, J, K, L, M, N, O) :-
    aux_disj_17(D, M, N, O),
    !,
    get_nft_bal(A, J, P),
    Q is P-1,
    I is Q,
    get_nft_bal(B, [n_b(A, I)|J], R),
    S is R+1,
    H is S.
aux_disj_16(_, _, _, _, A, A, _, _, _, _, _, _, _, _, _).
aux_disj_17(A, A, _, _).
aux_disj_17(A, _, A, _).
aux_disj_17(_, _, _, 1).
goal([A, B, C]) :-
    init(shark, s, _, D),
    mint(alice, 1, D, E),
    approve(bob, 1, alice, E, F),
    setApprovalForAll(dave, 1, alice, F, G),
    transferFrom(alice,
                 charlie,
                 1,
                 bob,
                 G,
                 state(_, _, H, I, _, _)),
    get_owner(1, H, A),
    get_nft_bal(alice, I, B),
    get_nft_bal(charlie, I, C).
