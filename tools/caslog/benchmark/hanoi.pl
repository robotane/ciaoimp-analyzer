%
%  hanoi.pl			Nai-Wei Lin			November, 1991
%
%  This program plays the tower of hanoi game.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(append/3,[+,+,-]). 
:- measure(append/3,[length,length,length]). 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
append([],L,L).
append([X|L1],L2,[X|L3]) :-
	append(L1,L2,L3).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(hanoi/5,[+,+,+,+,-]).
:- measure(hanoi/5,[int,void,void,void,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
hanoi(1,A,B,C,[mv(A,C)]).
hanoi(N,A,B,C,M) :-
	N > 1,
	N1 is N - 1,
	hanoi(N1,A,C,B,M1),
	hanoi(N1,B,A,C,M2),
	append(M1,[mv(A,C)],T),
	append(T,M2,M).
