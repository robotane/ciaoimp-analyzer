:- mode(goal/1, [-]). :- measure(goal/1, [size]).
get_bal(A, B, C) :-
    loop_aux_1(B, A, 0, C).
set_bal(A, B, C, D) :-
    loop_aux_2(C, A, B, D).
transfer(A, B, C, D, E) :-
    get_bal(A, D, F),
    G is F,
    H is G-C,
    set_bal(A, H, D, I),
    get_bal(B, I, J),
    K is J,
    L is K+C,
    set_bal(B, L, I, E).
init(_, null, 0).
invest(A, B, C, D, E_1, E_2, F, G) :-
    H is D*11//10,
    aux_cond_1(B, H, A, F, C, G, E_1, E_2, C, D).
aux_cond_1(A, B, C, D, E, F, C, A, _, _) :-
    A>B,
    !,
    transfer(C, this, A, D, G),
    aux_cond_2(E, A, G, F).
aux_cond_1(_, _, _, A, _, A, B_1, B_2, B_1, B_2).
aux_cond_2(A, B, C, D) :-
    neq(A, null),
    !,
    transfer(this, A, B, C, D).
aux_cond_2(_, _, A, A).
goal([A, B, C]) :-
    init(_, D_1, D_2),
    invest(alice, 100, D_1, D_2, E_1, E_2, [bal(alice, 1000), bal(bob, 1000), bal(this, 0)], F),
    invest(bob, 120, E_1, E_2, _, _, F, G),
    get_bal(alice, G, H),
    A is H,
    get_bal(bob, G, I),
    B is I,
    get_bal(this, G, J),
    C is J.
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_3(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_3(A, A, B, B, _) :-
    !.
aux_cond_3(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, [Elem_1|F]) :-
    aux_cond_4(A, D, Elem_1, E, B),
    loop_aux_2(C, D, E, F).
aux_cond_4(A, A, bal(A, B), B, _) :-
    !.
aux_cond_4(A, _, bal(A, B), _, B).
neq(A, B) :-
    A\==B.
