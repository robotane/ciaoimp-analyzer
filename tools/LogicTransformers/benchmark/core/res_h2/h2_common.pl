% Predicats communs aux runners H2 (Ciao, Prolog Cafe, SWI-Prolog).
%
% h2_pt/1 imprime un terme en syntaxe Prolog relisible, identique d'un
% moteur a l'autre : les variables sont imprimees '_' et les listes sont
% traitees explicitement (le foncteur de liste differe entre moteurs).

h2_split((A, B), Pre, T) :- !,
    h2_split(B, P1, T),
    h2_conj(A, P1, Pre).
h2_split(G, true, G).

h2_conj(A, true, A) :- !.
h2_conj(A, P, (A, P)).

h2_pt(T) :- var(T), !, write(user_output, '_').
h2_pt([]) :- !, write(user_output, '[]').
h2_pt([H|T]) :- !, write(user_output, '['), h2_pt(H), h2_ptl(T).
h2_pt(T) :- atomic(T), !, writeq(user_output, T).
h2_pt(T) :-
    T =.. [F|As],
    writeq(user_output, F), write(user_output, '('), h2_pta(As), write(user_output, ')').

h2_ptl(T) :- var(T), !, write(user_output, '|_]').
h2_ptl([]) :- !, write(user_output, ']').
h2_ptl([H|T]) :- !, write(user_output, ','), h2_pt(H), h2_ptl(T).
h2_ptl(T) :- write(user_output, '|'), h2_pt(T), write(user_output, ']').

h2_pta([A]) :- !, h2_pt(A).
h2_pta([A|As]) :- h2_pt(A), write(user_output, ','), h2_pta(As).
