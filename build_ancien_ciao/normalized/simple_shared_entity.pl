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
get_share(A, B, C) :-
    loop_aux_3(B, A, 0, C).
init(A, _, A, [], 0).
place_offer(A, B, C, D, E, F, G_1, G_2, G_3) :-
    get_share(C, D, H),
    aux_cond_1(H, B, F, C, A, E, G_1, G_2, G_3, D, D, E, F).
aux_cond_1(A, B, C, D, E, F, G, [offer(C, D, E, B, 1)|F], H, G, _, _, _) :-
    A>=B,
    !,
    I is C+1,
    H is I.
aux_cond_1(_, _, _, _, _, _, A_1, A_2, A_3, _, A_1, A_2, A_3).
accept(A, B, C, D, E, F, G, H, F, I, J) :-
    loop_aux_4(E, B, A, C, =, D, I, H, G, J).
goal([A, B, C, D]) :-
    init([sh(alice, 60), sh(bob, 40)], _, E_1, E_2, E_3),
    place_offer(200, 10, alice, E_1, E_2, E_3, F_1, F_2, F_3),
    accept(0, charlie, 200, F_1, F_2, F_3, _, _, _, [bal(alice, 1000), bal(bob, 1000), bal(charlie, 1000), bal(this, 0)], G),
    get_bal(alice, G, H),
    A is H,
    get_bal(bob, G, I),
    B is I,
    get_bal(charlie, G, J),
    C is J,
    get_bal(this, G, K),
    D is K.
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_2(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_2(A, A, B, B, _) :-
    !.
aux_cond_2(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, [Elem_1|F]) :-
    aux_cond_3(A, D, Elem_1, E, B),
    loop_aux_2(C, D, E, F).
aux_cond_3(A, A, bal(A, B), B, _) :-
    !.
aux_cond_3(A, _, bal(A, B), _, B).
loop_aux_3([], _, A, A).
loop_aux_3([sh(A, B)|C], D, E, F) :-
    aux_cond_4(D, A, E, G, B),
    loop_aux_3(C, D, G, F).
aux_cond_4(A, A, 0, B, B) :-
    !.
aux_cond_4(_, _, A, A, _).
loop_aux_4([], _, _, _, _, A, B, [], A, B).
loop_aux_4([offer(A, B, C, D, E)|F], G, H, I, J, K, L, [Elem_1|M], N, O) :-
    aux_cond_5(A, H, E, I, C, G, L, B, K, D, P, Elem_1, R, offer(A, B, C, D, E)),
    loop_aux_4(F, G, H, I, J, P, R, M, N, O).
aux_cond_5(A, A, 1, B, C, D, E, F, G, H, [sh(D, I), sh(F, J)|G], offer(A, F, C, H, 0), L, _) :-
    B>=C,
    !,
    transfer(D, this, B, E, M),
    transfer(this, F, B, M, L),
    get_share(F, G, N),
    O is N-H,
    J is O,
    get_share(D, [sh(F, J)|G], P),
    Q is P+H,
    I is Q.
aux_cond_5(_, _, _, _, _, _, A, _, B, _, B, C, A, C).
