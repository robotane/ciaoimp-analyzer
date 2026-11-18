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
get_paper(A, B, C) :-
    loop_aux_3(B, A, 0, C).
set_paper(A, B, C, D) :-
    loop_aux_4(C, B, A, 0, E, F),
    aux_disj_10(B, F, E, D).
aux_disj_10(A, 0, B, [A|B]) :-
    !.
aux_disj_10(_, _, A, A).
init(A, B, B, C, [paper(B, 1, 0, null, -1)]) :-
    init_props(A, C).
init_props([], []).
init_props([A|B], [proposal(A, 0)|C]) :-
    init_props(B, C).
give_right(A, B, C, D, E, F_1, F_2, F_3) :-
    aux_disj_8(A, B, C, D, E, F_1, F_2, F_3, C, D, E).
aux_disj_8(A, B, C_1, C_2, C_3, D_1, D_2, D_3, B, E, F) :-
    !,
    get_paper(A, F, G),
    aux_disj_9(A, C_1, C_2, C_3, D_1, D_2, D_3, B, E, F, G).
aux_disj_8(_, _, A_1, A_2, A_3, A_1, A_2, A_3, _, _, _).
aux_disj_9(A, _, _, _, B, C, D, B, C, E, 0) :-
    !,
    set_paper(A, paper(A, 1, 0, null, -1), E, D).
aux_disj_9(_, A_1, A_2, A_3, A_1, A_2, A_3, _, _, _, _).
delegate(A, B, C, D, E, F_1, F_2, F_3) :-
    get_paper(B, E, G),
    aux_disj_1(A, B, C, D, E, F_1, F_2, F_3, C, D, E, G).
aux_disj_1(A, B, C_1, C_2, C_3, D_1, D_2, D_3, E, F, G, paper(B, H, 0, I, J)) :-
    neq(paper(B, H, 0, I, J), 0),
    !,
    aux_disj_2(A, B, C_1, C_2, C_3, D_1, D_2, D_3, E, F, G, H).
aux_disj_1(_, _, A_1, A_2, A_3, A_1, A_2, A_3, _, _, _, _).
aux_disj_2(A, B, C_1, C_2, C_3, D_1, D_2, D_3, E, F, G, H) :-
    neq(A, B),
    !,
    find_final_delegate(A, B, G, I),
    get_paper(I, G, J),
    aux_disj_3(B, C_1, C_2, C_3, D_1, D_2, D_3, E, F, G, H, I, J).
aux_disj_2(_, _, A_1, A_2, A_3, A_1, A_2, A_3, _, _, _, _).
aux_disj_3(A, _, _, _, B_1, B_2, B_3, C, D, E, F, G, paper(G, H, I, J, K)) :-
    neq(paper(G, H, I, J, K), 0),
    !,
    set_paper(A, paper(A, F, 1, G, -1), E, L),
    aux_disj_4(B_1, B_2, B_3, C, D, F, G, L, H, I, J, K).
aux_disj_3(_, A_1, A_2, A_3, A_1, A_2, A_3, _, _, _, _, _, _).
aux_disj_4(A_1, A_2, A_3, B, C, D, _, E, _, 1, _, F) :-
    !,
    aux_disj_5(A_1, A_2, A_3, B, C, D, E, F).
aux_disj_4(A, B, C, A, B, D, E, F, G, _, H, _) :-
    I is G+D,
    J is I,
    set_paper(E, paper(E, J, 0, H, -1), F, C).
aux_disj_5(A, B, C, A, D, E, C, F) :-
    neq(F, -1),
    !,
    add_votes_to_prop(F, E, 1, D, B).
aux_disj_5(A, B, C, A, B, _, C, _).
find_final_delegate(A, B, C, D) :-
    get_paper(A, C, E),
    aux_disj_6(A, B, C, D, E).
