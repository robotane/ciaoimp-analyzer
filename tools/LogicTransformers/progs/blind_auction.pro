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
init(A, B, C, D, _, blind_state(C, E, F, null, 0, [])) :-
    G is D+A,
    E is G,
    H is E+B,
    F is H.
bid(A, B, C, D, blind_state(E, F, G, H, I, J), K, L, M) :-
    aux_cond_1(C,
               F,
               A,
               B,
               L,
               M,
               K,
               E,
               G,
               H,
               I,
               D,
               J,
               blind_state(E, F, G, H, I, J)).
aux_cond_1(A, B, C, D, E, F, blind_state(G, B, H, I, J, [bid(C, K, D)|L]), G, H, I, J, K, L, _) :-
    A<B,
    !,
    transfer(C, this, D, E, F).
aux_cond_1(_, _, _, _, A, A, B, _, _, _, _, _, _, B).
reveal(A, B, C, D, E, blind_state(F, G, H, I, J, K), L, M, N) :-
    aux_cond_2(B,
               G,
               H,
               K,
               A,
               C,
               E,
               D,
               J,
               I,
               M,
               L,
               F,
               N,
               blind_state(F, G, H, I, J, K)).
aux_cond_2(A, B, C, D, E, F, G, H, I, J, K, L, M, N, O) :-
    A>=B,
    A<C,
    !,
    loop_aux_3(D, E, =, 0, null, 0, P, Q, R, S),
    aux_cond_3(Q,
               R,
               F,
               G,
               S,
               H,
               I,
               J,
               K,
               E,
               L,
               M,
               B,
               C,
               P,
               N,
               O).
aux_cond_2(_, _, _, _, _, _, _, _, _, _, A, B, _, A, B).
aux_cond_3(1, A, A, B, C, D, E, F, G, H, I, J, K, L, M, N, _) :-
    !,
    aux_cond_4(B,
               C,
               D,
               E,
               F,
               G,
               H,
               I,
               J,
               K,
               L,
               M,
               N).
aux_cond_3(_, _, _, _, _, _, _, _, A, _, B, _, _, _, _, A, B).
aux_cond_4(0, A, B, C, D, E, F, blind_state(G, H, I, F, B, J), G, H, I, J, K) :-
    A>=B,
    B>C,
    !,
    aux_cond_5(D, C, E, L),
    M is A-B,
    N is M,
    aux_cond_6(N, F, L, K).
aux_cond_4(_, A, _, B, C, D, E, blind_state(F, G, H, C, B, I), F, G, H, I, J) :-
    transfer(this, E, A, D, J).
aux_cond_5(A, B, C, D) :-
    neq(A, null),
    !,
    transfer(this, A, B, C, D).
aux_cond_5(_, _, A, A).
aux_cond_6(A, B, C, D) :-
    A>0,
    !,
    transfer(this, B, A, C, D).
aux_cond_6(_, _, A, A).
auction_end(A, blind_state(B, C, D, E, F, G), H, I, J) :-
    aux_cond_7(A,
               D,
               E,
               B,
               F,
               I,
               J,
               H,
               C,
               blind_state(B, C, D, E, F, G)).
aux_cond_7(A, B, C, D, E, F, G, blind_state(D, H, B, C, E, []), H, _) :-
    A>=B,
    !,
    aux_cond_8(C, D, E, F, G).
aux_cond_7(_, _, _, _, _, A, A, B, _, B).
aux_cond_8(A, B, C, D, E) :-
    neq(A, null),
    !,
    transfer(this, B, C, D, E).
aux_cond_8(_, _, _, A, A).
goal([A, B, C, D]) :-
    init(100, 100, bene, 0, _, E),
    bid(alice,
        200,
        10,
        h_alice,
        E,
        F,
        [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
        G),
    bid(bob, 100, 20, h_bob, F, H, G, I),
    reveal(alice, 110, h_alice, 150, 0, H, J, I, K),
    reveal(bob, 120, h_bob, 100, 0, J, L, K, M),
    auction_end(210, L, _, M, N),
    get_bal(alice, N, O),
    A is O,
    get_bal(bob, N, P),
    B is P,
    get_bal(bene, N, Q),
    C is Q,
    get_bal(this, N, R),
    D is R,
    !.
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_9(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_9(A, A, B, B, _) :-
    !.
aux_cond_9(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, F) :-
    aux_cond_10(A, D, F, E, G, B),
    loop_aux_2(C, D, E, G).
aux_cond_10(A, A, [bal(A, B)|C], B, C, _) :-
    !.
aux_cond_10(A, _, [bal(A, B)|C], _, C, B).
loop_aux_3([], _, _, A, B, C, [], A, B, C).
loop_aux_3([bid(A, B, C)|D], E, F, G, H, I, J, K, L, M) :-
    aux_cond_11(A,
                E,
                G,
                N,
                O,
                B,
                P,
                C,
                J,
                bid(A, B, C),
                Q,
                H,
                I),
    loop_aux_3(D,
               E,
               F,
               N,
               O,
               P,
               Q,
               K,
               L,
               M).
aux_cond_11(A, A, 0, 1, B, B, C, C, _, _, _, _, _) :-
    !.
aux_cond_11(_, _, A, A, B, _, C, _, [D|E], D, E, B, C).
neq(A, B) :-
    A\=B.
