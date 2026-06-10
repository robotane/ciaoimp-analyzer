%
%  consistency.pl		Nai-Wei Lin			March 1992
%
%  This file contains the procedures for building the consistency graph
%  corresponding to a CSP.
%

%
%  Build a consistency graph.
%
build_consistency_graph([],_,_,_,[]).
build_consistency_graph([V|Vs],Interval,Domain,Constraint,[cgraph(V,Edge)|Gs]):-
	%nl,write(V),nl,
	%ttyflush,
	build_consistency_edges(Vs,V,Interval,Domain,Constraint,Edge),
	%write(Edge),nl,
	build_consistency_graph(Vs,Interval,Domain,Constraint,Gs).

%
%  Build the edges corresponding to the variable H in a consistency graph.
%
build_consistency_edges([],_,_,_,_,[]).
build_consistency_edges([T|Vs],H,Interval,Domain,Constraint,[cvar(T,Edge)|Es]):-
	%write(T),nl,
	build_consistency_edge(T,H,Interval,Domain,Constraint,Edge),
	build_consistency_edges(Vs,H,Interval,Domain,Constraint,Es).

%
%  Build the edges corresponding to the variables H and T in a consistency 
%  graph.
%
build_consistency_edge(T,H,Interval,Domain,Constraint,Edge) :-
	%relevant_bi_constraints(Constraint,T,H,RConstraint),
	%write(RConstraint),nl,
	canonical_binary_constraints(Constraint,T,H,Interval,BConstraint),
	%write(BConstraint),nl,
	find_domain_entry(Domain,H,domain(_,HDomain)),
	%write(HDomain),nl,
	find_domain_entry(Domain,T,domain(_,TDomain)),
	%write(TDomain),nl,
	consistency_edges(HDomain,TDomain,BConstraint,H,Edge).

%
%  Collect the set of constraints involving both variables H and T.
%
relevant_bi_constraints(Constraint,T,H,RConstraint) :-
	or_bi_constraints(Constraint,T,H,RConstraint).

or_bi_constraints([],_,_,[]).
or_bi_constraints([C|Constraint],T,H,RConst) :-
	and_bi_constraints(C,T,H,RC),
	(RC == [] ->
		RConst = RConstraint;
		RConst = [RC|RConstraint]),
	or_bi_constraints(Constraint,T,H,RConstraint).

and_bi_constraints([],_,_,[]).
and_bi_constraints([C|Constraint],T,H,RConst) :-
	(list_cas(C) ->
		or_bi_constraints(C,T,H,RC);
		atom_bi_constraints(C,T,H,RC)),
	(RC == [] ->
		RConst = RConstraint;
		RConst = [RC|RConstraint]),
	and_bi_constraints(Constraint,T,H,RConstraint).

atom_bi_constraints(C,T,H,RC) :-
	(both_involved(C,T,H) ->
		RC = C;
		RC = []).

%
%  Test if constraint C involves both variables H and T.
%
both_involved(C,T,H) :-
	both_involved(C,T,H,TF,HF),
	F is TF+HF,
	F =:= 0.

both_involved(C,_,_,1,1) :-
	number(C),!.
both_involved(C,T,_,0,1) :-
	C == T,!.
both_involved(C,_,H,1,0) :-
	C == H,!.
both_involved(C,T,H,1,1) :-
	variable(C),!,
	C \== T,
	C \== H.
both_involved(C,T,H,TF,HF) :-
	compound_cas(C),
	functor(C,F,N),
	F \== ($),
	both_involved(N,C,T,H,TF,HF).

both_involved(0,_,_,_,1,1).
both_involved(N,C,T,H,TF,HF) :-
	N > 0,
	arg(N,C,Arg),
	both_involved(Arg,T,H,TF1,HF1),
	N1 is N-1,
	both_involved(N1,C,T,H,TFs,HFs),
	TF is TF1*TFs,
	HF is HF1*HFs.

%
%  Transform general constraints into canonical binary constraints.
%
canonical_binary_constraints(Constraint,T,H,Domain,BConstraint) :-
	or_binary_constraints(Constraint,T,H,Domain,BConstraint).

or_binary_constraints([],_,_,_,[]).
or_binary_constraints([C|Constraint],T,H,Domain,[BC|BConstraint]) :-
	and_binary_constraints(C,T,H,Domain,BC),
/*
	(BC == [] ->
		BConst = BConstraint;
		BConst = [BC|BConstraint]),
*/
	or_binary_constraints(Constraint,T,H,Domain,BConstraint).

and_binary_constraints([],_,_,_,[]).
and_binary_constraints([C|Constraint],T,H,Domain,[BC|BConstraint]) :-
	(list_cas(C) ->
		or_binary_constraints(C,T,H,Domain,BC);
		atom_binary_constraint(C,T,H,Domain,BC)),
/*
	(BC == [] ->
		BConst = BConstraint;
		BConst = [BC|BConstraint]),
*/
	and_binary_constraints(Constraint,T,H,Domain,BConstraint).

