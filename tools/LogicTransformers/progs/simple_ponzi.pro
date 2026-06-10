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
init(_, state(null, 0)).
invest(A, B, state(C, D), E, F, G) :-
    H is D*11//10,
    aux_cond_1(B,
               H,
               A,
               F,
               C,
               G,
               E,
               state(C, D)).
aux_cond_1(A, B, C, D, E, F, state(C, A), _) :-
    A>B,
    !,
    transfer(C, this, A, D, G),
    aux_cond_2(E, A, G, F).
aux_cond_1(_, _, _, A, _, A, B, B).
aux_cond_2(A, B, C, D) :-
    neq(A, null),
    !,
    transfer(this, A, B, C, D).
aux_cond_2(_, _, A, A).
goal([A, B, C]) :-
    init(_, D),
    invest(alice,
           100,
           D,
           E,
           [bal(alice, 1000), bal(bob, 1000), bal(this, 0)],
           F),
    invest(bob, 120, E, _, F, G),
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
loop_aux_2([bal(A, B)|C], D, E, F) :-
    aux_cond_4(A, D, F, E, G, B),
    loop_aux_2(C, D, E, G).
aux_cond_4(A, A, [bal(A, B)|C], B, C, _) :-
    !.
aux_cond_4(A, _, [bal(A, B)|C], _, C, B).
neq(A, B) :-
    A\=B.
