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
init(A, B, C, _, auction_state(B, D, null, 0, 0)) :-
    E is C+A,
    D is E.
bid(A, B, C, auction_state(D, E, F, G, H), I, J, K) :-
    aux_cond_1(C,
               E,
               B,
               G,
               H,
               A,
               J,
               F,
               K,
               I,
               D,
               auction_state(D, E, F, G, H)).
aux_cond_1(A, B, C, D, 0, E, F, G, H, auction_state(I, B, E, C, 0), I, _) :-
    A<B,
    C>D,
    !,
    transfer(E, this, C, F, J),
    aux_cond_2(G, D, J, H).
aux_cond_1(_, _, _, _, _, _, A, _, A, B, _, B).
aux_cond_2(A, B, C, D) :-
    neq(A, null),
    !,
    transfer(this, A, B, C, D).
aux_cond_2(_, _, A, A).
end(A, auction_state(B, C, D, E, F), G, H, I) :-
    aux_cond_3(A,
               C,
               F,
               B,
               E,
               H,
               I,
               G,
               D,
               auction_state(B, C, D, E, F)).
aux_cond_3(A, B, 0, C, D, E, F, auction_state(C, B, G, D, 1), G, _) :-
    A>=B,
    !,
    transfer(this, C, D, E, F).
aux_cond_3(_, _, _, _, _, A, A, B, _, B).
goal([A, B, C, D]) :-
    init(100, bene, 0, _, E),
    bid(alice,
        100,
        10,
        E,
        F,
        [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
        G),
    bid(bob, 150, 20, F, H, G, I),
    bid(alice, 120, 30, H, J, I, K),
    end(200, J, _, K, L),
    get_bal(alice, L, M),
    A is M,
    get_bal(bob, L, N),
    B is N,
    get_bal(bene, L, O),
    C is O,
    get_bal(this, L, P),
    D is P.
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_4(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_4(A, A, B, B, _) :-
    !.
aux_cond_4(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, F) :-
    aux_cond_5(A, D, F, E, G, B),
    loop_aux_2(C, D, E, G).
aux_cond_5(A, A, [bal(A, B)|C], B, C, _) :-
    !.
aux_cond_5(A, _, [bal(A, B)|C], _, C, B).
neq(A, B) :-
    A\=B.
