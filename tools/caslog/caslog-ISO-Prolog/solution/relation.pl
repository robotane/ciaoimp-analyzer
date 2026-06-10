%
%  relation.pl			Nai-Wei Lin			December, 1991
%
%  This file contains the procedures for performing the relation size
%  analysis for the predicates in the program in topologically sorted order.
%

%
%  Perform the relation size analysis for a strongly connected component.
%
relation_analysis([],_,_,_,_,_,_,_,[]).
relation_analysis([Pred|CompList],BT,ST,Comp,[Size|SList],[Adg|AList],
		  [Gvars|GList],[Ldg|LList],[[Sol]|OList]) :-
	relation_predicate(Pred,BT,ST,Comp,Size,Adg,Gvars,Ldg,Sol1),
	simplification(Sol1,Sol),
	insert_symbol_field_relation(ST,Pred,relation,Sol),
	relation_analysis(CompList,BT,ST,Comp,SList,AList,GList,LList,OList).

%
%  Perform the relation size analysis for a predicate.
%
relation_predicate(Pred,BT,ST,Comp,Size,Adg,Gvars,Ldg,Sol) :-
flush_output,
	find_symbol_field_relation(ST,Pred,relation,Sol1),
	(var(Sol1) ->
		(recursive_predicate(Pred,ST,Comp) ->
		    Sol = inf;
		    (relation_nonrec_pred(Pred,BT,ST,Comp,Size,Adg,Gvars,
		    Ldg,Sol)
		)
		);
		Sol = Sol1).

%
%  Perform the relation size analysis for a predicate.
%
relation_nonrec_pred(Pred,BT,ST,Comp,Size,Adg,Gvars,Ldg,Sol) :-
	find_symbol_field_clause(ST,Pred,clause,Clauses),
	find_symbol_field_domain(ST,Pred,domain,Domain),
	((nonvar(Domain),unfoldable(Pred,BT,ST,Vars,UClauses)) ->
		(binary_disequality(Pred,ST,UClauses,DomainSize) ->
			gcp(Vars,DomainSize,UClauses,Sol);
			(linear_arithmetic_constraints(Pred,ST,UClauses) ->
				csp(Vars,Domain,UClauses,Sol);
				relation_clauses(Clauses,BT,ST,Comp,Size,Adg,
					Gvars,Ldg,Sol)));
		relation_clauses(Clauses,BT,ST,Comp,Size,Adg,Gvars,Ldg,Sol)).

%
%  Perform the relation size analysis for the set of clauses in a predicate.
%
relation_clauses(Clauses,_,_,_,_,_,_,_,0) :-
	var(Clauses).
relation_clauses(Clauses,BT,ST,Comp,[Size|SList],[Adg|AList],[Gvars|GList],
		 [Ldg|LList],Sol) :-
	nonvar(Clauses),
	Clauses = [Clause|CList],
	relation_clause(Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,Sol1),
	relation_clauses(CList,BT,ST,Comp,SList,AList,GList,LList,Sol2),
	addition(Sol1,Sol2,Sol).

%
%  Perform the relation size analysis for a clause.
%
relation_clause(Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,Sol) :-
	clause_type(Clause,Type),
	relation_clause(Type,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,Sol).

relation_clause(2,Clause,BT,ST,Comp,Size,Adg,Gvars,Ldg,Sol) :-
	Clause = (Head :- Body),
	(fail_body(Body) ->
		Sol = 0;
		(relation_head_input(Head,BT,ST,Clause,Adg,Gvars,Ldg,ISol),
		 (ISol == inf ->
			Sol = inf;
		 	(no_of_cuts(Body,Cuts),
			 collect_test_literals(Body,BT,ST,Lits),
		 	 body_binding(1,Body,BT,ST,Comp,Clause,Size,Adg,Gvars,
				Ldg,relation,Cuts,Lits,_),
		 	 relation_head(Head,Clause,Gvars,Ldg,Lits,Sol))))).
relation_clause(3,Fact,BT,ST,_,_,Adg,Gvars,Ldg,Sol) :-
	relation_head_input(Fact,BT,ST,Fact,Adg,Gvars,Ldg,ISol),
	(ISol == inf ->
		Sol = inf;
		relation_head(Fact,Fact,Gvars,Ldg,[],Sol)).

%
%  Test if a predicate is recursive.
%
recursive_predicate(Pred,ST,Component) :-
find_symbol_field_clause(ST,Pred,clause,Clauses),
	recursive_clauses(Clauses,Component).

recursive_clauses(Clauses,_) :-
	var(Clauses),
	fail,!.
recursive_clauses(Clauses,Component) :-
	nonvar(Clauses),
	Clauses = [C|CList],
	(recursive_clause(C,Component) ->
		(true,!);
		recursive_clauses(CList,Component)).
	
recursive_clause(Clause,Component) :-
	clause_type(Clause,Type),
	recursive_clause(Type,Clause,Component).

recursive_clause(2,(_:-Body),Component) :-
	recursive_body(Body,Component).
/*
recursive_body(Lit,Component) :-
	nonsequence(Lit),
	functor(Lit,F,A),
	member_cas(Component,F/A).
recursive_body((Lit,Body),Component) :-
	functor(Lit,F,A),
	(member_cas(Component,F/A) ->
		true;
		recursive_body(Body,Component)).
*/


recursive_body(L,Component):-
	(L=(Lit,Body) ->
	    (functor(Lit,F,A),
	    (member_cas(Component,F/A) ->
		(true);
		recursive_body(Body,Component)));
		(L=Lit ->
		    (nonsequence(Lit) ->
			(functor(Lit,F,A),
			member_cas(Component,F/A))
		    )
		)
	    ).



%
fail_clause(Clause) :-
	clause_type(Clause,2),
	Clause = (_:-Body),
	fail_body(Body).

fail_body((Lit,Body)) :-
	(Lit == (fail) ->
		true;
		fail_body(Body)).
fail_body((fail)).

