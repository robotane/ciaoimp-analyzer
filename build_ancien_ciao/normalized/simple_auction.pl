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
init(A, B, C, _, B, D, 0, null) :-
    E is C+A,
    D is E.
bid(A, B, C, D, E, F, G, H_1, H_2, H_3, H_4, I, J) :-
    aux_cond_1(C, E, B, F, A, I, G, J, H_1, H_2, H_3, H_4, D, D, E, F, G).
aux_cond_1(A, B, C, D, E, F, G, H, I, B, C, E, I, _, _, _, _) :-
    A<B,
    C>D,
    !,
    transfer(E, this, C, F, J),
    aux_cond_2(G, D, J, H).
aux_cond_1(_, _, _, _, _, A, _, A, B_1, B_2, B_3, B_4, _, B_1, B_2, B_3, B_4).
aux_cond_2(A, B, C, D) :-
    neq(A, null),
    !,
    transfer(this, A, B, C, D).
aux_cond_2(_, _, A, A).
auction_end(A, B, C, D, E, F_1, F_2, F_3, F_4, G, H) :-
    aux_cond_3(A, C, E, B, D, G, H, F_1, F_2, F_3, F_4, B, C, D, E).
aux_cond_3(A, B, C, D, E, F, G, D, B, E, null, _, _, _, _) :-
    A>=B,
    neq(C, null),
    !,
    transfer(this, D, E, F, G).
aux_cond_3(_, _, _, _, _, A, A, B_1, B_2, B_3, B_4, B_1, B_2, B_3, B_4).
goal([A, B, C, D]) :-
    init(100, bene, 0, _, E_1, E_2, E_3, E_4),
    bid(alice, 100, 10, E_1, E_2, E_3, E_4, F_1, F_2, F_3, F_4, [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)], G),
    bid(bob, 200, 20, F_1, F_2, F_3, F_4, H_1, H_2, H_3, H_4, G, I),
    auction_end(200, H_1, H_2, H_3, H_4, _, _, _, _, I, J),
    get_bal(alice, J, K),
    A is K,
    get_bal(bob, J, L),
    B is L,
    get_bal(bene, J, M),
    C is M,
    get_bal(this, J, N),
    D is N.
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_4(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_4(A, A, B, B, _) :-
    !.
aux_cond_4(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, [Elem_1|F]) :-
    aux_cond_5(A, D, Elem_1, E, B),
    loop_aux_2(C, D, E, F).
aux_cond_5(A, A, bal(A, B), B, _) :-
    !.
aux_cond_5(A, _, bal(A, B), _, B).
neq(A, B) :-
    A\==B.
