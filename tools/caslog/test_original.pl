:- mode(append/3, [+, +, -]).
:- measure(append/3, [size, size, size]).

append([], L, L).
append([H|T], L, [H|R]) :- append(T, L, R).
