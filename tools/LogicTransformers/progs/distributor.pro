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
init(A, _, dist_state(A, [])).
add_as_payee(A, dist_state(B, C), dist_state(B, [A|C])).
distribute(A, B, dist_state(C, D), dist_state(C, D), E, F) :-
    len_list(D, G),
    aux_cond_1(G, A, B, E, D, F).
aux_cond_1(A, B, C, D, E, F) :-
    A>0,
    !,
    transfer(B, this, C, D, G),
    H is C//A,
    I is H,
    loop_aux_3(E, I, G, F).
aux_cond_1(_, _, _, A, _, A).
goal([A, B, C, D]) :-
    init(owner, _, E),
    add_as_payee(alice, E, F),
    add_as_payee(bob, F, G),
    distribute(carol,
               300,
               G,
               _,
               [bal(alice, 1000), bal(bob, 1000), bal(carol, 1000), bal(this, 0)],
               H),
    get_bal(alice, H, I),
    A is I,
    get_bal(bob, H, J),
    B is J,
    get_bal(carol, H, K),
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
loop_aux_3([], _, A, A).
loop_aux_3([A|B], C, D, E) :-
    transfer(this, A, C, D, F),
    loop_aux_3(B, C, F, E).
len_list([], 0).
len_list([_|A], B) :-
    len_list(A, C),
    B is C+1.
