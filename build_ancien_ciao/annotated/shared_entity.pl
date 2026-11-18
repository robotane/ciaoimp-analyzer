:- mode(get_bal/3, [+, +, -]).
:- measure(get_bal/3, [void, length, void]).

:- mode(set_bal/4, [+, +, +, -]).
:- measure(set_bal/4, [void, void, length, length]).

:- mode(transfer/5, [+, +, +, +, -]).
:- measure(transfer/5, [void, void, int, length, length]).

:- mode(get_share/3, [+, +, -]).
:- measure(get_share/3, [void, length, void]).

:- mode(init/5, [+, +, +, +, -]).
:- measure(init/5, [void, void, void, length, int]).

:- mode(place_offer/9, [+, +, +, +, +, +, -, -, -]).
:- measure(place_offer/9, [void, void, void, length, length, void, void, length, void]).

:- mode(aux_cond_1/13, [+, +, +, +, +, +, -, -, -, +, +, +, +]).
:- measure(aux_cond_1/13, [void, void, void, void, void, length, void, length, void, void, void, length, void]).

:- mode(accept_offer/11, [+, +, +, +, +, +, +, -, +, +, -]).
:- measure(accept_offer/11, [void, void, void, length, length, void, void, length, void, length, void]).

:- mode(loop_aux_1/4, [+, +, +, -]).
:- measure(loop_aux_1/4, [length, void, void, void]).

:- mode(aux_cond_2/5, [+, +, -, +, +]).
:- measure(aux_cond_2/5, [void, void, void, void, void]).

:- mode(loop_aux_2/4, [+, +, +, -]).
:- measure(loop_aux_2/4, [length, void, void, length]).

:- mode(aux_cond_3/5, [+, +, -, +, +]).
:- measure(aux_cond_3/5, [void, void, void, void, void]).

:- mode(loop_aux_3/4, [+, +, +, -]).
:- measure(loop_aux_3/4, [length, void, void, void]).

:- mode(aux_cond_4/5, [+, +, +, -, +]).
:- measure(aux_cond_4/5, [void, void, void, void, void]).

:- mode(loop_aux_4/10, [+, +, +, +, +, +, +, -, +, -]).
:- measure(loop_aux_4/10, [length, void, void, void, void, length, length, length, void, void]).

:- mode(aux_cond_5/14, [+, +, +, +, +, +, +, +, +, +, -, -, -, +]).
:- measure(aux_cond_5/14, [void, void, void, void, void, void, length, void, length, void, length, void, length, void]).


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
get_share(A, B, C) :-
    loop_aux_3(B, A, 0, C).
init(A, _, A, [], 0).
place_offer(A, B, C, D, E, F, G_1, G_2, G_3) :-
    get_share(C, D, H),
    aux_cond_1(H, B, F, C, A, E, G_1, G_2, G_3, D, D, E, F).
aux_cond_1(A, B, C, D, E, F, G, [offer(C, D, E, B, 1)|F], H, G, _, _, _) :-
    A>=B,
    !,
    I is C+1,
    H is I.
aux_cond_1(_, _, _, _, _, _, A_1, A_2, A_3, _, A_1, A_2, A_3).
accept_offer(A, B, C, D, E, F, G, H, F, I, J) :-
    loop_aux_4(E, B, A, C, =, D, I, H, G, J).
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_2(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_2(A, A, B, B, _) :-
    !.
aux_cond_2(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, [Elem_1|F]) :-
    aux_cond_3(A, D, Elem_1, E, B),
    loop_aux_2(C, D, E, F).
aux_cond_3(A, A, bal(A, B), B, _) :-
    !.
aux_cond_3(A, _, bal(A, B), _, B).
loop_aux_3([], _, A, A).
loop_aux_3([sh(A, B)|C], D, E, F) :-
    aux_cond_4(D, A, E, G, B),
    loop_aux_3(C, D, G, F).
aux_cond_4(A, A, 0, B, B) :-
    !.
aux_cond_4(_, _, A, A, _).
loop_aux_4([], _, _, _, _, A, B, [], A, B).
loop_aux_4([offer(A, B, C, D, E)|F], G, H, I, J, K, L, [Elem_1|M], N, O) :-
    aux_cond_5(A, H, E, I, C, G, L, B, K, D, P, Elem_1, R, offer(A, B, C, D, E)),
    loop_aux_4(F, G, H, I, J, P, R, M, N, O).
aux_cond_5(A, A, 1, B, C, D, E, F, G, H, [sh(D, I), sh(F, J)|G], offer(A, F, C, H, 0), L, _) :-
    B>=C,
    !,
    transfer(D, this, B, E, M),
    transfer(this, F, B, M, L),
    get_share(F, G, N),
    O is N-H,
    J is O,
    get_share(D, [sh(F, J)|G], P),
    Q is P+H,
    I is Q.
aux_cond_5(_, _, _, _, _, _, A, _, B, _, B, C, A, C).