%
%  determinacy.pl		Nai-Wei Lin			May 1992
%
%  This file contains the procedures for performing the determinacy analysis
%  for the predicates in the program in topologically sorted order.
%

%
%  Perform the determinacy analysis for a strongly connected component.
%
determinacy_analysis(Comp,BT,ST,Adg) :-
	initial_determinacy(Comp,Det),
	determinacy_analysis1(Comp,BT,ST,Comp,Adg,Det).

determinacy_analysis1(Comp,BT,ST,Comp,Adg,Det) :-
	determinacy_analysis2(Comp,BT,ST,Comp,Det,Adg,NDet),
	(Det == NDet ->
		insert_determinacy(Det,ST);
		determinacy_analysis1(Comp,BT,ST,Comp,Adg,NDet)).

determinacy_analysis2([],_,_,_,_,_,[]).
determinacy_analysis2([Pred|Comps],BT,ST,Comp,CompDet,[Adg|AList],
		[comp(Pred,Det)|Dets]) :-
	determinacy_predicate(Pred,BT,ST,Comp,CompDet,Adg,Det),
	determinacy_analysis2(Comps,BT,ST,Comp,CompDet,AList,Dets).

%
%  Perform the determinacy analysis for a predicate.
%
determinacy_predicate(Pred,BT,ST,Comp,CompDet,Adg,Det) :-
	find_symbol_field_mutex(ST,Pred,mutex,Mutex),
	(pairwise_mutual_exclusion(Mutex) ->
		(find_symbol_field_clause(ST,Pred,clause,Clauses),
		 determinacy_clauses(Clauses,BT,ST,Comp,CompDet,Adg,Det));
		Det = 0).

%
%  Perform the determinacy analysis for the set of clauses in a predicate.
%
determinacy_clauses(Clauses,_,_,_,_,_,1) :-
	var(Clauses).
determinacy_clauses(Clauses,BT,ST,Comp,CompDet,[Adg|AList],Det) :-
	nonvar(Clauses),
	Clauses = [Clause|CList],
	determinacy_clause(Clause,BT,ST,Comp,CompDet,Adg,Det1),
	(Det1 == 1 ->
		determinacy_clauses(CList,BT,ST,Comp,CompDet,AList,Det);
		Det = 0).

%
%  Perform the determinacy analysis for a clause.
%
determinacy_clause(Clause,BT,ST,Comp,CompDet,Adg,Det) :-
	clause_type(Clause,Type),
	determinacy_clause(Type,Clause,BT,ST,Comp,CompDet,Adg,Det).

determinacy_clause(2,Clause,BT,ST,Comp,CompDet,Adg,Det) :-
	Clause = (_ :- Body),
	no_of_cuts(Body,Cuts),
	determinacy_body(Body,1,BT,ST,Comp,Cuts,CompDet,Adg,Clause,Det).
determinacy_clause(3,_,_,_,_,_,_,1).

%
%  Perform the determinacy analysis for the body of a clause.
%
/*
determinacy_body((Lit,Body),Num,BT,ST,Comp,Cuts,CompDet,Adg,Clause,Det) :-
	Num1 is Num+1,
	(Lit == (!) ->
		(Cuts1 is Cuts-1,
		 determinacy_body(Body,Num1,BT,ST,Comp,Cuts1,CompDet,Adg,Clause,Det));
		(Cuts > 0 ->
		 	determinacy_body(Body,Num1,BT,ST,Comp,Cuts,CompDet,Adg,Clause,Det);
			(determinacy_literal(Lit,Num,BT,ST,Comp,CompDet,Adg,Clause,Det1),
			 (Det1 == 1 ->
				determinacy_body(Body,Num1,BT,ST,Comp,Cuts,
					CompDet,Adg,Clause,Det);
				Det = 0)))).
determinacy_body(Lit,Num,BT,ST,Comp,_,CompDet,Adg,Clause,Det) :-
	nonsequence(Lit),
	(Lit == (!) ->
		Det = 1;
		determinacy_literal(Lit,Num,BT,ST,Comp,CompDet,Adg,Clause,Det)).
*/

determinacy_body(L,Num,BT,ST,Comp,Cuts,CompDet,Adg,Clause,Det) :-
(L=(Lit,Body) ->
    (Num1 is Num+1,
	(Lit == (!) ->
		(Cuts1 is Cuts-1,
		determinacy_body(Body,Num1,BT,ST,Comp,Cuts1,CompDet,Adg,Clause,Det));
		(Cuts > 0 ->
		    determinacy_body(Body,Num1,BT,ST,Comp,Cuts,CompDet,Adg,Clause,Det);
			(determinacy_literal(Lit,Num,BT,ST,Comp,CompDet,Adg,Clause,Det1),
			(Det1 == 1 ->
			    determinacy_body(Body,Num1,BT,ST,Comp,Cuts,
			    CompDet,Adg,Clause,Det);
			    Det = 0))))
			);
			(L=Lit ->
			    (nonsequence(Lit),
			    (Lit == (!) ->
				Det = 1;
				determinacy_literal(Lit,Num,BT,ST,Comp,CompDet,Adg,Clause,Det))
			    )
			)
		    ).



%
%  Perform the determinacy analysis for a literal.
%
determinacy_literal(Lit,LitNum,BT,ST,Comp,CompDet,Adg,Clause,Det) :-
	functor(Lit,F,A),
	(second_order_predicate(F/A) ->
		%% handle setof predicate
		(second_order_predicate_pred_arg(Lit,NLit),
		 functor(NLit,NF,NA),
		 arg(2,Clause,Body),
		 second_order_predicate_pred_num(Body,LitNum,Num),
		 gen_literal_iopos(Adg,(NF/NA),Num,(-),Pos),
		 pos_var(Pos,NLit,Vars),
		 arg(1,Lit,Arg1),
		 term_var(Arg1,Var1),
		 (opened_set_equivalent(Var1,Vars) ->
			Det = 1;
			Det = 0));
		%% handle other predicates
		(member_cas(Comp,(F/A)) ->
		   find_recursive_comp(CompDet,(F/A),Det);
		   (literal_property(BT,ST,(F/A),det,[Det1]),
		    ((Det1 == 0; Det1 == 1) ->
			Det = 1;
			Det = 0)))).
		
%
%  Initialize the determinacy to `true' for the predicates in the component.
%
initial_determinacy([],[]).
initial_determinacy([Pred|Comp],[comp(Pred,1)|Det]) :-
	initial_determinacy(Comp,Det).

%
%  Define the det field for the determinate predicates in the component.
%
insert_determinacy([],_).
insert_determinacy([comp(Pred,Det)|Dets],ST) :-
	(Det == 1 ->
		(find_symbol_field_relation(ST,Pred,relation,Rel),
		 (Rel == 0 ->
			insert_symbol_field_det(ST,Pred,det,[0]);
			insert_symbol_field_det(ST,Pred,det,[1])));
		true),
	insert_determinacy(Dets,ST).

%
%  Test if the clauses of a predicate is pairwise mutually exclusive.
%
pairwise_mutual_exclusion([]).
pairwise_mutual_exclusion([[_]|Mutex]) :-
	pairwise_mutual_exclusion(Mutex).
