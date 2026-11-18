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
init(A, B, C, _, B, D, null, 0, 0) :-
    E is C+A,
    D is E.
bid(A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5, J, K) :-
    aux_cond_1(C, E, B, G, H, A, J, F, K, I_1, I_2, I_3, I_4, I_5, D, D, E, F, G, H).
aux_cond_1(A, B, C, D, 0, E, F, G, H, I, B, E, C, 0, I, _, _, _, _, _) :-
    A<B,
    C>D,
    !,
    transfer(E, this, C, F, J),
    aux_cond_2(G, D, J, H).
aux_cond_1(_, _, _, _, _, _, A, _, A, B_1, B_2, B_3, B_4, B_5, _, B_1, B_2, B_3, B_4, B_5).
aux_cond_2(A, B, C, D) :-
    neq(A, null),
    !,
    transfer(this, A, B, C, D).
aux_cond_2(_, _, A, A).
end(A, B, C, D, E, F, G_1, G_2, G_3, G_4, G_5, H, I) :-
    aux_cond_3(A, C, F, B, E, H, I, G_1, G_2, G_3, G_4, G_5, D, B, C, D, E, F).
aux_cond_3(A, B, 0, C, D, E, F, C, B, G, D, 1, G, _, _, _, _, _) :-
    A>=B,
    !,
    transfer(this, C, D, E, F).
aux_cond_3(_, _, _, _, _, A, A, B_1, B_2, B_3, B_4, B_5, _, B_1, B_2, B_3, B_4, B_5).
goal([A, B, C, D]) :-
    init(100, bene, 0, _, E_1, E_2, E_3, E_4, E_5),
    bid(alice, 100, 10, E_1, E_2, E_3, E_4, E_5, F_1, F_2, F_3, F_4, F_5, [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)], G),
    bid(bob, 150, 20, F_1, F_2, F_3, F_4, F_5, H_1, H_2, H_3, H_4, H_5, G, I),
    bid(alice, 120, 30, H_1, H_2, H_3, H_4, H_5, J_1, J_2, J_3, J_4, J_5, I, K),
    end(200, J_1, J_2, J_3, J_4, J_5, _, _, _, _, _, K, L),
    get_bal(alice, L, M),
    A is M,
    get_bal(bob, L, N),
    B is N,
    get_bal(bene, L, O),
    C is O,
    get_bal(this, L, P),
    D is P.
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