%
%  Transform a general constraints into a canonical binary constraint.
%
atom_binary_constraint(C,T,H,Domain,BC) :-
	(both_involved(C,T,H) ->
		(functor(C,Op,2),
		 arg(1,C,LHS),
		 binary_constraint(LHS,T,H,Domain,T1,H1,dv(C1,C2)),
		 simplification(T1,Texpr),
		 substitute(Texpr,T,1,NTexpr),
		 simplification(NTexpr,A),
		 Con1 is -C2,
		 Con2 is -C1,
		 simplification(-H1,Hexpr),
		 BC = bc(Op,A,Hexpr,dv(Con1,Con2)));
		BC = []).

%
binary_constraint(C,_,_,_,0,0,dv(C,C)) :- number(C),!.
binary_constraint(T,T,_,_,T,0,dv(0,0)) :- !.
binary_constraint(H,_,H,_,0,H,dv(0,0)) :- !.
binary_constraint(V,T,H,Domain,0,0,dv(L,U)) :- variable(V),!,
	V \== T, V \== H,
	find_interval_entry(Domain,V,domain(V,L,U)).
binary_constraint(-E1,T,H,Domain,Texpr,Hexpr,dv(NC1,NC2)) :- !,
	binary_constraint(E1,T,H,Domain,T1,H1,dv(C1,C2)),
	minus(T1,Texpr), minus(H1,Hexpr),
	NC1 is -C2, NC2 is -C1.
binary_constraint(E1+E2,T,H,Domain,Texpr,Hexpr,dv(C1,C2)) :- !,
	binary_constraint(E1,T,H,Domain,T1,H1,dv(C11,C12)),
	binary_constraint(E2,T,H,Domain,T2,H2,dv(C21,C22)),
	addition(T1,T2,Texpr), addition(H1,H2,Hexpr),
	C1 is C11+C21, C2 is C12+C22.
binary_constraint(E1-E2,T,H,Domain,Texpr,Hexpr,dv(C1,C2)) :- !,
	binary_constraint(E1,T,H,Domain,T1,H1,dv(C11,C12)),
	binary_constraint(E2,T,H,Domain,T2,H2,dv(C21,C22)),
	subtraction(T1,T2,Texpr), subtraction(H1,H2,Hexpr),
	C1 is C11-C22, C2 is C12-C21.
binary_constraint(E1*E2,T,H,Domain,Texpr,Hexpr,dv(C1,C2)) :-
	binary_constraint(E1,T,H,Domain,T1,H1,dv(C11,C12)),
	binary_constraint(E2,T,H,Domain,T2,H2,dv(C21,C22)),
	constraint_term(T1,H1,C11,C12,T2,H2,C21,C22,Texpr,Hexpr,C1,C2).

%
constraint_term(0,0,C,C,T2,H2,C21,C22,Texpr,Hexpr,C1,C2) :- !,
	multiply(C,T2,Texpr), multiply(C,H2,Hexpr),
	C1 is C*C21, C2 is C*C22.
constraint_term(T1,H1,C11,C12,0,0,C,C,Texpr,Hexpr,C1,C2) :-
	multiply(C,T1,Texpr), multiply(C,H1,Hexpr),
	C1 is C*C11, C2 is C*C12.

%
%  Collect the edges corresponding to the variables H and T.
%
consistency_edges([],_,_,_,[]).
consistency_edges([V|HInterval],TInterval,BConstraint,H,[cedge(V,WEdge)|Es]) :-
	consistent_values(BConstraint,H,V,TInterval,Edge),
	weighted_edge(Edge,WEdge),
	consistency_edges(HInterval,TInterval,BConstraint,H,Es).

%
%  Generate the consistent interval corresponding to a set of constraints.
%
consistent_values(BCs,H,V,Interval,Edge) :-
	or_consistent_values(BCs,H,V,Interval,Edge).

or_consistent_values([],_,_,Edge,Edge).
or_consistent_values(BCs,H,V,Interval,Edge) :-
	BCs \== [],
	or_consistent_value(BCs,H,V,Interval,Edge).

/*
or_consistent_value(BCs,H,V,Interval,Edge) :-
	or_consistent_value_1(BCs,H,V,Interval,Edge1),
	number_difference(Interval,Edge1,Edge).
*/

or_consistent_value([],_,_,_,[]).
or_consistent_value([C|Cs],H,V,Interval,Edge) :-
	and_consistent_values(C,H,V,Interval,Edge1),
	%number_difference(Interval,Edge1,Edge2),
	or_consistent_value(Cs,H,V,Interval,Edge2),
	number_union(Edge1,Edge2,Edge).

and_consistent_values([],_,_,Edge,Edge).
and_consistent_values([C|Cs],H,V,Interval,Edge) :-
	(list_cas(C) ->
		or_consistent_values(C,H,V,Interval,Edge1);
		atom_consistent_values(C,H,V,Interval,Edge1)),
	and_consistent_values(Cs,H,V,Edge1,Edge).

