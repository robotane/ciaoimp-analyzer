%
%  unfold.pl			Nai-Wei Lin			April 1992
%
%  This file contains the procedures for unfolding a user-defined test 
%  predicate into buildin test predicates.
%

%
%  Unfolding a test predicate into buildin predicates by using top-down
%  and left-right order.
%
unfoldable(Pred,BT,ST,HVars,UClauses) :-
	find_symbol_field(ST,Pred,(mode),Mode),
	test_predicate(Mode),
	formal_predicate(Pred,ST,HVars),
	find_symbol_field_clause(ST,Pred,clause,Clauses),
	disj_unfoldable(Clauses,HVars,BT,ST,UClauses).

%
disj_unfoldable(Clauses,_,_,_,[]) :-
	var(Clauses).
disj_unfoldable(Clauses,HVars,BT,ST,UClauses) :-
	nonvar(Clauses),
	Clauses = [C|Cs],
	formal_clause(C,CVars,RC),
	conj_unfoldable(RC,BT,ST,UC),
	(UC == [] ->
		UClauses = UCs;
		(rename_term(CVars,HVars,UC,NC),
		 UClauses = [NC|UCs])),
	disj_unfoldable(Cs,HVars,BT,ST,UCs).

%
conj_unfoldable((_:-Body),BT,ST,UC) :-
	unfold_body(Body,BT,ST,UC).

%
unfold_literal(Pred,BT,ST,Call,UClauses) :-
	find_symbol_entry(BT,Pred,Entry),
	(nonvar(Entry) ->
		(unfold_admissible_builtin(Pred),
		 UClauses = Call);
		(find_symbol_field(ST,Pred,(mode),Mode),
		 test_predicate(Mode),
		 find_symbol_field_clause(ST,Pred,clause,Clauses),
		 unfold_clauses(Clauses,Call,BT,ST,UClauses))).

%
unfold_clauses(Clauses,_,_,_,[]) :-
	var(Clauses).
unfold_clauses(Clauses,Call,BT,ST,UClauses) :-
	nonvar(Clauses),
	Clauses = [C|Cs],
	new_term(C,RC),
	term_variables(Call,CVar),
	new_variables(CVar,NVar),
	rename_term(CVar,NVar,Call,NCall),
	unfold_clause(RC,NCall,CVar,NVar,BT,ST,UC),
	unfold_clauses(Cs,Call,BT,ST,UCs),
	(UC == [] ->
		UClauses = UCs;
		UClauses = [UC|UCs]).

%
unfold_clause(Clause,Call,CVar,NVar,BT,ST,UClause) :-
	clause_type(Clause,Type),
	unfold_clause(Type,Clause,Call,CVar,NVar,BT,ST,UClause).

unfold_clause(2,(Head:-Body),Call,CVar,NVar,BT,ST,UClause) :-
	((Head:-Body) = (Call:-B) ->
		(rename_term(NVar,CVar,B,NB),
		 unfold_body(NB,BT,ST,UClause));
		UClause = []).
unfold_clause(3,Fact,Call,_,_,_,_,UClause) :-
	(Fact = Call ->
		UClause = [true];
		UClause = []).

%
/*
unfold_body(Lit,BT,ST,UClauses) :-
	nonsequence(Lit),
	functor(Lit,F,A),
	unfold_literal(F/A,BT,ST,Lit,UClause),
	(UClause == [] -> UClauses = [];
	((F/A == fail/0) -> UClauses = [];
			((F/A == (is)/2; F/A == !/0; F/A == true/0) ->
				UClauses = [true];
				UClauses = [UClause]))).


unfold_body((Lit,Body),BT,ST,UClauses) :-

	functor(Lit,F,A),
	unfold_literal(F/A,BT,ST,Lit,UC),
	(UC == [] -> UClauses = [];	
		(F/A == fail/0 -> UClauses = [];
			(F/A == (is)/2 ->
				(arg(1,UC,LHS),	
		 		 arg(2,UC,RHS),
		 		 evaluate_general_expr(RHS,SRHS),
		 		 substitute(Body,LHS,SRHS,SBody),
		 		 unfold_body(SBody,BT,ST,UClause),
		 		 UClauses = UClause);
				((F/A == (!)/0; F/A == true/0) ->
				   (unfold_body(Body,BT,ST,UClause),
		 	 	    UClauses = UClause);
				   (unfold_body(Body,BT,ST,UClause),
				    (UClause == [] ->
					UClauses = [];
		 	 	 	UClauses = [UC|UClause])))))).
*/




unfold_body(L,BT,ST,UClauses) :-
	(L=(Lit,Body) ->
	    (functor(Lit,F,A),
	    unfold_literal(F/A,BT,ST,Lit,UC),
	    (UC == [] -> UClauses = [];	
		(F/A == fail/0 -> UClauses = [];
		    (F/A == (is)/2 ->
			(arg(1,UC,LHS),	
			arg(2,UC,RHS),
			evaluate_general_expr(RHS,SRHS),
			substitute(Body,LHS,SRHS,SBody),
			unfold_body(SBody,BT,ST,UClause),
			UClauses = UClause);
				 ((F/A == (!)/0; F/A == true/0) ->
				     (unfold_body(Body,BT,ST,UClause),
				     UClauses = UClause);
				     (unfold_body(Body,BT,ST,UClause),
				     (UClause == [] ->
					 UClauses = [];
					 UClauses = [UC|UClause])
				     )
				 )
			     )
			 )
		     )
		 );
		 (L=Lit ->
		     (nonsequence(Lit),
		     functor(Lit,F,A),
		     unfold_literal(F/A,BT,ST,Lit,UClause),
		     (UClause == [] -> UClauses = [];
			 ((F/A == fail/0) -> UClauses = [];
			     ((F/A == (is)/2; F/A == !/0; F/A == true/0) ->
				 UClauses = [true];
				 UClauses = [UClause])
			     )
			 )
		     )
		 )
	     ).




