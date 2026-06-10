get_tok_bal(A, B, C) :-
    loop_aux_1(B, A, 0, C).
init(A, B, C, _, coin_state(A, B, C, 1000000, [tb(C, 1000000)])).
token_transfer(A, B, C, coin_state(D, E, F, G, H), I) :-
    get_tok_bal(C, H, J),
    aux_cond_1(J,
               B,
               C,
               H,
               A,
               I,
               D,
               E,
               F,
               G,
               coin_state(D, E, F, G, H)).
aux_cond_1(A, B, C, D, E, coin_state(F, G, H, I, [tb(E, J), tb(C, K)|D]), F, G, H, I, _) :-
    A>=B,
    !,
    L is A-B,
    K is L,
    get_tok_bal(E, [tb(C, K)|D], M),
    N is M+B,
    J is N.
aux_cond_1(_, _, _, _, _, A, _, _, _, _, A).
mint(A, B, C, coin_state(D, E, F, G, H), I) :-
    aux_cond_2(C,
               F,
               A,
               H,
               B,
               G,
               I,
               D,
               E,
               coin_state(D, E, F, G, H)).
aux_cond_2(A, A, B, C, D, E, coin_state(F, G, A, H, [tb(B, I)|C]), F, G, _) :-
    !,
    get_tok_bal(B, C, J),
    K is J+D,
    I is K,
    L is E+D,
    H is L.
aux_cond_2(_, _, _, _, _, _, A, _, _, A).
burn(A, B, C, coin_state(D, E, F, G, H), I) :-
    get_tok_bal(A, H, J),
    aux_cond_3(C,
               F,
               J,
               B,
               A,
               H,
               G,
               I,
               D,
               E,
               coin_state(D, E, F, G, H)).
aux_cond_3(A, A, B, C, D, E, F, coin_state(G, H, A, I, [tb(D, J)|E]), G, H, _) :-
    B>=C,
    !,
    K is B-C,
    J is K,
    L is F-C,
    I is L.
aux_cond_3(_, _, _, _, _, _, _, A, _, _, A).
goal([A, B, C, D]) :-
    init(mycoin, mc, alice, _, E),
    token_transfer(bob, 500, alice, E, F),
    mint(charlie, 200, alice, F, G),
    burn(bob,
         100,
         alice,
         G,
         coin_state(_, _, _, D, H)),
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