aux_disj_6(A, B, C, D, paper(E, F, G, H, I)) :-
    neq(paper(E, F, G, H, I), 0),
    !,
    aux_disj_7(A, B, C, D, H).
aux_disj_6(A, _, _, A, _).
aux_disj_7(_, A, B, C, D) :-
    neq(D, null),
    neq(D, A),
    !,
    find_final_delegate(D, A, B, C).
aux_disj_7(A, _, _, A, _).
vote(A, B, C, D, E, F_1, F_2, F_3) :-
    get_paper(B, E, G),
    aux_disj_11(A, B, C, D, E, F_1, F_2, F_3, C, D, E, G).
aux_disj_11(A, B, _, _, _, C, D, E, C, F, G, paper(B, H, 0, I, J)) :-
    neq(paper(B, H, 0, I, J), 0),
    !,
    set_paper(B, paper(B, H, 1, null, A), G, E),
    add_votes_to_prop(A, H, 1, F, D).
aux_disj_11(_, _, A_1, A_2, A_3, A_1, A_2, A_3, _, _, _, _).
add_votes_to_prop(_, _, _, [], []).
add_votes_to_prop(A, B, A, [proposal(C, D)|E], [proposal(C, F)|G]) :-
    !,
    H is A+1,
    add_votes_to_prop(A, B, H, E, G),
    I is D+B,
    F is I.
add_votes_to_prop(A, B, C, [proposal(D, E)|F], [proposal(D, E)|G]) :-
    H is C+1,
    add_votes_to_prop(A, B, H, F, G).
best_proposal([], A, _, A).
best_proposal([proposal(A, B)|C], _, D, E) :-
    B>D,
    !,
    best_proposal(C, A, B, E).
best_proposal([proposal(_, _)|A], B, C, D) :-
    best_proposal(A, B, C, D).
winner(A, _, B, _) :-
    best_proposal(B, aucun, -1, A).
goal([A]) :-
    init([prop_a, prop_b, prop_c], admin, B_1, B_2, B_3),
    give_right(alice, admin, B_1, B_2, B_3, C_1, C_2, C_3),
    give_right(bob, admin, C_1, C_2, C_3, D_1, D_2, D_3),
    give_right(charlie, admin, D_1, D_2, D_3, E_1, E_2, E_3),
    vote(1, alice, E_1, E_2, E_3, F_1, F_2, F_3),
    delegate(alice, bob, F_1, F_2, F_3, G_1, G_2, G_3),
    vote(2, charlie, G_1, G_2, G_3, H_1, H_2, H_3),
    vote(1, admin, H_1, H_2, H_3, I_1, I_2, I_3),
    winner(A, I_1, I_2, I_3).
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_1(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_1(A, A, B, B, _) :-
    !.
aux_cond_1(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, [Elem_1|F]) :-
    aux_cond_2(A, D, Elem_1, E, B),
    loop_aux_2(C, D, E, F).
aux_cond_2(A, A, bal(A, B), B, _) :-
    !.
aux_cond_2(A, _, bal(A, B), _, B).
loop_aux_3([], _, A, A).
loop_aux_3([paper(A, B, C, D, E)|F], G, H, I) :-
    aux_cond_3(A, G, J, B, C, D, E, H),
    loop_aux_3(F, G, J, I).
aux_cond_3(A, A, paper(A, B, C, D, E), B, C, D, E, _) :-
    !.
aux_cond_3(_, _, A, _, _, _, _, A).
loop_aux_4([], _, _, A, [], A).
loop_aux_4([paper(A, B, C, D, E)|F], G, H, I, [Elem_1|J], K) :-
    aux_cond_4(A, H, Elem_1, G, M, paper(A, B, C, D, E), I),
    loop_aux_4(F, G, H, M, J, K).
aux_cond_4(A, A, B, B, 1, _, _) :-
    !.
aux_cond_4(_, _, A, _, C, A, C).
neq(A, B) :-
    A\==B.
