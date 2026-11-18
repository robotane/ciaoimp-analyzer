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
init(A, _, [A], 1000).
invest(A, B, C, D, E_1, E_2, F, G) :-
    H is D*11//10,
    I is H,
    aux_cond_1(B, I, A, F, C, G, E_1, E_2, C, D).
aux_cond_1(A, B, C, D, E, F, [C|E], A, _, _) :-
    A>=B,
    !,
    transfer(C, this, A, D, G),
    loop_aux_3(E, is, 0, H),
    I is A//H,
    J is I,
    loop_aux_4(E, J, G, F).
aux_cond_1(_, _, _, A, _, A, B_1, B_2, B_1, B_2).
goal([A, B, C, D]) :-
    init(alice, _, E_1, E_2),
    invest(bob, 1100, E_1, E_2, F_1, F_2, [bal(alice, 1000), bal(bob, 2000), bal(charlie, 1500), bal(this, 0)], G),
    invest(charlie, 1210, F_1, F_2, _, _, G, H),
    get_bal(alice, H, I),
    A is I,
    get_bal(bob, H, J),
    B is J,
    get_bal(charlie, H, K),
    C is K,
    get_bal(this, H, L),
    D is L.
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
loop_aux_3([_|A], B, C, D) :-
    E is C+1,
    loop_aux_3(A, B, E, D).
loop_aux_4([], _, A, A).
loop_aux_4([A|B], C, D, E) :-
    transfer(this, A, C, D, F),
    loop_aux_4(B, C, F, E).