%
%  Check if a predicate is a test.
%
test_predicate(Mode) :-
	Mode \== [],
	test_predicate1(Mode).

test_predicate1([]).
test_predicate1([+|Mode]) :-
	test_predicate1(Mode).

%
%  Create a new instance of the first clause and collect the variables
%  in the head as the formal parameters of the predicate.
%
formal_predicate(Pred,ST,HVars) :-
	find_symbol_field_clause(ST,Pred,clause,Clauses),
	nonvar(Clauses), Clauses = [C|_],
	clause_type(C,2),
	new_term(C,RC),
	arg(1,RC,Head),
	constraint_head_vars(Head,HVars).

%
formal_clause(C,RVars,RC) :-
	clause_type(C,2),
	new_term(C,RC),
	arg(1,RC,Head),
	constraint_head_vars(Head,RVars).

%
new_term(C,RC) :-
	term_variables(C,Vars),
	new_variables(Vars,NewVars),
	rename_term(Vars,NewVars,C,RC).

%
term_variables(Term,Var) :-
	term_variables(Term,[],Var).

term_variables(Term,Var,[Term|Var]) :-
	var(Term).
term_variables(Term,Var,NVar) :-
	nonvar(Term),
	functor(Term,_,A),
	term_variables(A,Term,Var,NVar).
	
term_variables(0,_,Var,Var).
term_variables(A,Term,Var,NVar) :-
	A > 0,
	arg(A,Term,Arg),
	term_variables(Arg,Var,Var1),
	A1 is A-1,
	term_variables(A1,Term,Var1,NVar).

%
new_variables([],[]).
new_variables([_|Var],[_|NVar]) :-
	new_variables(Var,NVar).

%
rename_term([],_,Term,Term).
rename_term([V|Var],[NV|NVar],Term,NTerm) :-
	substitute(Term,V,NV,Term1),
	rename_term(Var,NVar,Term1,NTerm).

%
%  Collect the set of variables in the head of a constraint.
%
constraint_head_vars(Head,HVars) :-
	functor(Head,_,A),
	constraint_head_vars(1,A,Head,HVars).
	
constraint_head_vars(N,A,_,[]) :-
	N > A.
constraint_head_vars(N,A,Head,[Arg|HVars]) :-
	N =< A,
	arg(N,Head,Arg),
	var(Arg),
	N1 is N+1,
	constraint_head_vars(N1,A,Head,HVars).

%
%  The set of builtin predicates allowed during unfolding.
%
unfold_admissible_builtin((==)/2).
unfold_admissible_builtin((\==)/2).
unfold_admissible_builtin((=:=)/2).
unfold_admissible_builtin((=\=)/2).
unfold_admissible_builtin((>=)/2).
unfold_admissible_builtin((>)/2).
unfold_admissible_builtin((=<)/2).
unfold_admissible_builtin((<)/2).
unfold_admissible_builtin((is)/2).
unfold_admissible_builtin((!)/0).
unfold_admissible_builtin((true)/0).
unfold_admissible_builtin((fail)/0).

%
evaluate_general_expr(RHS,RHS) :-
	var(RHS),!.
evaluate_general_expr(RHS,RHS) :-
	number(RHS),!.
evaluate_general_expr(-E1,RHS) :-
	!,
	evaluate_general_expr(E1,RHS1),
	(number(RHS1) ->
		RHS is -RHS1;
		RHS = -RHS1).
evaluate_general_expr(E1+E2,RHS) :-
	!,
	evaluate_general_expr(E1,RHS1),
	evaluate_general_expr(E2,RHS2),
	((number(RHS1),number(RHS2)) ->
		RHS is RHS1+RHS2;
		RHS = RHS1+RHS2).
evaluate_general_expr(E1-E2,RHS) :-
	!,
	evaluate_general_expr(E1,RHS1),
	evaluate_general_expr(E2,RHS2),
	((number(RHS1),number(RHS2)) ->
		RHS is RHS1-RHS2;
		RHS = RHS1-RHS2).
evaluate_general_expr(E1*E2,RHS) :-
	!,
	evaluate_general_expr(E1,RHS1),
	evaluate_general_expr(E2,RHS2),
	((number(RHS1),number(RHS2)) ->
		RHS is RHS1*RHS2;
		RHS = RHS1*RHS2).
evaluate_general_expr(RHS,SRHS) :-
	functor(RHS,F,N),
	functor(SRHS,F,N),
	evaluate_general_expr(N,RHS,SRHS).
	
evaluate_general_expr(0,_,_).
evaluate_general_expr(N,RHS,SRHS) :-
	N > 0,
	arg(N,RHS,Arg),
	evaluate_general_expr(Arg,SArg),
	arg(N,SRHS,SArg),
	N1 is N-1,
	evaluate_general_expr(N1,RHS,SRHS).
