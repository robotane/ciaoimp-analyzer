%
%  qsort.pl			Nai-Wei Lin			November, 1991
%
%  This program performs the quicksort on a list of integers.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(partition/4,[+,+,-,-]).
:- measure(partition/4,[void,length,length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
partition(F,[],[],[]).
partition(F,[X|Y],[X|Y1],Y2) :- 
	X =< F, 
	partition(F,Y,Y1,Y2).
partition(F,[X|Y],Y1,[X|Y2]) :- 
	X > F,
	partition(F,Y,Y1,Y2). 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(append/3,[+,+,-]).
:- measure(append/3,[length,length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
append([],L,L).
append([H|L],L1,[H|R]) :-
	append(L,L1,R).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(qsort/2,[+,-]).
:- measure(qsort/2,[length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
qsort([],[]).
qsort([First|L1],L2) :-
	partition(First,L1,Ls,Lg), 
	qsort(Ls,Ls2), 
	qsort(Lg,Lg2),
	append(Ls2,[First|Lg2],L2).
