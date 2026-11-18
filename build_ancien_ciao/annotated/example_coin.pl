:- mode(get_tok_bal/3, [+, +, -]).
:- measure(get_tok_bal/3, [void, length, void]).

:- mode(init/9, [+, +, +, +, +, +, +, +, -]).
:- measure(init/9, [void, void, void, void, void, void, void, int, length]).

:- mode(token_transfer/13, [+, +, +, +, +, +, +, +, -, -, -, -, -]).
:- measure(token_transfer/13, [void, void, void, void, void, void, void, length, void, void, void, void, length]).

:- mode(aux_cond_1/19, [+, +, +, +, +, -, -, -, -, -, +, +, +, +, +, +, +, +, +]).
:- measure(aux_cond_1/19, [void, void, void, length, void, void, void, void, void, length, void, void, void, void, void, void, void, void, length]).

:- mode(mint/13, [+, +, +, +, +, +, +, +, -, -, -, -, -]).
:- measure(mint/13, [void, void, void, void, void, void, void, length, void, void, void, void, length]).

:- mode(aux_cond_2/18, [+, +, +, +, +, +, -, -, -, -, -, +, +, +, +, +, +, +]).
:- measure(aux_cond_2/18, [void, void, void, length, void, void, void, void, void, void, length, void, void, void, void, void, void, length]).

:- mode(burn/13, [+, +, +, +, +, +, +, +, -, -, -, -, -]).
:- measure(burn/13, [void, void, void, void, void, void, void, length, void, void, void, void, length]).

:- mode(aux_cond_3/19, [+, +, +, +, +, +, +, -, -, -, -, -, +, +, +, +, +, +, +]).
:- measure(aux_cond_3/19, [void, void, void, void, void, length, void, void, void, void, void, length, void, void, void, void, void, void, length]).

:- mode(loop_aux_1/4, [+, +, +, -]).
:- measure(loop_aux_1/4, [length, void, void, void]).

:- mode(aux_cond_4/5, [+, +, +, -, +]).
:- measure(aux_cond_4/5, [void, void, void, void, void]).


get_tok_bal(A, B, C) :-
    loop_aux_1(B, A, 0, C).
init(A, B, C, _, A, B, C, 1000000, [tb(C, 1000000)]).
token_transfer(A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5) :-
    get_tok_bal(C, H, J),
    aux_cond_1(J, B, C, H, A, I_1, I_2, I_3, I_4, I_5, D, E, F, G, D, E, F, G, H).
aux_cond_1(A, B, C, D, E, F, G, H, I, [tb(E, J), tb(C, K)|D], F, G, H, I, _, _, _, _, _) :-
    A>=B,
    !,
    L is A-B,
    K is L,
    get_tok_bal(E, [tb(C, K)|D], M),
    N is M+B,
    J is N.
aux_cond_1(_, _, _, _, _, A_1, A_2, A_3, A_4, A_5, _, _, _, _, A_1, A_2, A_3, A_4, A_5).
mint(A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5) :-
    aux_cond_2(C, F, A, H, B, G, I_1, I_2, I_3, I_4, I_5, D, E, D, E, F, G, H).
aux_cond_2(A, A, B, C, D, E, F, G, A, H, [tb(B, I)|C], F, G, _, _, _, _, _) :-
    !,
    get_tok_bal(B, C, J),
    K is J+D,
    I is K,
    L is E+D,
    H is L.
aux_cond_2(_, _, _, _, _, _, A_1, A_2, A_3, A_4, A_5, _, _, A_1, A_2, A_3, A_4, A_5).
burn(A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4, I_5) :-
    get_tok_bal(A, H, J),
    aux_cond_3(C, F, J, B, A, H, G, I_1, I_2, I_3, I_4, I_5, D, E, D, E, F, G, H).
aux_cond_3(A, A, B, C, D, E, F, G, H, A, I, [tb(D, J)|E], G, H, _, _, _, _, _) :-
    B>=C,
    !,
    K is B-C,
    J is K,
    L is F-C,
    I is L.
aux_cond_3(_, _, _, _, _, _, _, A_1, A_2, A_3, A_4, A_5, _, _, A_1, A_2, A_3, A_4, A_5).
loop_aux_1([], _, A, A).
loop_aux_1([tb(A, B)|C], D, E, F) :-
    aux_cond_4(A, D, E, G, B),
    loop_aux_1(C, D, G, F).
aux_cond_4(A, A, 0, B, B) :-
    !.
aux_cond_4(_, _, A, A, _).