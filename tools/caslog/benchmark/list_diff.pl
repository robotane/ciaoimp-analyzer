% diff(L1, L2, L3) is true iff L3 contains only elements in the
% lists L1 but not in the list L2.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(diff/3, [+,+,-]).
:- measure(diff/3, [length,length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

diff([], L, []).
diff([H|L1], L2, L3) :-
     memberchk(H, L2),
     !,
     diff(L1, L2, L3).
diff([H|L1], L2, [H|L3]) :-
     diff(L1, L2, L3).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(memberchk/2, [+,+]).
:- measure(memberchk/2, [length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

memberchk(X, [X|_]) :- !.
memberchk(X, [_|L]) :- memberchk(X, L).

