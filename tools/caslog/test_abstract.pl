:- mode(append/3, [+, +, -]).
:- measure(append/3, [size, size, size]).

append(0, L, L).
append(N, L, M) :- N > 0, N1 is N - 1, append(N1, L, R), M is R + 1.
