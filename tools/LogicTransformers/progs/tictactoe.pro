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
get_board(A, B, C) :-
    loop_aux_3(B, A, 0, C).
check_winner(A, B) :-
    get_board(1, A, C),
    get_board(2, A, D),
    get_board(3, A, E),
    get_board(4, A, F),
    get_board(5, A, G),
    get_board(6, A, H),
    get_board(7, A, I),
    get_board(8, A, J),
    get_board(9, A, K),
    aux_disj_1(B,
               C,
               D,
               E,
               F,
               G,
               H,
               I,
               J,
               K).
aux_disj_1(1, A, B, C, _, _, _, _, _, _) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, _, _, _, A, B, C, _, _, _) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, _, _, _, _, _, _, A, B, C) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, A, _, _, B, _, _, C, _, _) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, _, A, _, _, B, _, _, C, _) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, _, _, A, _, _, B, _, _, C) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, A, _, _, _, B, _, _, _, C) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(1, _, _, A, _, B, _, C, _, _) :-
    A=:=1,
    B=:=1,
    C=:=1,
    !.
aux_disj_1(2, A, B, C, _, _, _, _, _, _) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, _, _, _, A, B, C, _, _, _) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, _, _, _, _, _, _, A, B, C) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, A, _, _, B, _, _, C, _, _) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, _, A, _, _, B, _, _, C, _) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, _, _, A, _, _, B, _, _, C) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, A, _, _, _, B, _, _, _, C) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(2, _, _, A, _, B, _, C, _, _) :-
    A=:=2,
    B=:=2,
    C=:=2,
    !.
aux_disj_1(0, _, _, _, _, _, _, _, _, _).
init(A, B, C, _, ttt_state(A, B, 1, 0, []), D, E) :-
    transfer(A, this, C, D, F),
    transfer(B, this, C, F, E).
play(A, B, ttt_state(C, D, E, F, G), H, I, J) :-
    get_board(A, G, K),
    aux_cond_1(F,
               K,
               A,
               E,
               B,
               C,
               G,
               I,
               H,
               D,
               ttt_state(C, D, E, F, G),
               J).
aux_cond_1(0, 0, A, B, C, D, E, F, G, H, I, J) :-
    A>=1,
    A=<9,
    !,
    aux_cond_2(B,
               C,
               D,
               K,
               A,
               E,
               L,
               F,
               M,
               G,
               H,
               I),
    aux_cond_4(B,
               C,
               H,
               A,
               E,
               L,
               M,
               J,
               I,
               D,
               K).
aux_cond_1(_, _, _, _, _, _, _, A, B, _, B, A).
aux_cond_2(1, A, A, [cell(B, 1)|C], B, C, D, E, F, ttt_state(A, G, 2, D, [cell(B, 1)|C]), G, _) :-
    !,
    check_winner([cell(B, 1)|C], D),
    aux_cond_3(D, A, E, F).
aux_cond_2(_, _, _, _, _, _, _, A, A, B, _, B).
aux_cond_3(1, A, B, C) :-
    !,
    transfer(this, A, 200, B, C).
aux_cond_3(_, _, A, A).
aux_cond_4(2, A, A, B, C, D, E, F, ttt_state(G, A, 1, D, [cell(B, 2)|C]), G, _) :-
    !,
    check_winner([cell(B, 2)|C], D),
    aux_cond_5(D, A, E, F).
aux_cond_4(_, _, _, _, _, _, A, A, _, _, _).
aux_cond_5(2, A, B, C) :-
    !,
    transfer(this, A, 200, B, C).
aux_cond_5(_, _, A, A).
goal([A, B, C]) :-
    init(alice,
         bob,
         100,
         _,
         D,
         [bal(alice, 1000), bal(bob, 1000), bal(this, 0)],
         E),
    play(1, alice, D, F, E, G),
    play(2, bob, F, H, G, I),
    play(5, alice, H, J, I, K),
    play(3, bob, J, L, K, M),
    play(9, alice, L, _, M, N),
    get_bal(alice, N, O),
    A is O,
    get_bal(bob, N, P),
    B is P,
    get_bal(this, N, Q),
    C is Q.
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_6(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_6(A, A, B, B, _) :-
    !.
aux_cond_6(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, F) :-
    aux_cond_7(A, D, F, E, G, B),
    loop_aux_2(C, D, E, G).
aux_cond_7(A, A, [bal(A, B)|C], B, C, _) :-
    !.
aux_cond_7(A, _, [bal(A, B)|C], _, C, B).
loop_aux_3([], _, A, A).
loop_aux_3([cell(A, B)|C], D, E, F) :-
    aux_cond_8(A, D, E, G, B),
    loop_aux_3(C, D, G, F).
aux_cond_8(A, A, 0, B, B) :-
    !.
aux_cond_8(_, _, A, A, _).
