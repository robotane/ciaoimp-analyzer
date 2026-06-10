%
%  constraint.pl		Nai-Wei Lin			April, 1992
%
%  This file contains the procedures for testing the linearity of arithmetic
%  constraints.
%

%
%  Test if a predicate consists of linear arithmetic constraints.
%
linear_arithmetic_constraints(Pred,ST,Constraints) :-
	find_symbol_field_measure(ST,Pred,measure,Measure),
	integer_constraint(Measure),
	find_symbol_field_domain(ST,Pred,domain,Domain),
	nonvar(Domain),
	interval_domain(Domain),
	linear_arithmetic_constraints(Constraints).

linear_arithmetic_constraints([]).
linear_arithmetic_constraints([C|Constraints]) :-
	(list_cas(C) ->
		linear_arithmetic_constraints(C);
		linear_arithmetic_constraint(C)),
	linear_arithmetic_constraints(Constraints).

linear_arithmetic_constraint(true).
linear_arithmetic_constraint(C) :-
	C \== true,
	functor(C,Op,A),
	(arithmetic_op(Op/A) ->
		(arg(1,C,LHS),
		 constraint_expr(LHS),
		 arg(2,C,RHS),
		 constraint_expr(RHS))).

%
%  Check if a predicate involves only integer.
%
integer_constraint([]).
integer_constraint([int|Measure]) :-
	integer_constraint(Measure).

%
%  Check if all the domains are integer interval.
%
interval_domain([]).
interval_domain([_-_|Domain]) :-
	interval_domain(Domain).

%
%  Test if a literal is an arithmetic operator.
%
arithmetic_op((=:=)/2).
arithmetic_op((=\=)/2).
arithmetic_op((>=)/2).
arithmetic_op((>)/2).
arithmetic_op((=<)/2).
arithmetic_op((<)/2).
	
%
%  Test if an expression is linear.
%
constraint_expr(E) :-
	number(E),!.
constraint_expr(E) :-
	var(E),!.
constraint_expr(-E) :-
	!,constraint_term(E).
constraint_expr(E1+E2) :-
	!,
	constraint_expr(E1),
	constraint_expr(E2).
constraint_expr(E1-E2) :-
	!,
	constraint_expr(E1),
	constraint_expr(E2).
constraint_expr(E1*E2) :-
	(number(E1);number(E2)),!,
	constraint_factor(E1),
	constraint_factor(E2).

%
%  Test if a term is linear.
%
constraint_term(E) :-
	number(E),!.
constraint_term(E) :-
	var(E),!.
constraint_term(E1*E2) :-
	(nonvar(E1);nonvar(E2)),!,
	constraint_factor(E1),
	constraint_factor(E2).

%
%  Test if a factor is linear.
%
constraint_factor(E) :-
	number(E).
constraint_factor(E) :-
	var(E).

