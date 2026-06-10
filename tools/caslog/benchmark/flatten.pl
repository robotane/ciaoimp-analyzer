%
%  flatten.pl			Nai-Wei Lin			November, 1991
%
%  This program flattens a multi-level list into a single-level list.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(append/3,[+,+,-]).
:- measure(append/3,[length,length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
append([],L,L).
append([H|L],L1,[H|R]) :-
	append(L,L1,R).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(flatten/2,[+,-]).
:- measure(flatten/2,[size,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
flatten(X,[X]) :- 
	atomic(X),
	X =\= [],!.
flatten([],[]).
flatten([X|Xs], Ys) :-
	flatten(X, Ys1), 
	flatten(Xs, Ys2),
	append(Ys1,Ys2,Ys).

