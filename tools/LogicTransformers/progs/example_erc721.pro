get_owner(A, B, C) :-
    loop_aux_1(B, A, null, C).
get_nft_bal(A, B, C) :-
    loop_aux_2(B, A, 0, C).
init(A, B, _, erc721_state(A, B, [], [])).
mint(A, B, erc721_state(C, D, E, F), G) :-
    get_owner(B, E, H),
    aux_cond_1(H,
               B,
               A,
               E,
               F,
               G,
               C,
               D,
               erc721_state(C, D, E, F)).
aux_cond_1(null, A, B, C, D, erc721_state(E, F, [t_o(A, B)|C], [n_b(B, G)|D]), E, F, _) :-
    !,
    get_nft_bal(B, D, H),
    I is H+1,
    G is I.
aux_cond_1(_, _, _, _, _, A, _, _, A).
transferFrom(A, B, C, D, erc721_state(E, F, G, H), I) :-
    get_owner(C, G, J),
    aux_cond_2(J,
               A,
               D,
               H,
               B,
               C,
               G,
               I,
               E,
               F,
               erc721_state(E, F, G, H)).
aux_cond_2(A, A, A, B, C, D, E, erc721_state(F, G, [t_o(D, C)|E], [n_b(C, H), n_b(A, I)|B]), F, G, _) :-
    !,
    get_nft_bal(A, B, J),
    K is J-1,
    I is K,
    get_nft_bal(C, [n_b(A, I)|B], L),
    M is L+1,
    H is M.
aux_cond_2(_, _, _, _, _, _, _, A, _, _, A).
goal([A, B, C, D]) :-
    init(nft, n, _, E),
    mint(alice, 1, E, F),
    mint(alice, 2, F, G),
    transferFrom(alice,
                 bob,
                 1,
                 alice,
                 G,
                 erc721_state(_, _, H, I)),
    get_owner(1, H, A),
    get_owner(2, H, B),
    get_nft_bal(alice, I, C),
    get_nft_bal(bob, I, D).
loop_aux_1([], _, A, A).
loop_aux_1([t_o(A, B)|C], D, E, F) :-
    aux_cond_3(A, D, E, G, B),
    loop_aux_1(C, D, G, F).
aux_cond_3(A, A, null, B, B) :-
    !.
aux_cond_3(_, _, A, A, _).
loop_aux_2([], _, A, A).
loop_aux_2([n_b(A, B)|C], D, E, F) :-
    aux_cond_4(A, D, E, G, B),
    loop_aux_2(C, D, G, F).
aux_cond_4(A, A, 0, B, B) :-
    !.
aux_cond_4(_, _, A, A, _).
