:- mode(get_bal/3, [+, +, -]).
:- measure(get_bal/3, [void, length, void]).

:- mode(set_bal/4, [+, +, +, -]).
:- measure(set_bal/4, [void, void, length, length]).

:- mode(transfer/5, [+, +, +, +, -]).
:- measure(transfer/5, [void, void, int, length, length]).

:- mode(init/4, [+, +, +, -]).
:- measure(init/4, [void, void, length, int]).

:- mode(invest/8, [+, +, +, +, -, -, +, -]).
:- measure(invest/8, [void, void, length, int, length, void, length, void]).

:- mode(aux_cond_1/10, [+, +, +, +, +, -, -, -, +, +]).
:- measure(aux_cond_1/10, [void, void, void, length, length, void, length, void, length, void]).

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
init(A, _, [A], 1000).
invest(A, B, C, D, E_1, E_2, F, G) :-
    H is D*11//10,
    I is H,
    aux_cond_1(B, I, A, F, C, G, E_1, E_2, C, D).
aux_cond_1(A, B, C, D, E, F, [C|E], A, _, _) :-
    A>=B,
    !,
    transfer(C, this, A, D, G),
    loop_aux_3(E, is, 0, H),
    I is A//H,
    J is I,
    loop_aux_4(E, J, G, F).
aux_cond_1(_, _, _, A, _, A, B_1, B_2, B_1, B_2).
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
loop_aux_3([_|A], B, C, D) :-
    E is C+1,
    loop_aux_3(A, B, E, D).
loop_aux_4([], _, A, A).
loop_aux_4([A|B], C, D, E) :-
    transfer(this, A, C, D, F),
    loop_aux_4(B, C, F, E).