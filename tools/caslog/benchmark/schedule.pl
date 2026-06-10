%
%  schedule.pl			Nai-Wei Lin			April, 1992
%
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(schedule/1,[-]).
:- measure(schedule/1,[void]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
schedule(MinTime) :-
	findall(G,legal_schedule(A,B,C,D,E,F,G),Time),
	earliest_completion(Time,MinTime).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(legal_schedule/7,[-,-,-,-,-,-,-]).
:- measure(legal_schedule/7,[int,int,int,int,int,int,int]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
legal_schedule(A,B,C,D,E,F,G) :-
	generator(7,10,[A,B,C,D,E,F,G]),
	schedule_constraints(A,B,C,D,E,F,G).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(schedule_constraints/7,[+,+,+,+,+,+,+]).
:- measure(schedule_constraints/7,[int,int,int,int,int,int,int]).
:- domain(schedule_constraints/7,[1-10,1-10,1-10,1-10,1-10,1-10,1-10]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
schedule_constraints(A,B,C,D,E,F,G) :-
	precedence_constraints(A,B,C,D,E,F,G),
	distance_constraints(B,C,D).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(precedence_constraints/7,[+,+,+,+,+,+,+]).
:- measure(precedence_constraints/7,[int,int,int,int,int,int,int]).
:- domain(precedence_constraints/7,[1-10,1-10,1-10,1-10,1-10,1-10,1-10]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
precedence_constraints(A,B,C,D,E,F,G) :-
	B >= A+1,
	C >= A+1,
	D >= A+1,
	E >= B+5,
	E >= C+3,
	F >= D+5,
	F >= E+2,
	G >= F+1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(distance_constraints/3,[+,+,+]).
:- measure(distance_constraints/3,[int,int,int]).
:- domain(distance_constraints/3,[1-10,1-10,1-10]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
distance_constraints(B,C,D) :- C >= B+1.
distance_constraints(B,C,D) :- D >= C+1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(generator/3,[+,+,-]).
:- measure(generator/3,[int,int,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
generator(0,_,[]).
generator(M,N,[Q|L]) :-
	M > 0,
	choose(N,Q),
	M1 is M-1,
	generator(M1,N,L).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(choose/2,[+,-]).
:- measure(choose/2,[int,int]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
choose(N,N) :- N > 0.
choose(N,M) :- N > 0, N1 is N-1, choose(N1,M).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(earliest_completion/2,[+,-]).
:- measure(earliest_completion/2,[length,void]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
earliest_completion([],10000).
earliest_completion([T|Time],MinTime) :-
	earliest_completion(Time,MTime),
	min(T,MTime,MinTime).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(min/3,[+,+,-]).
:- measure(min/3,[void,void,void]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
min(X,Y,X) :- X =< Y.
min(X,Y,Y) :- X > Y.
