%
%  gcp.pl			Nai-Wei Lin			April 1992
%
%  This file contains the procedures for estimating the number of solutions
%  of a GCP.
%

%
%  Estimate the number of solutions of a GCP.
%
gcp(_,_,[],0).
gcp(Vars,DomainSize,Disequality,Sol) :-
	Disequality \== [],
	rename_variables_gcp(Vars,1,NVars,Disequality,NDisequality),
	build_constraint_graph(NVars,NDisequality,Graph),
	csl_poly(Graph,Upoly,_,_),
	evaluate_poly(Upoly,DomainSize,Sol).

%
%  Assign symbolic names to variables to facilitate further manipulation.
%
rename_variables_gcp([],_,[],Disequality,Disequality).
rename_variables_gcp([V|Vars],N,[N|NVars],Disequality,NDisequality) :-
	substitute(Disequality,V,N,Disequality1),
	N1 is N+1,
	rename_variables_gcp(Vars,N1,NVars,Disequality1,NDisequality).

%
%  Build a constraint graph.
%
build_constraint_graph([],_,[]).
build_constraint_graph([V|Vs],Disequality,[node(V,Order,Edge)|Gs]):-
	build_constraint_edges(Disequality,V,Order,Edge),
	build_constraint_graph(Vs,Disequality,Gs).

%
%  Build the edges corresponding to the variable V in a constraint graph.
%
build_constraint_edges(Disequality,V,Order,Edge) :-
	build_constraint_edges(Disequality,V,0,Order,[],Edge).

build_constraint_edges([],_,Order,Order,Edge,Edge).
build_constraint_edges([E|Es],V,Order,NOrder,Edge,NEdge):-
	(list_cas(E) ->
		build_constraint_edges(E,V,Order,Order1,Edge,Edge1);
		build_constraint_edge(E,V,Order,Order1,Edge,Edge1)),
	build_constraint_edges(Es,V,Order1,NOrder,Edge1,NEdge).
		
build_constraint_edge(E,V,Order,NOrder,Edge,NEdge) :-
	(constraint_edge(E,V,W) ->
		(member_cas(Edge,W) ->
			(NOrder = Order,
		 	 NEdge = Edge);
			(NOrder is Order+1,
			 NEdge = [W|Edge]));
		(NOrder = Order,
		 NEdge = Edge)).

%
%  Test if a disequality involve the variable V. If it does, also return the
%  other involved variable.
%
constraint_edge(U =\= W,V,W) :-
	U == V.
constraint_edge(W =\= U,V,W) :-
	U == V.
constraint_edge(U =\= W,V,_) :-
	U \== V,
	W \== V,
	fail.

%
%  Evaluate the value of a polynomial at a point.
%
evaluate_poly([],_,1).
evaluate_poly([Term|Poly],Point,Value) :-
	Term = k-Const,
	Term_value is Point-Const,
	evaluate_poly(Poly,Point,Values),
	(Term_value > 0 ->
		Value is Term_value*Values;
		Value = 0).
