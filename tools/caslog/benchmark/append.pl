%
%  append.pl			Nai-Wei Lin			November, 1991
%
%  This program appends two lists into one list.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(append/3,[+,+,-]).
:- measure(append/3,[length,length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
append([],L,L).
append([H|L],L1,[H|R]) :-
	append(L,L1,R).
