%
%  csp.pl			Nai-Wei Lin			March 1992
%
%  This file contains the procedures for estimating the number of solutions
%  of a CSP.
%

%
%  Estimate the number of solutions of a CSP.
%
csp(_,_,[],0).
csp(Vars,Domain,Constraint,Sols) :-
	%write(Constraint),nl,
	Constraint \== [],
	%write('rename_variables'),nl,
	rename_variables(Vars,1,NVars,Domain,NDomain,Constraint,NConstraint),
	%write(NConstraint),nl,
	%write('simplify_constraints'),nl,
	simplify_constraints(NConstraint,SConstraint),
	%write(SConstraint),nl,
	%write('node_consistency'),nl,
	node_consistency(NVars,NDomain,RDomain,SConstraint,RConstraint),
	%write(RConstraint),nl,
	%write('build_consistency_graph'),nl,
	build_consistency_graph(NVars,NDomain,RDomain,RConstraint,Graph),
	%write(Graph),nl,
	%write('number_of_cliques'),nl,
	number_n_cliques(NVars,RDomain,Graph,Sols).

%
%  Assign symbolic names to variables to facilitate further manipulation.
%
rename_variables([],_,[],_,[],Constraint,Constraint).
rename_variables([V|Vars],N,[$(N)|NVars],[L-U|Domain],[ND|NDomain],Constraint,
		NConstraint) :-
	ND = domain($(N),L,U),
	substitute(Constraint,V,$(N),Constraint1),
	N1 is N+1,
	rename_variables(Vars,N1,NVars,Domain,NDomain,Constraint1,NConstraint).

%
%  Simplify the constraints.
%
simplify_constraints([],[]).
simplify_constraints([C|Constraint],[SC|SConstraint]) :-
	(list_cas(C) ->
		simplify_constraints(C,SC);
		simplify_constraint(C,SC)),
	simplify_constraints(Constraint,SConstraint).

simplify_constraint(true,[]).
simplify_constraint(C,SC) :-
	C \== true,
	functor(C,Op,2),
	arg(1,C,LHS), arg(2,C,RHS),
	simplification(LHS-RHS,SExpr),
	functor(SC,Op,2),
	arg(1,SC,SExpr), arg(2,SC,0).

%
%  Reduce the domain size by performing node consistency via unary constraints.
%
node_consistency([],_,[],Constraint,Constraint).
node_consistency([V|Vars],Domain,[domain(V,NInterval)|NDomain],Constraint,
		NConstraint) :-
	relevant_uni_constraints(Constraint,V,RConstraint,Constraint1),
	find_interval_entry(Domain,V,domain(_,L,U)),
	gen_interval(L,U,Interval),
	consistent_node(RConstraint,Interval,NInterval),
	node_consistency(Vars,Domain,NDomain,Constraint1,NConstraint).

%
%  Collect the set of unary constraints involing variable V and transform
%  them into canonical form.
%
relevant_uni_constraints(Constraint,V,RConstraint,NConstraint) :-
	or_uni_constraints(Constraint,V,RConstraint,NConstraint).

or_uni_constraints([],_,[],[]).
or_uni_constraints([C|Constraints],V,[RC|RCs],[NC|NCs]) :-
	and_uni_constraints(C,V,RC,NC),
/*
	(RC == [] ->
		RConst = RCs;
		RConst = [RC|RCs]),
	(NC == [] ->
		NConst = NCs;
		NConst = [NC|NCs]),
*/
	or_uni_constraints(Constraints,V,RCs,NCs).

and_uni_constraints([],_,[],[]).
and_uni_constraints([C|Constraints],V,[RC|RCs],[NC|NCs]) :-
	(list_cas(C) ->
		or_uni_constraints(C,V,RC,NC);
		atom_uni_constraints(C,V,RC,NC)),
/*
	(RC == [] ->
		RConst = RCs;
		RConst = [RC|RCs]),
	(NC == [] ->
		NConst = NCs;
		NConst = [NC|NCs]),
*/
	and_uni_constraints(Constraints,V,RCs,NCs).

