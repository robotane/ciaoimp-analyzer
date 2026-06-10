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
init(_, state([])).
new_campaign(A, B, C, state(D), state([campaign(C, A, B, 0, [])|D])) :-
    len_list(D, C).
contribute(A, B, C, state(D), state(E), F, G) :-
    transfer(A, this, B, F, G),
    loop_aux_3(D, B, A, C, =, E).
check_goal_reached(A, B, state(C), state(D), E, F) :-
    loop_aux_4(C, A, =, 0, E, D, B, F).
goal([A, B, C, D]) :-
    init(_, E),
    new_campaign(bene, 300, _, E, F),
    contribute(alice,
               200,
               0,
               F,
               G,
               [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
               H),
    contribute(bob, 150, 0, G, I, H, J),
    check_goal_reached(0, _, I, _, J, K),
    get_bal(alice, K, L),
    A is L,
    get_bal(bob, K, M),
    B is M,
    get_bal(bene, K, N),
    C is N,
    get_bal(this, K, O),
    D is O.
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_1(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_1(A, A, B, B, _) :-
    !.
aux_cond_1(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, F) :-
    aux_cond_2(A, D, F, E, G, B),
    loop_aux_2(C, D, E, G).
aux_cond_2(A, A, [bal(A, B)|C], B, C, _) :-
    !.
aux_cond_2(A, _, [bal(A, B)|C], _, C, B).
loop_aux_3([], _, _, _, _, []).
loop_aux_3([campaign(A, B, C, D, E)|F], G, H, I, J, K) :-
    aux_cond_3(A,
               I,
               D,
               G,
               K,
               B,
               C,
               H,
               E,
               L,
               campaign(A, B, C, D, E)),
    loop_aux_3(F, G, H, I, J, L).
aux_cond_3(A, A, B, C, [campaign(A, D, E, F, [funder(G, C)|H])|I], D, E, G, H, I, _) :-
    !,
    J is B+C,
    F is J.
aux_cond_3(_, _, _, _, [A|B], _, _, _, _, B, A).
loop_aux_4([], _, _, A, B, [], A, B).
loop_aux_4([campaign(A, B, C, D, E)|F], G, H, I, J, K, L, M) :-
    aux_cond_4(A,
               G,
               D,
               C,
               B,
               J,
               K,
               E,
               N,
               O,
               campaign(A, B, C, D, E),
               I,
               P),
    loop_aux_4(F,
               G,
               H,
               O,
               P,
               N,
               L,
               M).
aux_cond_4(A, A, B, C, D, E, F, G, H, I, J, K, L) :-
    !,
    aux_cond_5(B,
               C,
               D,
               E,
               F,
               A,
               G,
               H,
               I,
               L,
               J,
               K,
               L).
aux_cond_4(_, _, _, _, _, A, [B|C], _, C, D, B, D, A).
aux_cond_5(A, B, C, D, [campaign(E, C, B, 0, F)|G], E, F, G, 1, H, _, _, _) :-
    A>=B,
    !,
    transfer(this, C, A, D, H).
aux_cond_5(_, _, _, A, [B|C], _, _, C, D, A, B, D, A).
len_list([], 0).
len_list([_|A], B) :-
    len_list(A, C),
    B is C+1.
