:- mode(p/1, [+]).
:- measure(p/1, [size]).

:- mode(u/3, [+, +, -]).
:- measure(u/3, [size, size, size]).

u(A, B, arr(A, B)).

p(true).

p(A) :-
	u(B, get_bal, C),
	u(0, C, D),
	u([], D, E),
	u(F, E, A),
	p(B).
