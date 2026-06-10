%
%  clause.pl			Nai-Wei Lin			December, 1991
%
%  This file contains the procedures for finding information about a clause
%  or a literal in a clause.
%

%
%  Get the term and its measure at an argument position of a clause.
%
clause_term_measure(BT,ST,Clause,Pos,Term,Measure) :-
	pos_litnum(Pos,LitNum),
  %write('\nLitNum'),write(LitNum),nl,
	(LitNum > 0 ->
		(arg(2,Clause,Body),
		 number_of_literals(Body,1,Num),
		 (LitNum > Num ->
			NewNum is LitNum-Num;	% assume depth-one single pred
			NewNum = LitNum));
		NewNum = LitNum),
	ith_clause_literal(NewNum,Clause,Lit),
%	write('\nLit'),write(Lit),nl,
	(LitNum > 0 ->
	  ( LitNum > Num ->
		second_order_predicate_pred_arg(Lit,NewLit);NewLit = Lit);
		NewLit = Lit),
 
	pos_argnum(Pos,ArgNum),
	arg(ArgNum,NewLit,Term),
	functor(NewLit,F,A),
	literal_property(BT,ST,F/A,measure,MeasureList),
	ith_list_cas_element(ArgNum,MeasureList,Measure).
	
/*
clause_term_measure(_,ST,Clause,Pos,Term,Measure) :-
	pos_litnum(Pos,0),
	pos_argnum(Pos,N),
	head_term_measure(ST,Clause,N,Term,Measure).
clause_term_measure(BT,ST,Clause,Pos,Term,Measure) :-
	pos_litnum(Pos,M),
	M > 0,
	pos_argnum(Pos,N),
	body_term_measure(BT,ST,Clause,M,N,Term,Measure).
*/
%
%  Get the term and its measure at an argument position of the head.
%
head_term_measure(ST,Clause,N,Term,Measure) :-
	clause_type(Clause,Type),
	(Type =:= 2 ->
		arg(1,Clause,Head);
		Clause = Head),
	arg(N,Head,Term),
	functor(Head,F,A),
	find_symbol_field_measure(ST,F/A,measure,MeasureList),
	ith_list_cas_element(N,MeasureList,Measure).

%
%  Get the term and its measure at an argument position of a body literal.
%
body_term_measure(BT,ST,Clause,M,N,Term,Measure) :-
	arg(2,Clause,Body),
	literal_term_measure(BT,ST,Body,1,M,N,Term,Measure).

%
%  Get the term and its measure at an argument position of a literal.
%
literal_term_measure(BT,ST,(Lit,_),M,M,N,Term,Measure) :-
	arg(N,Lit,Term),
	functor(Lit,F,A),
	find_symbol_field_measure(BT,F/A,measure,MeasureList),
	(var(MeasureList) ->
		find_symbol_field_measure(ST,F/A,measure,MeasureList);
		true),
	ith_list_cas_element(N,MeasureList,Measure).
literal_term_measure(BT,ST,Body,M,M,N,Term,Measure) :-
	nonsequence(Body),
	arg(N,Body,Term),
	functor(Body,F,A),
	find_symbol_field_measure(BT,F/A,measure,MeasureList),
	(var(MeasureList) ->
		find_symbol_field_measure(ST,F/A,measure,MeasureList);
		true),
	ith_list_cas_element(N,MeasureList,Measure).
literal_term_measure(BT,ST,(_,Body),I,M,N,Term,Measure) :-
	I < M,
	I1 is I+1,
	literal_term_measure(BT,ST,Body,I1,M,N,Term,Measure).
literal_term_measure(_,_,Body,I,M,_,_,_) :-
	I > M,
	nonsequence(Body),
  write('illegal argument position').
%	error_message('illegal argument position').

%
%  Get the ith literal in the clause.
%
ith_clause_literal(I,Clause,Lit) :-
	clause_type(Clause,Type),
	ith_clause_literal(Type,I,Clause,Lit).

ith_clause_literal(2,0,Clause,Lit) :-
	arg(1,Clause,Lit).
ith_clause_literal(2,I,Clause,Lit) :-
	I > 0,
	arg(2,Clause,Body),
	ith_body_literal(I,Body,Lit).
ith_clause_literal(3,0,Clause,Clause).

%
%  Get the ith literal in the body.
%

/*

ith_body_literal(LitNum,(_,Body),Lit) :-
	LitNum > 1,
	LitNum1 is LitNum-1,
	ith_body_literal(LitNum1,Body,Lit).

ith_body_literal(1,(Lit,_),Lit).
ith_body_literal(1,Lit,Lit) :-
	nonsequence(Lit).
*/

ith_body_literal(LitNum,L,Lit) :-
	(LitNum==1 ->
	    (L=(Lite,_) -> (Lit=Lite);
		(L=Lit) -> (nonsequence(Lit)));
		    ((LitNum > 1, L=(_,Body)) ->
			(LitNum1 is LitNum-1,
			ith_body_literal(LitNum1,Body,Lit)))).




%
/*
number_of_literals(Lit,Num,Num) :-
	nonsequence(Lit).
number_of_literals((_,Body),N1,Num) :-
	N2 is N1+1,
	number_of_literals(Body,N2,Num).

*/


number_of_literals(L,N1,Num):-
  (L=(_,Body) ->
      (N2 is N1+1,
	number_of_literals(Body,N2,Num));
	(L=Lit ->
	    (nonsequence(Lit) -> Num=N1)
	)
    ).
	
