% intersect(L1, L2, L3) is true iff L3 contains only elements in both the
% lists L1 and L2.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(intersect/3, [+,+,-]).
:- measure(intersect/3, [length,length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

intersect([], L, []).
intersect([H|L1], L2, [H|L3]) :-
     memberchk(H, L2),
     !,
     intersect(L1, L2, L3).
intersect([H|L1], L2, L3) :-
     intersect(L1, L2, L3).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(memberchk/2, [+,+]).
:- measure(memberchk/2, [void,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

memberchk(X, []) :- fail.
memberchk(X, [X|_]) :- !.
memberchk(X, [_|L]) :- memberchk(X, L).

