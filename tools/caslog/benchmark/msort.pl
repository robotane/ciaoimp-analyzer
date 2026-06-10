%
%  msort.pl			Nai-Wei Lin			November, 1991
%
%  This program performs the mergesort on a list of integers.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(divide/3,[+,-,-]).
:- measure(divide/3,[length,length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
divide([],[],[]).
divide([X],[X],[]).
divide([X1,X2|L],[X1|L1],[X2|L2]) :-
	divide(L,L1,L2).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(merge/3,[+,+,-]).
:- measure(merge/3,[length,length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
merge(L,[],L).
merge([],L,L) :-
	L \== [].
merge([X1|L1],[X2|L2],[X1|L]) :-
	X1 >= X2,
	merge(L1,[X2|L2],L).
merge([X1|L1],[X2|L2],[X2|L]) :-
	X1 < X2,
	merge([X1|L1],L2,L).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(msort/2,[+,-]).
:- measure(msort/2,[length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
msort([],[]).
msort([X],[X]).
msort([X1,X2|L],R) :-
	divide([X1,X2|L],L1,L2),
	msort(L1,R1),
	msort(L2,R2),
	merge(R1,R2,R).
