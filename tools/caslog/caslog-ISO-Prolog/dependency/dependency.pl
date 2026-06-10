%
%  dependency.pl		Nai-Wei Lin			November, 1991
%
%  This file contains the procedures for performing the data dependency
%  analysis for the predicates in the program in topologically sorted order.
%

%
%  Perform the data dependency analysis for a strongly connected component.
%
dependency_analysis([],_,_,[],[],[],1).
dependency_analysis([Pred|CompList],BT,ST,[Adg|AList],[Ldg|LList],
		    [Gvars|GList],Error) :-
	dependency_predicate(Pred,BT,ST,Adg,Ldg,Gvars,Error1),
	dependency_analysis(CompList,BT,ST,AList,LList,GList,Error2),
	Error is Error1*Error2.

%
%  Perform the data dependency analysis for a predicate.
%
dependency_predicate(Pred,BT,ST,Adg,Ldg,Gvars,Error) :-
	find_symbol_field_clause(ST,Pred,clause,Clauses),
	find_symbol_field(ST,Pred,(mode),Mode),
	mutual_exclusive_classes(Clauses,Mode,Classes),
	nl,nl,
	write('*********************************************************'),nl,
	write('                         '),write(Pred),write('                           '),nl,
	write('*********************************************************'),nl,
	nl,
	write('* Mutually exclusive classes of clauses for predicate '),
	write(Pred),
	write(' :'),
	nl,nl,
	write(Classes),nl,
	
	insert_symbol_field_mutex(ST,Pred,mutex,Classes),
	dependency_clauses(Clauses,BT,ST,Adg,Ldg,Gvars,Error).

%
%  Perform the data dependency analysis for the set of clauses in a predicate.
%
dependency_clauses(Clauses,_,_,[],[],[],1) :-
	var(Clauses).
dependency_clauses(Clauses,BT,ST,[Adg|AList],[Ldg|LList],[Gvars|GList],Error) :-
	nonvar(Clauses),
	Clauses = [Clause|CList],
	dependency_clause(Clause,BT,ST,Adg,Ldg,Gvars,Error1),
	dependency_clauses(CList,BT,ST,AList,LList,GList,Error2),
	Error is Error1*Error2.

%
%  Perform the data dependency analysis for a clause.
%
dependency_clause(Clause,BT,ST,Adg,Ldg,Gvars,Error) :-
	clause_type(Clause,Type),
	argument_dependency_graph(Type,Clause,BT,ST,Adg,Gvars,Error),
	literal_dependency_graph(Adg,Ldg).

