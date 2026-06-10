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
init(A, _, state([A])).
invest(A, B, state(C), D, E, F) :-
    aux_cond_1(B, A, E, C, F, D, state(C)).
aux_cond_1(A, B, C, D, E, state([B|D]), _) :-
    A>=1000,
    !,
    transfer(B, this, A, C, F),
    loop_aux_3(D, 0, G),
    H is A//G,
    I is H,
    loop_aux_4(D, I, F, E).
aux_cond_1(_, _, A, _, A, B, B).
goal([A, B, C, D]) :-
    init(alice, _, E),
    invest(bob,
           1000,
           E,
           F,
           [bal(alice, 1000), bal(bob, 1000), bal(charlie, 1000), bal(this, 0)],
           G),
    invest(charlie, 2000, F, _, G, H),
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
loop_aux_2([bal(A, B)|C], D, E, F) :-
    aux_cond_3(A, D, F, E, G, B),
    loop_aux_2(C, D, E, G).
aux_cond_3(A, A, [bal(A, B)|C], B, C, _) :-
    !.
aux_cond_3(A, _, [bal(A, B)|C], _, C, B).
loop_aux_3([], A, A).
loop_aux_3([_|A], B, C) :-
    D is B+1,
    loop_aux_3(A, D, C).
loop_aux_4([], _, A, A).
loop_aux_4([A|B], C, D, E) :-
    transfer(this, A, C, D, F),
    loop_aux_4(B, C, F, E).
