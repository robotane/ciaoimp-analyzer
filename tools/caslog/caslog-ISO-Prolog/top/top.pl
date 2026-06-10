%
%  top.pl			Nai-Wel Lin			December, 1991
%
%  This file contains the top level procedures for the system.
%

%
%  Top-level predicate of CASLOG in interactive mode.
%
caslog(Files) :- 
	nl,
	write('Caslog 1.0, April 1992.'),nl,
	statistics(runtime,[_,_]),
%	read_prog(Files),
	top(Files),
	statistics(runtime,[_,T]),
	nl, write('{Exexution Time: '),
	write(T), write(' msec}'), nl,
	nl,
	write('{End of Caslog execution.}'),nl,!.

%%%
read_prog([]).
read_prog([File|Fs]) :-
	see(File),
	r_prog,
	seen,
	read_prog(Fs).

r_prog :-
	read(Clause),
	(Clause \== end_of_file -> 
		 r_prog;
		 true).
%%%

top(Files) :-
	init_system(Files,BT,ST,SCCG,Error1),
	analysis_check(SCCG,ST,Error2),
	Error is Error1*Error2,
	(Error =:= 1 ->
		analysis(SCCG,BT,ST);
		true).

analysis([],_,_).
analysis([Comp|SCCG],BT,ST) :-
%	write('start dependency analysis'),nl,
	dependency_analysis(Comp,BT,ST,Adg,Ldg,Gvars,Error),
	%write(Adg),nl,
	%write(Ldg),nl,
	%write(Gvars),nl,
	(Error =:= 1 ->
		(%write('start size analysis'),nl,
	%	write('\nST :'),write(ST),	
		
	%	write('\nComp : '),write(Comp),
	%	write('\nadg :'),write(Adg),
		
		 size_analysis(Comp,BT,ST,Comp,Adg,Gvars,Size),
		 print_size(Comp,ST),
		flush_output,
		%write('start relation analysis'),nl,
		 relation_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		 print_relation(Comp,ST),
		flush_output,
		 %write('start solution analysis'),nl,
	%	write('\nSTdeterm :'),write(ST),
		 
		 determinacy_analysis(Comp,BT,ST,Adg),
	%	 write('\n***********************************************'),
	%	 write('\nSTsol_analyse'),write(ST),
		% write('\nComp= '),write(Comp),
		%write('\nAdg='),write(Adg),
		% write('\nSize='),write(Size),
		% write('\nGvars = '),write(Gvars),
		% write('\nLdg='),write(Ldg),
		% write('\n***********************************************'),
		 solution_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		 print_solution(Comp,ST),
		flush_output,
		
		 %write('start time analysis'),nl,
		 time_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		 print_time(Comp,ST),
		flush_output,!,
		 analysis(SCCG,BT,ST)
		);
		true).

%
%  Top-level predicate of CASLOG in batch mode.
%
caslog(Complexity,File) :-
	(legal_complexity(Complexity) ->
		(init_system(File,BT,ST,SCCG,Error1),
		 analysis_check(SCCG,ST,Error2),
%		 direct_recursive_check(SCCG,Error3),
		 Error3 = 1,
		 Error is Error1*Error2*Error3,
		 (Error =:= 1 ->
			analysis(Complexity,SCCG,BT,ST);
			true));
		true).

%
%  Check if the complexity name is legal.
%
legal_complexity(size).
legal_complexity(solution).
legal_complexity(time).
legal_complexity(all).
legal_complexity(Complexity) :-
	Complexity \== size,
	Complexity \== solution,
	Complexity \== time,
	Complexity \== all,
	error_message(comp1,Complexity,''),
	fail.

%
%  Analyze the program.
%
analysis(size,SCCG,BT,ST) :-
	size_analysis(SCCG,BT,ST).
/*
	size_analysis_check(SCCG,ST,Error),
	(Error =:= 1 ->
		size_analysis(SCCG,BT,ST);
		true).
*/
analysis(solution,SCCG,BT,ST) :-
	solution_analysis(SCCG,BT,ST).
/*
	solution_analysis_check(SCCG,ST,Error),
	(Error =:= 1 ->
		solution_analysis(SCCG,BT,ST);
		true).
*/
analysis(time,SCCG,BT,ST) :-
	time_analysis(SCCG,BT,ST).
/*
	time_analysis_check(SCCG,ST,Error),
	(Error =:= 1 ->
		time_analysis(SCCG,BT,ST);
		true).
*/
analysis(all,SCCG,BT,ST) :-
	all_analysis(SCCG,BT,ST).


%
%  Perform the argument size analysis.
%
size_analysis([],_,_).
size_analysis([Comp|SCCG],BT,ST) :-
	dependency_analysis(Comp,BT,ST,Adg,_,Gvars,Error),
	(Error =:= 1 ->
		(size_analysis(Comp,BT,ST,Comp,Adg,Gvars,_),
		 print_size(Comp,ST),
		 size_analysis(SCCG,BT,ST));
		true).

%
%  Perform the relation size and solution size analysis.
%
solution_analysis([],_,_).
solution_analysis([Comp|SCCG],BT,ST) :-
	dependency_analysis(Comp,BT,ST,Adg,Ldg,Gvars,Error),
	(Error =:= 1 ->
		(size_analysis(Comp,BT,ST,Comp,Adg,Gvars,Size),
		%print_size(Comp,ST),
		 relation_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		 print_relation(Comp,ST),
		 solution_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		 print_solution(Comp,ST),
		 solution_analysis(SCCG,BT,ST));
		true).

%
%  Perform the time analysis.
%
time_analysis([],_,_).
time_analysis([Comp|SCCG],BT,ST) :-
	dependency_analysis(Comp,BT,ST,Adg,Ldg,Gvars,Error),
	(Error =:= 1 ->
		(size_analysis(Comp,BT,ST,Comp,Adg,Gvars,Size),
		%print_size(Comp,ST),
		 relation_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		%print_relation(Comp,ST),
		 solution_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		%print_solution(Comp,ST),
		 time_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		 print_time(Comp,ST),
		 time_analysis(SCCG,BT,ST));
		true).

%
%  Perform all the complexity analysis.
%
all_analysis([],_,_).
all_analysis([Comp|SCCG],BT,ST) :-
	dependency_analysis(Comp,BT,ST,Adg,Ldg,Gvars,Error),
	(Error =:= 1 ->
		(size_analysis(Comp,BT,ST,Comp,Adg,Gvars,Size),
		 print_size(Comp,ST),
		 relation_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		 print_relation(Comp,ST),
		 solution_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		 print_solution(Comp,ST),
		 time_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,_),
		 print_time(Comp,ST),
		 all_analysis(SCCG,BT,ST));
		true).

%
%
direct_recursive_check([],1).
direct_recursive_check([Comp|SCCG],Error) :-
	Comp = [_],
	direct_recursive_check(SCCG,Error).
direct_recursive_check([Comp|SCCG],0) :-
	Comp = [_|_],
	write('* caslog error: cannot handle indirect recursion'),
	nl,
	direct_recursive_check(SCCG,_).
