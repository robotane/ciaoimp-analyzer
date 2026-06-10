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
    loop_aux_4(C, B, A, 0, D, E),
    aux_disj_10(B, E, D).
aux_disj_10(_, 0, _) :-
    !.
aux_disj_10(_, _, _).
init(A, B, ballot_state(B, C, [paper(B, 1, 0, null, -1)])) :-
    init_props(A, C).
init_props([], []).
init_props([A|B], [proposal(A, 0)|C]) :-
    init_props(B, C).
give_right(A, B, ballot_state(C, D, E), F) :-
    aux_disj_8(A,
               B,
               ballot_state(C, D, E),
               F,
               C,
               D,
               E).
aux_disj_8(A, B, C, D, B, E, F) :-
    !,
    get_paper(A, F, G),
    aux_disj_9(A, C, D, B, E, F, G).
aux_disj_8(_, _, A, A, _, _, _).
aux_disj_9(A, _, ballot_state(B, C, D), B, C, E, 0) :-
    !,
    set_paper(A, paper(A, 1, 0, null, -1), E, D).
aux_disj_9(_, A, A, _, _, _, _).
delegate(A, B, ballot_state(C, D, E), F) :-
    get_paper(B, E, G),
    aux_disj_1(A,
               B,
               ballot_state(C, D, E),
               F,
               C,
               D,
               E,
               G).
aux_disj_1(A, B, C, D, E, F, G, paper(B, H, 0, I, J)) :-
    neq(paper(B, H, 0, I, J), 0),
    !,
    aux_disj_2(A,
               B,
               C,
               D,
               E,
               F,
               G,
               H).
aux_disj_1(_, _, A, A, _, _, _, _).
aux_disj_2(A, B, C, D, E, F, G, H) :-
    neq(A, B),
    !,
    find_final_delegate(A, B, G, I),
    get_paper(I, G, J),
    aux_disj_3(B,
               C,
               D,
               E,
               F,
               G,
               H,
               I,
               J).
aux_disj_2(_, _, A, A, _, _, _, _).
aux_disj_3(A, _, B, C, D, E, F, G, paper(G, H, I, J, K)) :-
    neq(paper(G, H, I, J, K), 0),
    !,
    set_paper(A, paper(A, F, 1, G, -1), E, L),
    aux_disj_4(B,
               C,
               D,
               F,
               G,
               L,
               H,
               I,
               J,
               K).
aux_disj_3(_, A, A, _, _, _, _, _, _).
aux_disj_4(A, B, C, D, _, E, _, 1, _, F) :-
    !,
    aux_disj_5(A, B, C, D, E, F).
aux_disj_4(ballot_state(A, B, C), A, B, D, E, F, G, _, H, _) :-
    I is G+D,
    J is I,
    set_paper(E, paper(E, J, 0, H, -1), F, C).
aux_disj_5(ballot_state(A, B, C), A, D, E, C, F) :-
    neq(F, -1),
    !,
    add_votes_to_prop(F, E, 1, D, B).
aux_disj_5(ballot_state(A, B, C), A, B, _, C, _).
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
vote(A, B, ballot_state(C, D, E), F) :-
    get_paper(B, E, G),
    aux_disj_11(A,
                B,
                ballot_state(C, D, E),
                F,
                C,
                D,
                E,
                G).
aux_disj_11(A, B, _, ballot_state(C, D, E), C, F, G, paper(B, H, 0, I, J)) :-
    neq(paper(B, H, 0, I, J), 0),
    !,
    set_paper(B, paper(B, H, 1, null, A), G, E),
    add_votes_to_prop(A, H, 1, F, D).
aux_disj_11(_, _, A, A, _, _, _, _).
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
winner(A, ballot_state(_, B, _)) :-
    best_proposal(B, aucun, -1, A).
goal([A]) :-
    init([prop_a, prop_b, prop_c], admin, B),
    give_right(alice, admin, B, C),
    give_right(bob, admin, C, D),
    give_right(charlie, admin, D, E),
    vote(1, alice, E, F),
    delegate(alice, bob, F, G),
    vote(2, charlie, G, H),
    vote(1, admin, H, I),
    winner(A, I).
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
loop_aux_3([], _, A, A).
loop_aux_3([paper(A, B, C, D, E)|F], G, H, I) :-
    aux_cond_3(A,
               G,
               J,
               B,
               C,
               D,
               E,
               H),
    loop_aux_3(F, G, J, I).
aux_cond_3(A, A, paper(A, B, C, D, E), B, C, D, E, _) :-
    !.
aux_cond_3(_, _, A, _, _, _, _, A).
loop_aux_4([], _, _, A, [], A).
loop_aux_4([paper(A, B, C, D, E)|F], G, H, I, J, K) :-
    aux_cond_4(A,
               H,
               J,
               G,
               L,
               M,
               paper(A, B, C, D, E),
               I),
    loop_aux_4(F, G, H, M, L, K).
aux_cond_4(A, A, [B|C], B, C, 1, _, _) :-
    !.
aux_cond_4(_, _, [A|B], _, B, C, A, C).
neq(A, B) :-
    A\=B.
