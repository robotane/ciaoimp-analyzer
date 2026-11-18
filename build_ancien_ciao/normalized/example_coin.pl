get_tok_bal(A, B, C) :-
    loop_aux_1(B, A, 0, C).
init(A, B, C, _, A, B, C, 1000000, [tb(C, 1000000)]).
token_transfer(A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5) :-
    get_tok_bal(C, H, J),
    aux_cond_1(J, B, C, H, A, I_1, I_2, I_3, I_4, I_5, D, E, F, G, D, E, F, G, H).
aux_cond_1(A, B, C, D, E, F, G, H, I, [tb(E, J), tb(C, K)|D], F, G, H, I, _, _, _, _, _) :-
    A>=B,
    !,
    L is A-B,
    K is L,
    get_tok_bal(E, [tb(C, K)|D], M),
    N is M+B,
    J is N.
aux_cond_1(_, _, _, _, _, A_1, A_2, A_3, A_4, A_5, _, _, _, _, A_1, A_2, A_3, A_4, A_5).
mint(A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5) :-
    aux_cond_2(C, F, A, H, B, G, I_1, I_2, I_3, I_4, I_5, D, E, D, E, F, G, H).
aux_cond_2(A, A, B, C, D, E, F, G, A, H, [tb(B, I)|C], F, G, _, _, _, _, _) :-
    !,
    get_tok_bal(B, C, J),
    K is J+D,
    I is K,
    L is E+D,
    H is L.
aux_cond_2(_, _, _, _, _, _, A_1, A_2, A_3, A_4, A_5, _, _, A_1, A_2, A_3, A_4, A_5).
burn(A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5) :-
    get_tok_bal(A, H, J),
    aux_cond_3(C, F, J, B, A, H, G, I_1, I_2, I_3, I_4, I_5, D, E, D, E, F, G, H).
aux_cond_3(A, A, B, C, D, E, F, G, H, A, I, [tb(D, J)|E], G, H, _, _, _, _, _) :-
    B>=C,
    !,
    K is B-C,
    J is K,
    L is F-C,
    I is L.
aux_cond_3(_, _, _, _, _, _, _, A_1, A_2, A_3, A_4, A_5, _, _, A_1, A_2, A_3, A_4, A_5).
goal([A, B, C, D]) :-
    init(mycoin, mc, alice, _, E_1, E_2, E_3, E_4, E_5),
    token_transfer(bob, 500, alice, E_1, E_2, E_3, E_4, E_5, F_1, F_2, F_3, F_4, F_5),
    mint(charlie, 200, alice, F_1, F_2, F_3, F_4, F_5, G_1, G_2, G_3, G_4, G_5),
    burn(bob, 100, alice, G_1, G_2, G_3, G_4, G_5, _, _, _, D, H),
    get_tok_bal(alice, H, A),
    get_tok_bal(bob, H, B),
    get_tok_bal(charlie, H, C).
loop_aux_1([], _, A, A).
loop_aux_1([tb(A, B)|C], D, E, F) :-
    aux_cond_4(A, D, E, G, B),
    loop_aux_1(C, D, G, F).
aux_cond_4(A, A, 0, B, B) :-
    !.
aux_cond_4(_, _, A, A, _).
