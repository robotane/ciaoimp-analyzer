:- mode(get_bal/3, [+, +, -]).
:- measure(get_bal/3, [void, length, void]).

:- mode(set_bal/4, [+, +, +, -]).
:- measure(set_bal/4, [void, void, length, length]).

:- mode(transfer/5, [+, +, +, +, -]).
:- measure(transfer/5, [void, void, int, length, length]).

:- mode(init/3, [+, +, -]).
:- measure(init/3, [void, void, int]).

:- mode(invest/8, [+, +, +, +, -, -, +, -]).
:- measure(invest/8, [void, void, void, int, void, void, length, length]).

:- mode(aux_cond_1/10, [+, +, +, +, +, -, -, -, +, +]).
:- measure(aux_cond_1/10, [void, void, void, length, void, length, void, void, void, void]).

:- mode(aux_cond_2/4, [+, +, +, -]).
:- measure(aux_cond_2/4, [void, void, length, length]).

:- mode(loop_aux_1/4, [+, +, +, -]).
:- measure(loop_aux_1/4, [length, void, void, void]).

:- mode(aux_cond_3/5, [+, +, -, +, +]).
:- measure(aux_cond_3/5, [void, void, void, void, void]).

:- mode(loop_aux_2/4, [+, +, +, -]).
:- measure(loop_aux_2/4, [length, void, void, length]).

:- mode(aux_cond_4/5, [+, +, -, +, +]).
:- measure(aux_cond_4/5, [void, void, void, void, void]).

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
    set_bal(A, H, D, I),
    get_bal(B, I, J),
    K is J,
    L is K+C,
    set_bal(B, L, I, E).
init(_, null, 0).
invest(A, B, C, D, E_1, E_2, F, G) :-
    H is D*11//10,
    aux_cond_1(B, H, A, F, C, G, E_1, E_2, C, D).
aux_cond_1(A, B, C, D, E, F, C, A, _, _) :-
    A>B,
    !,
    transfer(C, this, A, D, G),
    aux_cond_2(E, A, G, F).
aux_cond_1(_, _, _, A, _, A, B_1, B_2, B_1, B_2).
aux_cond_2(A, B, C, D) :-
    neq(A, null),
    !,
    transfer(this, A, B, C, D).
aux_cond_2(_, _, A, A).
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_3(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_3(A, A, B, B, _) :-
    !.
aux_cond_3(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, [Elem_1|F]) :-
    aux_cond_4(A, D, Elem_1, E, B),
    loop_aux_2(C, D, E, F).
aux_cond_4(A, A, bal(A, B), B, _) :-
    !.
aux_cond_4(A, _, bal(A, B), _, B).
neq(A, B) :-
    A\==B.