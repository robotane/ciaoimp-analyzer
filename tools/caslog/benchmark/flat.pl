%
%  flat.pl			Nai-Wei Lin			November 1991
%
%  This program flattens a term into a list of atom.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(flat/2,[+,-]).
:- measure(flat/2,[size,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
flat(X,[X]) :-
	atomic(X),!.
flat(X,[F|List]) :-
	functor(X,F,N),
	flat3(N,X,List).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(flat3/3,[+,+,-]).
:- measure(flat3/3,[int,size,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
flat3(0,_,[]).
flat3(N,X,List) :-
	N > 0,
	arg(N,X,Arg),
	flat(Arg,List1),
	N1 is N-1,
	flat3(N1,X,List2),
	append(List1,List2,List).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(append/3,[+,+,-]).
:- measure(append/3,[length,length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
append([],L,L).
append([H|L],L1,[H|R]) :-
	append(L,L1,R).
