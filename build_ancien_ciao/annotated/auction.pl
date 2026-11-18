:- mode(get_bal/3, [+, +, -]).
:- measure(get_bal/3, [void, length, void]).

:- mode(set_bal/4, [+, +, +, -]).
:- measure(set_bal/4, [void, void, length, length]).

:- mode(transfer/5, [+, +, +, +, -]).
:- measure(transfer/5, [void, void, int, length, length]).

:- mode(init/9, [+, +, +, +, +, +, +, +, -]).
:- measure(init/9, [int, void, int, void, void, int, void, int, int]).

:- mode(bid/15, [+, +, +, +, +, +, +, +, -, -, -, -, -, +, -]).
:- measure(bid/15, [void, void, void, void, void, void, void, void, void, void, void, void, void, length, length]).

:- mode(aux_cond_1/20, [+, +, +, +, +, +, +, +, -, -, -, -, -, -, +, +, +, +, +, +]).
:- measure(aux_cond_1/20, [void, void, void, void, void, void, length, void, length, void, void, void, void, void, void, void, void, void, void, void]).

:- mode(aux_cond_2/4, [+, +, +, -]).
:- measure(aux_cond_2/4, [void, void, length, length]).

:- mode(end/13, [+, +, +, +, +, +, -, -, -, -, -, +, -]).
:- measure(end/13, [void, void, void, void, void, void, void, void, void, void, void, length, length]).

:- mode(aux_cond_3/18, [+, +, +, +, +, +, -, -, -, -, -, -, +, +, +, +, +, +]).
:- measure(aux_cond_3/18, [void, void, void, void, void, length, length, void, void, void, void, void, void, void, void, void, void, void]).

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
init(A, B, C, _, B, D, null, 0, 0) :-
    E is C+A,
    D is E.
bid(A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5, J, K) :-
    aux_cond_1(C, E, B, G, H, A, J, F, K, I_1, I_2, I_3, I_4, I_5, D, D, E, F, G, H).
aux_cond_1(A, B, C, D, 0, E, F, G, H, I, B, E, C, 0, I, _, _, _, _, _) :-
    A<B,
    C>D,
    !,
    transfer(E, this, C, F, J),
    aux_cond_2(G, D, J, H).
aux_cond_1(_, _, _, _, _, _, A, _, A, B_1, B_2, B_3, B_4, B_5, _, B_1, B_2, B_3, B_4, B_5).
aux_cond_2(A, B, C, D) :-
    neq(A, null),
    !,
    transfer(this, A, B, C, D).
aux_cond_2(_, _, A, A).
end(A, B, C, D, E, F, G_1, G_2, G_3, G_4, G_5, H, I) :-
    aux_cond_3(A, C, F, B, E, H, I, G_1, G_2, G_3, G_4, G_5, D, B, C, D, E, F).
aux_cond_3(A, B, 0, C, D, E, F, C, B, G, D, 1, G, _, _, _, _, _) :-
    A>=B,
    !,
    transfer(this, C, D, E, F).
aux_cond_3(_, _, _, _, _, A, A, B_1, B_2, B_3, B_4, B_5, _, B_1, B_2, B_3, B_4, B_5).
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