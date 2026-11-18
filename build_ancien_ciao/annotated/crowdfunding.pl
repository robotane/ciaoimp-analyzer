:- mode(get_bal/3, [+, +, -]).
:- measure(get_bal/3, [void, length, void]).

:- mode(set_bal/4, [+, +, +, -]).
:- measure(set_bal/4, [void, void, length, length]).

:- mode(transfer/5, [+, +, +, +, -]).
:- measure(transfer/5, [void, void, int, length, length]).

:- mode(init/2, [+, -]).
:- measure(init/2, [void, length]).

:- mode(new_campaign/5, [+, +, -, +, -]).
:- measure(new_campaign/5, [void, void, int, length, length]).

:- mode(contribute/7, [+, +, +, +, -, +, -]).
:- measure(contribute/7, [void, int, void, length, length, length, length]).

:- mode(check_goal_reached/6, [+, +, +, -, +, -]).
:- measure(check_goal_reached/6, [void, void, length, length, length, void]).

:- mode(loop_aux_1/4, [+, +, +, -]).
:- measure(loop_aux_1/4, [length, void, void, void]).

:- mode(aux_cond_1/5, [+, +, -, +, +]).
:- measure(aux_cond_1/5, [void, void, void, void, void]).

:- mode(loop_aux_2/4, [+, +, +, -]).
:- measure(loop_aux_2/4, [length, void, void, length]).

:- mode(aux_cond_2/5, [+, +, -, +, +]).
:- measure(aux_cond_2/5, [void, void, void, void, void]).

:- mode(loop_aux_3/6, [+, +, +, +, +, -]).
:- measure(loop_aux_3/6, [length, void, void, void, void, length]).

:- mode(aux_cond_3/10, [+, +, +, +, -, +, +, +, +, +]).
:- measure(aux_cond_3/10, [void, void, void, void, void, void, void, void, length, void]).

:- mode(loop_aux_4/8, [+, +, +, +, +, -, +, -]).
:- measure(loop_aux_4/8, [length, void, void, void, length, length, void, void]).

:- mode(aux_cond_4/13, [+, +, +, +, +, +, -, +, +, -, +, +, -]).
:- measure(aux_cond_4/13, [void, void, void, void, void, length, length, void, length, void, void, void, length]).

:- mode(aux_cond_5/12, [+, +, +, +, -, +, +, -, -, +, +, +]).
:- measure(aux_cond_5/12, [void, void, void, length, void, void, void, void, length, void, void, void]).

:- mode(len_list/2, [+, -]).
:- measure(len_list/2, [length, int]).


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
init(_, []).
new_campaign(A, B, C, D, [campaign(C, A, B, 0, [])|D]) :-
    len_list(D, C).
contribute(A, B, C, D, E, F, G) :-
    transfer(A, this, B, F, G),
    loop_aux_3(D, B, A, C, =, E).
check_goal_reached(A, B, C, D, E, F) :-
    loop_aux_4(C, A, =, 0, E, D, B, F).
loop_aux_1([], _, A, A).
loop_aux_1([bal(A, B)|C], D, E, F) :-
    aux_cond_1(A, D, G, B, E),
    loop_aux_1(C, D, G, F).
aux_cond_1(A, A, B, B, _) :-
    !.
aux_cond_1(_, _, A, _, A).
loop_aux_2([], _, _, []).
loop_aux_2([bal(A, B)|C], D, E, [Elem_1|F]) :-
    aux_cond_2(A, D, Elem_1, E, B),
    loop_aux_2(C, D, E, F).
aux_cond_2(A, A, bal(A, B), B, _) :-
    !.
aux_cond_2(A, _, bal(A, B), _, B).
loop_aux_3([], _, _, _, _, []).
loop_aux_3([campaign(A, B, C, D, E)|F], G, H, I, J, [Elem_1|K]) :-
    aux_cond_3(A, I, D, G, Elem_1, B, C, H, E, campaign(A, B, C, D, E)),
    loop_aux_3(F, G, H, I, J, K).
aux_cond_3(A, A, B, C, campaign(A, D, E, F, [funder(G, C)|H]), D, E, G, H, _) :-
    !,
    J is B+C,
    F is J.
aux_cond_3(_, _, _, _, A, _, _, _, _, A).
loop_aux_4([], _, _, A, B, [], A, B).
loop_aux_4([campaign(A, B, C, D, E)|F], G, H, I, J, K, L, M) :-
    aux_cond_4(A, G, D, C, B, J, K, E, N, O, campaign(A, B, C, D, E), I, P),
    loop_aux_4(F, G, H, O, P, N, L, M).
aux_cond_4(A, A, B, C, D, E, [Elem_1|F], G, F, I, J, K, L) :-
    !,
    aux_cond_5(B, C, D, E, Elem_1, A, G, I, L, J, K, L).
aux_cond_4(_, _, _, _, _, A, [B|C], _, C, D, B, D, A).
aux_cond_5(A, B, C, D, campaign(E, C, B, 0, F), E, F, 1, H, _, _, _) :-
    A>=B,
    !,
    transfer(this, C, A, D, H).
aux_cond_5(_, _, _, A, B, _, _, D, A, B, D, A).
len_list([], 0).
len_list([_|A], B) :-
    len_list(A, C),
    B is C+1.