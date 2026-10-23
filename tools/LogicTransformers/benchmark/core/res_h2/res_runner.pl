% Runner portable (SWI-Prolog, Prolog Cafe) pour le comptage de resolutions.
%
% A concatener apres P_n instrumente et les faits generes :
%     res_scen(N, Corps).          % corps du goal du benchmark, taille N
%     res_modes([+, -, ...]).      % modes du predicat cible (fichier annote)
%     res_measures([length, ...]). % mesures du predicat cible
%
% Le dernier conjoint du corps est l'appel cible ; les conjoints precedents
% (init, bid...) preparent l'etat et ne sont pas comptes.
%
% Sortie, une ligne par N :
%     RES|N|Succes|Resolutions1|NbSolutions|ResolutionsToutes|Tailles

:- dynamic(res_cnt/1).

res_inc :-
    retract(res_cnt(N)), !,
    N1 is N + 1,
    assertz(res_cnt(N1)).

res_reset :-
    retractall(res_cnt(_)),
    assertz(res_cnt(0)).

res_split((A, B), Pre, T) :- !,
    res_split(B, P1, T),
    res_conj(A, P1, Pre).
res_split(G, true, G).

res_conj(A, true, A) :- !.
res_conj(A, P, (A, P)).

res_main :-
    res_reset,
    res_scen(N, Body),
    res_one(N, Body),
    fail.
res_main.

res_one(N, Body) :-
    res_split(Body, Pre, T),
    (   call(Pre)
    ->  copy_term(T, T2),
        res_sizes(T, Sz),
        res_reset,
        (   call(T) -> S1 = 1 ; S1 = 0 ),
        res_cnt(C1),
        res_reset,
        findall(x, call(T2), L),
        length(L, NS),
        res_cnt(C2),
        write(user_output, 'RES|'), write(user_output, N), write(user_output, '|'), write(user_output, S1), write(user_output, '|'),
        write(user_output, C1), write(user_output, '|'), write(user_output, NS), write(user_output, '|'), write(user_output, C2), write(user_output, '|'),
        writeq(user_output, Sz), nl(user_output)
    ;   write(user_output, 'RES|'), write(user_output, N), write(user_output, '|PREFAIL'), nl(user_output)
    ).

% Tailles des arguments d'entree selon les mesures CasLog.
res_sizes(T, Sz) :-
    T =.. [_|Args],
    res_modes(Mds),
    res_measures(Ms),
    res_sz(Args, Ms, Mds, 1, Sz).

res_sz([], _, _, _, []) :- !.
res_sz([A|As], [M|Ms], [Md|Mds], I, Out) :-
    I1 is I + 1,
    (   Md == (+), res_msize(M, A, S)
    ->  Out = [I-S|R]
    ;   Out = R
    ),
    res_sz(As, Ms, Mds, I1, R).

res_msize(length, A, S) :- res_plist(A, 0, S).
res_msize(int, A, A) :- integer(A).
res_msize(size, A, S) :- res_tsize(A, S).

res_plist(L, _, _) :- var(L), !, fail.
res_plist([], N, N) :- !.
res_plist([_|T], N0, N) :-
    N1 is N0 + 1,
    res_plist(T, N1, N).

res_tsize(T, 1) :- var(T), !.
res_tsize(T, 1) :- atomic(T), !.
res_tsize(T, S) :-
    T =.. [_|As],
    res_tsl(As, 1, S).

res_tsl([], S, S).
res_tsl([A|As], S0, S) :-
    res_tsize(A, SA),
    S1 is S0 + SA,
    res_tsl(As, S1, S).
