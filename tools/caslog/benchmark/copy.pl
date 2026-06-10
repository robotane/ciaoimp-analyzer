%
%  copy.pl			Nai-Wei Lin			November 1991
%
%  This program generates a copy a term.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(copy/2,[+,-]).
:- measure(copy/2,[size,size]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
copy(X,X) :-
	atomic(X),!.
copy(X,Y) :-
	functor(X,F,N),
	functor1(Y1,F,N),
	copy1(N,X,Y1,Y).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(copy1/4,[+,+,+,-]).
:- measure(copy1/4,[int,size,size,size]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
copy1(0,_,Y,Y).
copy1(N,X,Y,Z) :-
	N > 0,
	arg(N,X,Arg),
	copy(Arg,Arg1),
	N1 is N-1,
	copy1(N1,X,Y,Y1),
	arg(N,Y1,Arg1,Z).