atom_consistent_values(bc(Op,A,Hexpr,dv(Con1,Con2)),H,V,DInterval,Edge) :-
	substitute(Hexpr,H,V,Nexpr),
	simplification(Nexpr,Val),
	ELB is Con1+Val,
	EUB is Con2+Val,
	gen_interval(ELB,EUB,EInterval1),
	divide_all(EInterval1,A,EInterval2),
	(A > 0 ->
		(EInterval = EInterval2,
		 Nop = Op);
		(reverse(EInterval2,[],EInterval),
		 reverse_op(Op,Nop))),
	consistency(Nop,DInterval,EInterval,Edge).

%
%  Extend consistency graph to weighted consistency graph.
%
weighted_edge([],[]).
weighted_edge([E|Edge],[weight(E,1)|WEdge]) :-
	weighted_edge(Edge,WEdge).

%
%  Generate the set of consistent edges between the interval LB-UB.
%
gen_interval(LB,UB,[]) :-
	LB > UB.
gen_interval(LB,UB,[LB|Es]) :-
	LB =< UB,
	LB1 is LB+1,
	gen_interval(LB1,UB,Es).

%
%  Generate the consistent interval corresponding to a constraint.
%
consistency((=:=),DEdge,EEdge,Edge) :-
	number_intersection(DEdge,EEdge,Edge).
consistency((=\=),DEdge,EEdge,Edge) :-
	(EEdge = [E] ->
		number_delete(DEdge,E,Edge);
		Edge = DEdge).
consistency((>=),DEdge,EEdge,Edge) :-
	smallest_element(EEdge,SE),
	geq_set(DEdge,SE,Edge).
consistency((>),DEdge,EEdge,Edge) :-
	smallest_element(EEdge,SE),
	g_set(DEdge,SE,Edge).
consistency((=<),DEdge,EEdge,Edge) :-
	largest_element(EEdge,LE),
	leq_set(DEdge,LE,Edge).
consistency((<),DEdge,EEdge,Edge) :-
	largest_element(EEdge,LE),
	l_set(DEdge,LE,Edge).

%
number_member_cas([E|_],Ele) :- 
	E =:= Ele.
number_member_cas([E|List],Ele) :- 
	E =\= Ele,
	number_member_cas(List,Ele).

%
number_union(S,[],S).
number_union([],S,S) :-
	S \== [].
number_union([X1|S1],[X2|S2],[X1|S]) :-
	X1 =:= X2,
	number_union(S1,S2,S).
number_union([X1|S1],[X2|S2],[X1|S]) :-
	X1 < X2,
	number_union(S1,[X2|S2],S).
number_union([X1|S1],[X2|S2],[X2|S]) :-
	X1 > X2,
	number_union([X1|S1],S2,S).

%
number_intersection([],_,[]).
number_intersection([X|S1],S2,S) :-
	(number_member_cas(S2,X) ->
		S = [X|SList];
		S = SList),
	number_intersection(S1,S2,SList).

number_difference([],_,[]).
number_difference([X|S1],S2,S) :-
	(number_member_cas(S2,X) ->
		S = SList;
		S = [X|SList]),
	number_difference(S1,S2,SList).

%
number_delete([],_,[]).
number_delete([D|DEdge],E,Edge) :-
	(D =:= E ->
		Edge = Edges;
		Edge = [D|Edges]),
	number_delete(DEdge,E,Edges).

%
divide_all([],_,[]).
divide_all([E|EEdge],A,[D|DEdge]) :-
	D is E/A,
	divide_all(EEdge,A,DEdge).

%
reverse([],L,L).
reverse([X|L1],L2,L3) :-
	reverse(L1,[X|L2],L3).

%
reverse_op((=:=),(=:=)).
reverse_op((=\=),(=\=)).
reverse_op((>=),(=<)).
reverse_op((>),(<)).
reverse_op((=<),(>=)).
reverse_op((<),(>)).

%
complement_constraint(bc(Op1,X1,X2,X3),bc(Op2,X1,X2,X3)) :-
	complement_op(Op1,Op2).

%
complement_op((=:=),(=\=)).
complement_op((=\=),(=:=)).
complement_op((>=),(<)).
complement_op((>),(=<)).
complement_op((=<),(>)).
complement_op((<),(>=)).

%
smallest_element([E|_],E).

%
largest_element([E],E).
largest_element([_|List],L) :-
	largest_element(List,L).

%
geq_set([],_,[]).
geq_set([D|Ds],X,E) :-
	(D >= X ->
		E = [D|Es];
		E = Es),
	geq_set(Ds,X,Es).

g_set([],_,[]).
g_set([D|Ds],X,E) :-
	(D > X ->
		E = [D|Es];
		E = Es),
	g_set(Ds,X,Es).

leq_set([],_,[]).
leq_set([D|Ds],X,E) :-
	(D =< X ->
		E = [D|Es];
		E = Es),
	leq_set(Ds,X,Es).

l_set([],_,[]).
l_set([D|Ds],X,E) :-
	(D < X ->
		E = [D|Es];
		E = Es),
	l_set(Ds,X,Es).

