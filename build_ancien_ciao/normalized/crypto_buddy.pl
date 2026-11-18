get_tok_bal(A, B, C) :-
    loop_aux_1(B, A, 0, C).
get_allow(A, B, C, D) :-
    loop_aux_2(C, A, B, 0, D).
init(A, B, _, A, [tb(B, 1000)], []).
approve(A, B, C, D, E, F, D, E, [al(C, A, B)|F]).
transferFrom(A, B, C, D, E, F, G, H_1, H_2, H_3) :-
    get_allow(A, D, G, I),
    get_tok_bal(A, F, J),
    aux_cond_1(I, C, J, A, D, G, F, B, H_1, H_2, H_3, E, E, F, G).
aux_cond_1(A, B, C, D, E, F, G, H, I, [tb(H, J), tb(D, K)|G], [al(D, E, L)|F], I, _, _, _) :-
    A>=B,
    C>=B,
    !,
    M is A-B,
    L is M,
    N is C-B,
    K is N,
    get_tok_bal(H, [tb(D, K)|G], O),
    P is O+B,
    J is P.
aux_cond_1(_, _, _, _, _, _, _, _, A_1, A_2, A_3, _, A_1, A_2, A_3).
token_transfer(A, B, C, D, E, F, G_1, G_2, G_3) :-
    get_tok_bal(C, E, H),
    aux_cond_2(H, B, C, E, A, G_1, G_2, G_3, D, F, D, E, F).
aux_cond_2(A, B, C, D, E, F, [tb(E, G), tb(C, H)|D], I, F, I, _, _, _) :-
    A>=B,
    !,
    J is A-B,
    H is J,
    get_tok_bal(E, [tb(C, H)|D], K),
    L is K+B,
    G is L.
aux_cond_2(_, _, _, _, _, A_1, A_2, A_3, _, _, A_1, A_2, A_3).
goal([A, B, C, D]) :-
    init(btk, alice, _, E_1, E_2, E_3),
    approve(bob, 300, alice, E_1, E_2, E_3, F_1, F_2, F_3),
    transferFrom(alice, charlie, 200, bob, F_1, F_2, F_3, G_1, G_2, G_3),
    token_transfer(dave, 100, alice, G_1, G_2, G_3, _, H, _),
    get_tok_bal(alice, H, A),
    get_tok_bal(bob, H, B),
    get_tok_bal(charlie, H, C),
    get_tok_bal(dave, H, D).
loop_aux_1([], _, A, A).
loop_aux_1([tb(A, B)|C], D, E, F) :-
    aux_cond_3(A, D, E, G, B),
    loop_aux_1(C, D, G, F).
aux_cond_3(A, A, 0, B, B) :-
    !.
aux_cond_3(_, _, A, A, _).
loop_aux_2([], _, _, A, A).
loop_aux_2([al(A, B, C)|D], E, F, G, H) :-
    aux_cond_4(A, E, B, F, G, I, C),
    loop_aux_2(D, E, F, I, H).
aux_cond_4(A, A, B, B, 0, C, C) :-
    !.
aux_cond_4(_, _, _, _, A, A, _).
