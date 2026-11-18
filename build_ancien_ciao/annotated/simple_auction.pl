:- mode(get_bal/3, [+, +, -]).
:- measure(get_bal/3, [void, length, void]).

:- mode(set_bal/4, [+, +, +, -]).
:- measure(set_bal/4, [void, void, length, length]).

:- mode(transfer/5, [+, +, +, +, -]).
:- measure(transfer/5, [void, void, int, length, length]).

:- mode(init/8, [+, +, +, +, +, +, +, -]).
:- measure(init/8, [int, void, int, void, void, int, int, void]).

:- mode(bid/13, [+, +, +, +, +, +, +, -, -, -, -, +, -]).
:- measure(bid/13, [void, void, void, void, void, void, void, void, void, void, void, length, length]).

:- mode(aux_cond_1/17, [+, +, +, +, +, +, +, -, -, -, -, -, +, +, +, +, +]).
:- measure(aux_cond_1/17, [void, void, void, void, void, length, void, length, void, void, void, void, void, void, void, void, void]).

:- mode(aux_cond_2/4, [+, +, +, -]).
:- measure(aux_cond_2/4, [void, void, length, length]).

:- mode(auction_end/11, [+, +, +, +, +, -, -, -, -, +, -]).
:- measure(auction_end/11, [void, void, void, void, void, void, void, void, void, length, length]).

:- mode(aux_cond_3/15, [+, +, +, +, +, +, -, -, -, -, -, +, +, +, +]).
:- measure(aux_cond_3/15, [void, void, void, void, void, length, length, void, void, void, void, void, void, void, void]).

:- mode(loop_aux_1/4, [+, +, +, -]).
:- measure(loop_aux_1/4, [length, void, void, void]).

:- mode(aux_cond_4/5, [+, +, -, +, +]).
:- measure(aux_cond_4/5, [void, void, void, void, void]).

:- mode(loop_aux_2/4, [+, +, +, -]).
:- measure(loop_aux_2/4, [length, void, void, length]).

:- mode(aux_cond_5/5, [+, +, -, +, +]).
:- measure(aux_cond_5/5, [void, void, void, void, void]).

:- mode(neq/2, [+, +]).
:- measure(neq/2, [void, void]).


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
init(A, B, C, _, B, D, 0, null) :-
    E is C+A,
    D is E.
bid(A, B, C, D, E, F, G, H_1, H_2, H_3, H_4, I, J) :-
    aux_cond_1(C, E, B, F, A, I, G, J, H_1, H_2, H_3, H_4, D, D, E, F, G).
aux_cond_1(A, B, C, D, E, F, G, H, I, B, C, E, I, _, _, _, _) :-
    A<B,
    C>D,
    !,
    transfer(E, this, C, F, J),
    aux_cond_2(G, D, J, H).
aux_cond_1(_, _, _, _, _, A, _, A, B_1, B_2, B_3, B_4, _, B_1, B_2, B_3, B_4).
aux_cond_2(A, B, C, D) :-
    neq(A, null),
    !,
    transfer(this, A, B, C, D).
aux_cond_2(_, _, A, A).
auction_end(A, B, C, D, E, F_1, F_2, F_3, F_4, G, H) :-
    aux_cond_3(A, C, E, B, D, G, H, F_1, F_2, F_3, F_4, B, C, D, E).
aux_cond_3(A, B, C, D, E, F, G, D, B, E, null, _, _, _, _) :-
    A>=B,
    neq(C, null),
    !,
    transfer(this, D, E, F, G).
aux_cond_3(_, _, _, _, _, A, A, B_1, B_2, B_3, B_4, B_1, B_2, B_3, B_4).
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_4(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_4(A, A, B, B, _) :-
    !.
aux_cond_4(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, [Elem_1|F]) :-
    aux_cond_5(A, D, Elem_1, E, B),
    loop_aux_2(C, D, E, F).
aux_cond_5(A, A, bal(A, B), B, _) :-
    !.
aux_cond_5(A, _, bal(A, B), _, B).
neq(A, B) :-
    A\==B.