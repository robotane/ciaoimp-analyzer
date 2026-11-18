:- mode(get_owner/3, [+, +, -]).
:- measure(get_owner/3, [void, length, void]).

:- mode(get_nft_bal/3, [+, +, -]).
:- measure(get_nft_bal/3, [void, length, void]).

:- mode(init/7, [+, +, +, +, +, +, -]).
:- measure(init/7, [void, void, void, void, void, length, length]).

:- mode(mint/10, [+, +, +, +, +, +, -, -, -, -]).
:- measure(mint/10, [void, void, void, void, length, length, void, void, length, length]).

:- mode(aux_cond_1/15, [+, +, +, +, +, -, -, -, -, +, +, +, +, +, +]).
:- measure(aux_cond_1/15, [void, void, void, length, length, void, void, length, length, void, void, void, void, length, length]).

:- mode(transferFrom/12, [+, +, +, +, +, +, +, +, -, -, -, -]).
:- measure(transferFrom/12, [void, void, void, void, void, void, length, length, void, void, length, length]).

:- mode(aux_cond_2/17, [+, +, +, +, +, +, +, -, -, -, -, +, +, +, +, +, +]).
:- measure(aux_cond_2/17, [void, void, void, length, void, void, length, void, void, length, length, void, void, void, void, length, length]).

:- mode(loop_aux_1/4, [+, +, +, -]).
:- measure(loop_aux_1/4, [length, void, void, void]).

:- mode(aux_cond_3/5, [+, +, +, -, +]).
:- measure(aux_cond_3/5, [void, void, void, void, void]).

:- mode(loop_aux_2/4, [+, +, +, -]).
:- measure(loop_aux_2/4, [length, void, void, void]).

:- mode(aux_cond_4/5, [+, +, +, -, +]).
:- measure(aux_cond_4/5, [void, void, void, void, void]).


get_owner(A, B, C) :-
    loop_aux_1(B, A, null, C).
get_nft_bal(A, B, C) :-
    loop_aux_2(B, A, 0, C).
init(A, B, _, A, B, [], []).
mint(A, B, C, D, E, F, G_1, G_2, G_3, G_4) :-
    get_owner(B, E, H),
    aux_cond_1(H, B, A, E, F, G_1, G_2, G_3, G_4, C, D, C, D, E, F).
aux_cond_1(null, A, B, C, D, E, F, [t_o(A, B)|C], [n_b(B, G)|D], E, F, _, _, _, _) :-
    !,
    get_nft_bal(B, D, H),
    I is H+1,
    G is I.
aux_cond_1(_, _, _, _, _, A_1, A_2, A_3, A_4, _, _, A_1, A_2, A_3, A_4).
transferFrom(A, B, C, D, E, F, G, H, I_1, I_2, I_3, I_4) :-
    get_owner(C, G, J),
    aux_cond_2(J, A, D, H, B, C, G, I_1, I_2, I_3, I_4, E, F, E, F, G, H).
aux_cond_2(A, A, A, B, C, D, E, F, G, [t_o(D, C)|E], [n_b(C, H), n_b(A, I)|B], F, G, _, _, _, _) :-
    !,
    get_nft_bal(A, B, J),
    K is J-1,
    I is K,
    get_nft_bal(C, [n_b(A, I)|B], L),
    M is L+1,
    H is M.
aux_cond_2(_, _, _, _, _, _, _, A_1, A_2, A_3, A_4, _, _, A_1, A_2, A_3, A_4).
loop_aux_1([], _, A, A).
loop_aux_1([t_o(A, B)|C], D, E, F) :-
    aux_cond_3(A, D, E, G, B),
    loop_aux_1(C, D, G, F).
aux_cond_3(A, A, null, B, B) :-
    !.
aux_cond_3(_, _, A, A, _).
loop_aux_2([], _, A, A).
loop_aux_2([n_b(A, B)|C], D, E, F) :-
    aux_cond_4(A, D, E, G, B),
    loop_aux_2(C, D, G, F).
aux_cond_4(A, A, 0, B, B) :-
    !.
aux_cond_4(_, _, A, A, _).