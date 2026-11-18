:- mode(get_bal/3, [+, +, -]).
:- measure(get_bal/3, [void, length, void]).

:- mode(set_bal/4, [+, +, +, -]).
:- measure(set_bal/4, [void, void, length, length]).

:- mode(transfer/5, [+, +, +, +, -]).
:- measure(transfer/5, [void, void, int, length, length]).

:- mode(init/3, [+, +, -]).
:- measure(init/3, [void, void, length]).

:- mode(invest/6, [+, +, +, -, +, -]).
:- measure(invest/6, [void, void, length, length, length, void]).

:- mode(aux_cond_1/7, [+, +, +, +, -, -, +]).
:- measure(aux_cond_1/7, [void, void, length, length, void, length, length]).

:- mode(loop_aux_1/4, [+, +, +, -]).
:- measure(loop_aux_1/4, [length, void, void, void]).

:- mode(aux_cond_2/5, [+, +, -, +, +]).
:- measure(aux_cond_2/5, [void, void, void, void, void]).

:- mode(loop_aux_2/4, [+, +, +, -]).
:- measure(loop_aux_2/4, [length, void, void, length]).

:- mode(aux_cond_3/5, [+, +, -, +, +]).
:- measure(aux_cond_3/5, [void, void, void, void, void]).

:- mode(loop_aux_3/3, [+, +, -]).
:- measure(loop_aux_3/3, [length, void, void]).

:- mode(loop_aux_4/4, [+, +, +, -]).
:- measure(loop_aux_4/4, [length, void, length, void]).


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
init(A, _, [A]).
invest(A, B, C, D_1, E, F) :-
    aux_cond_1(B, A, E, C, F, D_1, C).
aux_cond_1(A, B, C, D, E, [B|D], _) :-
    A>=1000,
    !,
    transfer(B, this, A, C, F),
    loop_aux_3(D, 0, G),
    H is A//G,
    I is H,
    loop_aux_4(D, I, F, E).
aux_cond_1(_, _, A, _, A, B_1, B_1).
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
loop_aux_3([], A, A).
loop_aux_3([_|A], B, C) :-
    D is B+1,
    loop_aux_3(A, D, C).
loop_aux_4([], _, A, A).
loop_aux_4([A|B], C, D, E) :-
    transfer(this, A, C, D, F),
    loop_aux_4(B, C, F, E).