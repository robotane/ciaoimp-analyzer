%
%  time.pl			Nai-Wei Lin			December, 1991
%
%  This file contains the procedures for performing the time
%  analysis for the predicates in the program in topologically sorted order.
%

%
%  Perform the time analysis for a strongly connected component.
%
time_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,Time) :-
%write('\n=BT'),write(BT),write('\nST='),write(ST),
%remove_recursive_comp3(arg($(0,1),1),BT,ST,2,Sol),
%write('\nSol='),write(Sol),
	time_analysis(Comp,BT,ST,Comp,Size,Adg,Gvars,Ldg,[],[],Lout,Time),removeTime_lout(Lout,BT,ST).

removeTime_lout([],_,_).
removeTime_lout([L|Lout],BT,ST):-
	ith_list_cas_element(3,L,Equ),general_form(Equ,GEqu),
	ith_list_cas_element(2,L,BE),

	ith_list_cas_element(4,L,Var),

	ith_list_cas_element(1,L,Pred),
	remove_recursive_depends([GEqu],BT,ST,Pred,time,Solrm),Solrm=[Sol],
	normal_form(Sol,NEqu),
	write_purrs(BE,NEqu,Var,Pred,time),removeTime_lout(Lout,BT,ST).
	







time_analysis([],_,_,_,_,_,_,_,_,Lin,Lin,[]).
time_analysis([Pred|CompList],BT,ST,Comp,[Size|SList],[Adg|AList],
	      [Gvars|GList],[Ldg|LList],RTime,Lin,Lout,[Time|TList]) :-
	find_symbol_field_time(ST,Pred,time,Time1),
	(var(Time1) ->
	    (find_symbol_field_clause(ST,Pred,clause,Clauses),
	    time_clauses(Clauses,BT,ST,Comp,Size,Adg,Gvars,Ldg,RTime,Time2),
	    %write('\nTime2='),write(Time2),nl,
		 solve_complexity_equ(Pred,ST,Comp,Time2,Size,Lin,Lout1,TTime),
		 Time3 = [TTime]);
		Time3 = Time1),
	%	write('\nTime3='),write(Time3),nl,
		time_analysis(CompList,BT,ST,Comp,SList,AList,GList,LList,[comp(Pred,Time3)|RTime],Lout1,Lout,TList),
		remove_recursive_comps(Time3,BT,ST,time,Time),
		insert_symbol_field_time(ST,Pred,time,Time).

/*
%
%  Perform the time analysis for a predicate.
%
time_predicate(Pred,BT,ST,Comp,Size,Adg,Gvars,Ldg,Time) :-
	find_symbol_field_time(ST,Pred,time,Time1),
	(var(Time1) ->
		(find_symbol_field_clause(ST,Pred,clause,Clauses),
		 time_clauses(Clauses,BT,ST,Comp,Size,Adg,Gvars,Ldg,Time2),
		 find_symbol_field_mutex(ST,Pred,mutex,Mutex),
		 solve_comp_equs(Pred,ST,Comp,Time2,Size,Mutex,Time),
		 insert_symbol_field_time(ST,Pred,time,[Time]));
		Time = Time1).
*/

%
%  Perform the time analysis for the set of clauses in a predicate.
%
time_clauses(Clauses,_,_,_,_,_,_,_,_,[]) :-
	var(Clauses).
time_clauses(Clauses,BT,ST,Comp,[Size|SList],[Adg|AList],[Gvars|GList],
	     [Ldg|LList],RTime,[Time|TList]) :-
	nonvar(Clauses),
	Clauses = [Clause|CList],
%write('\nClause='),write(Clause),
	time_clause(Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,RTime,Time1),
	simplification(Time1,Time),
	time_clauses(CList,BT,ST,Comp,SList,AList,GList,LList,RTime,TList).

%
%  Perform the time analysis for a clause.
%
time_clause(Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,RTime,Time) :-
  clause_type(Clause,Type),
%write('\nType='),write(Type),
	time_clause(Type,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,RTime,Time).

time_clause(2,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,RTime,Time) :-
%write('\nClause='),write(Clause),
	Clause = (_:-Body),
	time_body(Body,1,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,1,RTime,Time1),
	addition(Time1,1,Time).
time_clause(3,_,_,_,_,_,_,_,_,_,1).