atom_uni_constraints(C,V,RCs,NCs) :-
	functor(C,Op,_), arg(1,C,LHS),
	(unary_constraint(LHS,V,Term,Const) ->
		(RCs = uc(Op,Term,Const),
		 NCs = []);
		(RCs = [],
		 NCs = C)).

%
%  Transform unary constraint into canonical form.
%
unary_constraint(V,V,1,0).
unary_constraint(C,_,0,C) :- number(C).
unary_constraint(-C,V,NTerm,NConst) :-
	unary_constraint(C,V,Term,Const),
	minus(Term,NTerm),
	minus(Const,NConst).
unary_constraint(C1+C2,V,Term,Const) :-
	unary_constraint(C1,V,Term1,Const1),
	unary_constraint(C2,V,Term2,Const2),
	addition(Term1,Term2,Term),
	addition(Const1,Const2,Const).
unary_constraint(C1-C2,V,Term,Const) :-
	unary_constraint(C1,V,Term1,Const1),
	unary_constraint(C2,V,Term2,Const2),
	subtraction(Term1,Term2,Term),
	subtraction(Const1,Const2,Const).
unary_constraint(C1*C2,V,Term,Const) :-
	unary_constraint(C1,V,Term1,Const1),
	unary_constraint(C2,V,Term2,Const2),
	multiply(Term1,Const2,M1),
	multiply(Term2,Const1,M2),
	addition(M1,M2,Term),
	multiply(Const1,Const2,Const).
unary_constraint(C,V) :-
	variable(C), C \== V, fail.

%
%  Reduce the domain size according to the set of unary constraints.
%
consistent_node(Constraint,Interval,NInterval) :-
	or_consistent_nodes(Constraint,Interval,NInterval).

or_consistent_nodes([],Interval,Interval).
or_consistent_nodes(Constraint,Interval,NInterval) :-
	Constraint \== [],
	or_consistent_node(Constraint,Interval,NInterval).

or_consistent_node([],_,[]).
or_consistent_node([C|Constraint],Interval,NInterval) :-
	and_consistent_node(C,Interval,Interval1),
	or_consistent_node(Constraint,Interval,Interval2),
	number_union(Interval1,Interval2,NInterval).

and_consistent_node([],Interval,Interval).
and_consistent_node([C|Constraint],Interval,NInterval) :-
	(list_cas(C) ->
		or_consistent_nodes(C,Interval,Interval1);
		atom_consistent_node(C,Interval,Interval1)),
	and_consistent_node(Constraint,Interval1,NInterval).

atom_consistent_node(uc(Op,Term,Const),Interval,NInterval) :-
	Threshold is -(Const/Term),
	(Term > 0 ->
		Nop = Op;
		reverse_op(Op,Nop)),
	consistency(Nop,Interval,[Threshold],NInterval).

%
%  Find the defined interval for varibale Var.
%
find_interval_entry(Dom,_,_) :- 
	var(Dom).
find_interval_entry([],_,_).
find_interval_entry(Dom,Var,Entry) :- 
	nonvar(Dom),
	Dom = [Entry|_],
	Entry = domain(V,_,_),
	V == Var.
find_interval_entry(Dom,Var,Entry) :- 
	nonvar(Dom),
	Dom = [domain(V,_,_)|D],
	V \== Var,
	find_interval_entry(D,Var,Entry).

%
%  Find the defined domain for varibale Var.
%
find_domain_entry(Dom,_,_) :- 
	var(Dom).
find_domain_entry([],_,_).
find_domain_entry(Dom,Var,Entry) :- 
	nonvar(Dom),
	Dom = [Entry|_],
	Entry = domain(V,_),
	V == Var.
find_domain_entry(Dom,Var,Entry) :- 
	nonvar(Dom),
	Dom = [domain(V,_)|D],
	V \== Var,
	find_domain_entry(D,Var,Entry).

