% Runner Ciao pour la variante xsyntax (CF-4 / H2).
%
% A inclure apres la source xsyntax (sans goal/1) et les faits :
%     h2_xscen(N, Corps).
%
% Pour chaque N, on execute le dernier conjoint (appel cible) apres la
% preparation, puis on imprime chaque argument aplati a la maniere de
% destate : un argument state(V1, ..., Vk) (ou *_state) devient V1, ..., Vk.
% Un argument libre avant l'appel est marque out, sinon in.
%
% Sortie :
%     H2X|N|PREFAIL
%     H2X|N|NbSolutions|Foncteur|[in([...]), out([...]), ...]   (1re solution)

h2_main :-
    h2_xscen(N, Body),
    h2_one(N, Body),
    fail.
h2_main.

h2_one(N, Body) :-
    h2_split(Body, Pre, T),
    (   call(Pre)
    ->  T =.. [F|Args0],
        h2_marks(Args0, Marks),
        copy_term(T, T2),
        findall(T2, call(T2), Sols),
        length(Sols, NS),
        write(user_output, 'H2X|'), write(user_output, N), write(user_output, '|'), write(user_output, NS), write(user_output, '|'),
        writeq(user_output, F), write(user_output, '|'),
        (   Sols = [S1|_]
        ->  S1 =.. [_|Args1],
            h2_tag(Args1, Marks, Tagged),
            h2_pt(Tagged)
        ;   h2_pt(Marks)
        ),
        nl(user_output)
    ;   write(user_output, 'H2X|'), write(user_output, N), write(user_output, '|PREFAIL'), nl(user_output)
    ).

h2_marks([], []).
h2_marks([A|As], [M|Ms]) :-
    ( var(A) -> M = out ; M = in ),
    h2_marks(As, Ms).

h2_tag([], [], []).
h2_tag([A|As], [M|Ms], [E|Es]) :-
    h2_flat(A, Fl),
    E =.. [M, Fl],
    h2_tag(As, Ms, Es).

h2_flat(A, [A]) :- var(A), !.
h2_flat(A, Fs) :-
    compound(A),
    functor(A, F, _),
    h2_wrapper(F), !,
    A =.. [_|Xs],
    h2_flatl(Xs, Fs).
h2_flat(A, [A]).

h2_flatl([], []).
h2_flatl([X|Xs], Fs) :-
    h2_flat(X, F1),
    h2_flatl(Xs, F2),
    append(F1, F2, Fs).

h2_wrapper(state) :- !.
h2_wrapper(F) :-
    atom_codes(F, Cs),
    append(_, "_state", Cs).