%
%  Perform the time analysis for the body of a clause.
%
/*
time_body((Lit,Body),LitNum,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,Times,RTime,
	Time) :- 
	time_literal(Lit,LitNum,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,RTime,
		Time1),
		(Lit == (!) ->
		Time2 = Time1;
		multiply(Times,Time1,Time2)),
	(Lit == (!) ->
		Times1 = 1; 
		(frequency_literal(Lit,LitNum,Clause,BT,ST,Comp,Size,Adg,
			Gvars,_,_,Sol2),
		 multiply(Times,Sol2,Times1))),
	LitNum1 is LitNum+1,
	time_body(Body,LitNum1,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,Times1,
		  RTime,Time3),
	addition(Time2,Time3,Time).
time_body(Lit,LitNum,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,Times,RTime,Time) :-
	nonsequence(Lit),
	time_literal(Lit,LitNum,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,RTime,
		Time1),
	multiply(Times,Time1,Time).
*/
time_body(L,LitNum,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,Times,RTime,Time) :-
	(L=(Lit,Body) ->
	    (time_literal(Lit,LitNum,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,RTime,Time1),
	    (Lit == (!) ->
		Time2 = Time1;
		multiply(Times,Time1,Time2)
	    ),
	    (Lit == (!) ->
		    Times1 = 1; 
		    (
			frequency_literal(Lit,LitNum,Clause,BT,ST,Comp,Size,Adg,Gvars,_,_,Sol2),
			multiply(Times,Sol2,Times1))),
			LitNum1 is LitNum+1,
		    time_body(Body,LitNum1,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,Times1,RTime,Time3),
		    addition(Time2,Time3,Time));
		    (L=Lit ->
			(nonsequence(Lit) ->
			    (time_literal(Lit,LitNum,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,RTime,Time1),
			    multiply(Times,Time1,Time)
			)
		    )
		)
	    ).

%
%  Perform the time analysis for a literal.
%
time_literal(Lit,LitNum,Clause,BT,ST,Comp,Size,Adg,Gvars,_,RTime,Time) :-
	functor(Lit,F,A),
	(second_order_predicate(F/A) ->
	    (second_order_predicate_pred_arg(Lit,Lit1),
	    functor(Lit1,F1,A1),
	    arg(2,Clause,Body),
	    second_order_predicate_pred_num(Body,LitNum,Num1));
	    (F1 = F, A1 = A, Num1 = LitNum)),
	    literal_output_comp(F1/A1,Num1,1,BT,ST,Comp,Adg,time,RTime,LitTime),
	   normalize_time_function(LitTime,F1/A1,Num1,BT,ST,Comp,Clause,Adg,Gvars,Size,RTime,Time).

frequency_literal(Lit,LitNum,Clause,BT,ST,Comp,Size,Adg,Gvars,_,_,Sol) :-
	functor(Lit,F,A),
	literal_output_comp(F/A,LitNum,1,BT,ST,[],Adg,det,[],Sol1),
	normalize_solution_function(Sol1,F/A,LitNum,BT,ST,Comp,Clause,
			Adg,Gvars,Size,[],Sol).
/*
	(second_order_predicate(F/A) ->
		(second_order_predicate_pred_arg(Lit,Lit1),
		 functor(Lit1,F1,A1),
		 arg(2,Clause,Body),
		 second_order_predicate_pred_num(Body,LitNum,Num1));
		(F1 = F, A1 = A, Num1 = LitNum)),
	literal_output_comp(F1/A1,Num1,1,BT,ST,[],Adg,det,[],Sol1),
	normalize_solution_function(Sol1,F1/A1,Num1,BT,ST,Comp,Clause,
			Adg,Gvars,Size,[],Sol2),
	(second_order_predicate(F/A) ->
		(gen_literal_iopos(Adg,F1/A1,Num1,(-),Pos),
		 pos_var(Pos,Lit1,Vars),
		 arg(1,Lit,Arg1),
		 term_var(Arg1,Var1),
		 (opened_set_equivalent(Var1,Vars) ->
			Sol = 1;
			Sol = Sol2));
		Sol = Sol2).
*/


%
%  Normalize the time function of a literal.
%
normalize_time_function(LitTime,LitName,LitNum,BT,ST,Comp,Clause,Adg,Gvars,
			Size,RTime,Time) :-
	gen_clause_pos(Adg,PosSet),
	(recursive_clause(Clause,Comp) ->
		(ith_clause_literal(0,Clause,Lit),
		 functor(Lit,F,N),
		 find_symbol_field_size(ST,F/N,size,ISz));
		ISz = Size),
	gen_literal_iopos(Adg,LitName,LitNum,(+),Pos),
	init_normalize_queue(Pos,QHd,QTl),
	normalize(LitTime,QHd,QTl,BT,ST,[],Clause,Adg,Gvars,PosSet,ISz,RTime,Time).

