%
%  normalize.pl			Nai-Wei Lin			December, 1991
%
%  This file contains the procedures for performing normalization.
%

%
%  Initialize the normalization queue.
%
init_normalize_queue(Pos,QHead,QTail) :-
	init_queue(QHead,ITail),
	set_put_queue(ITail,Pos,QTail).

%
%  Insert the predecessors of a position into the normalization queue.
%
insert_normalize_queue(Pos,Adg,QTail,NTail) :-
	find_adg_field(Adg,Pos,pred,EdgeList),
	set_put_queue(QTail,EdgeList,NTail).

%
%  Normalize an expression by the sizes in the normalization queue.
%

normalize(bot,_,_,_,_,_,_,_,_,_,_,_,bot).
normalize(Exp,QHead,QTail,_,_,_,_,_,_,_,_,_,Exp) :-
	Exp \== bot,
	empty_queue(QHead,QTail).
normalize(Exp,QHead,QTail,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,RSize,NExp) :-
	Exp \== bot,
	nonempty_queue(QHead,QTail),
	get_queue(QHead,Pos,NHead),
	(subterm(Pos,Exp) ->
		(normalize_pos(Exp,Pos,NHead,QTail,BT,ST,Comp,Clause,Adg,
			      Gvars,PosSet,ISize,RSize,NExp));
	(normalize(Exp,NHead,QTail,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,RSize,NExp))).
/*
normalize(Exp,QHead,QTail,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,RSize,NExp) :-
	(Exp==bot -> NExp=bot;
	    (Exp \== bot ->
		(empty_queue(QHead,QTail) -> Nexp=Exp);
		    (nonempty_queue(QHead,QTail) -> 
			(get_queue(QHead,Pos,NHead),
			(subterm(Pos,Exp) ->
			    (normalize_pos(Exp,Pos,NHead,QTail,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,RSize,NExp));
				(normalize(Exp,NHead,QTail,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,RSize,NExp)
			    )
			)
		    )
		)
	    )
	).



*/


%
%  Normalize an expression by the size of a position.
%
/*
normalize_pos(Exp,Pos,QHd,QTl,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,RSize,NExp) :-
	find_adg_field(Adg,Pos,(mode),+),
	pos_litnum(Pos,0),
	pos_argnum(Pos,ArgNum),
	ith_list_cas_element(ArgNum,ISize,Size),
	normalize_size(Exp,Pos,Size,QHd,QTl,BT,ST,Comp,Clause,Adg,Gvars,
		       PosSet,ISize,RSize,NExp).
normalize_pos(Exp,Pos,QHd,QTl,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,RSize,NExp) :-
	find_adg_field(Adg,Pos,(mode),+),
	pos_litnum(Pos,LitNum),
	LitNum > 0,
	clause_term_measure(BT,ST,Clause,Pos,Term,Measure),
	general_term_size(Measure,Clause,BT,ST,Gvars,PosSet,Term,Size),
	normalize_size(Exp,Pos,Size,QHd,QTl,BT,ST,Comp,Clause,Adg,Gvars,
		       PosSet,ISize,RSize,NExp).
normalize_pos(Exp,Pos,QHd,QTl,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,RSize,NExp) :-
	find_adg_field(Adg,Pos,(mode),-),
	pos_litnum(Pos,LitNum),
	pos_argnum(Pos,ArgNum),
	arg(2,Clause,Body),
	ith_body_literal(LitNum,Body,Lit),
	functor(Lit,F,N),
	(second_order_predicate(F/N) ->
		(second_order_predicate_pred_arg(Lit,Lit1),
		 functor(Lit1,F1,N1),
		 second_order_predicate_pred_num(Body,LitNum,Num),
		 literal_output_comp(F1/N1,Num,1,BT,ST,[],Adg,det,[],Size));
		literal_output_comp(F/N,LitNum,ArgNum,BT,ST,Comp,Adg,size,
			RSize,Size)),
	normalize_size(Exp,Pos,Size,QHd,QTl,BT,ST,Comp,Clause,Adg,Gvars,
		       PosSet,ISize,RSize,NExp).
*/

normalize_pos(Exp,Pos,QHd,QTl,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,RSize,NExp) :-

(find_adg_field(Adg,Pos,(mode),+) ->
    (
	pos_litnum(Pos,LitNum),
	(LitNum==0 ->
	    (
		pos_argnum(Pos,ArgNum),
		ith_list_cas_element(ArgNum,ISize,Size),
		normalize_size(Exp,Pos,Size,QHd,QTl,BT,ST,Comp,Clause,Adg,Gvars,
		PosSet,ISize,RSize,NExp)
	    );
	   (
	       LitNum > 0 ->
	       (
		   clause_term_measure(BT,ST,Clause,Pos,Term,Measure),
		   general_term_size(Measure,Clause,BT,ST,Gvars,PosSet,Term,Size),
		   normalize_size(Exp,Pos,Size,QHd,QTl,BT,ST,Comp,Clause,Adg,Gvars,
		   PosSet,ISize,RSize,NExp)
	       )
	   )
       )
   );
(find_adg_field(Adg,Pos,(mode),-) ->
    (
	pos_litnum(Pos,LitNum),
	pos_argnum(Pos,ArgNum),
	arg(2,Clause,Body),
	ith_body_literal(LitNum,Body,Lit),
	functor(Lit,F,N),
	(second_order_predicate(F/N) ->
	    (
		second_order_predicate_pred_arg(Lit,Lit1),
		functor(Lit1,F1,N1),
		second_order_predicate_pred_num(Body,LitNum,Num),
		literal_output_comp(F1/N1,Num,1,BT,ST,[],Adg,det,[],Size)
	    );
	    (literal_output_comp(F/N,LitNum,ArgNum,BT,ST,Comp,Adg,size,
	    RSize,Size))
	),
	normalize_size(Exp,Pos,Size,QHd,QTl,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,RSize,NExp)
    )
)
).





%
%  Normalize an expression by a size.
%
normalize_size(_,_,bot,_,_,_,_,_,_,_,_,_,_,_,bot).
normalize_size(Exp,Pos,Size,QHead,QTail,BT,ST,Comp,Clause,Adg,Gvars,PosSet,
	       ISize,RSize,NExp) :-
	Size \== bot,
	substitute(Exp,Pos,Size,Exp1),
	insert_normalize_queue(Pos,Adg,QTail,NTail),
	normalize(Exp1,QHead,NTail,BT,ST,Comp,Clause,Adg,Gvars,PosSet,ISize,
		  RSize,NExp).

%
%  Get the output complexity function of a literal in the clause.
%

literal_output_comp(LitName,LitNum,ArgNum,BT,ST,Component,Adg,Type,RComp,Comp) :-
	find_symbol_field_property(BT,LitName,Type,BuildinComp),
%	literal_property(BT,ST,LitName,Type,BuildinComp),
	lit_output_comp(BuildinComp,ST,Component,LitName,LitNum,ArgNum,Adg,Type,RComp,Comp).

lit_output_comp(BuildinComp,ST,Component,LitName,LitNum,ArgNum,Adg,Type,RComp,Comp) :-
	var(BuildinComp),
   
	(member_cas(Component,LitName) ->
	(rec_literal_comp(Adg,LitName,LitNum,ArgNum,RComp,Comp));
		(
		    find_symbol_field_property(ST,LitName,Type,LitComp),
		 (var(LitComp) ->
			(error_message(dec1,LitName,''),
			 Comp = bot);
			nonrec_literal_comp(LitComp,LitName,LitNum,ArgNum,
				Comp)))).
lit_output_comp(BuildinComp,_,_,LitName,LitNum,ArgNum,Adg,Type,_,Comp) :-

	nonvar(BuildinComp),
	buildin_output_comp(Type,LitName,LitNum,ArgNum,Adg,Comp).
/*

lit_output_comp(BuildinComp,BT,ST,Component,LitName,LitNum,ArgNum,Adg,Type,RComp,Comp) :-
	(var(BuildinComp) ->
	    ((member_cas(Component,LitName) ->
		rec_literal_comp(Adg,LitName,LitNum,ArgNum,RComp,Comp);
		(
		%find_symbol_field(ST,LitName,Type,LitComp),
		    literal_property(BT,ST,LitName,Type,LitComp),
		    (var(LitComp) ->
			(error_message(dec1,LitName,''),
			Comp = bot);
			nonrec_literal_comp(LitComp,LitName,LitNum,ArgNum,
			Comp)))));
				(nonvar(BuildinComp) ->
				    (buildin_output_comp(Type,LitName,LitNum,ArgNum,Adg,Comp))
				)
			    ).

*/

%
%  Generate the symbolic output complexity function for a recursive literal.
%
rec_literal_comp(Adg,LitName,LitNum,ArgNum,RComp,Comp) :-
	find_recursive_comp(RComp,LitName,Rcomp),
	LitName = F/A,
	(var(Rcomp) ->
		(gen_literal_iopos(Adg,LitName,LitNum,(+),Pos),
		 Comp =.. [F,A,ArgNum|Pos]);
		(ith_list_cas_element(ArgNum,Rcomp,Comp1),
		 substitute_literal_formal(A,Comp1,LitNum,Comp))).

%
%  Find the mutual recursive complexity when available.
%
find_recursive_comp([],_,_).
find_recursive_comp([comp(LitName,Rcomp)|_],LitName,Rcomp).
find_recursive_comp([comp(Pred,_)|RComp],LitName,Rcomp) :-
	Pred \== LitName,
	find_recursive_comp(RComp,LitName,Rcomp).

%
%  Substitute the actuals for the formals in the output complexity functions 
%  of a nonrecursive literal.
%
nonrec_literal_comp([C|_],LitName,LitNum,1,Comp) :-
	LitName = _/A,
	substitute_literal_formal(A,C,LitNum,Comp).
nonrec_literal_comp([_|CompList],LitName,LitNum,ArgNum,Comp) :-
	ArgNum > 1,
	ArgNum1 is ArgNum-1,
	nonrec_literal_comp(CompList,LitName,LitNum,ArgNum1,Comp).

%
%  Substitute an actual for a formal in the output complexity function 
%  of a nonrecursive literal.
%
substitute_literal_formal(0,Comp,_,Comp).
substitute_literal_formal(A,C,LitNum,Comp) :-
	A > 0,
	new_pos(0,A,Pos1),
	new_pos(LitNum,A,Pos2),
	substitute(C,Pos1,Pos2,C1),
	A1 is A-1,
	substitute_literal_formal(A1,C1,LitNum,Comp).

%
%  Substitute all occurrences of a subterm by another subterm.
%
substitute(Term,Var,NTerm,NTerm) :-
	Term == Var.
substitute(Term,Var,_,Term) :-
	Term \== Var,
	var(Term).
substitute(Term,Var,_,Term) :-
	Term \== Var,
	atomic(Term).
substitute(Term,Var,NVar,NTerm) :-
	Term \== Var,
	compound_cas(Term),
	functor(Term,F,N),
	functor(NTerm,F,N),
	substitute(N,Term,Var,NVar,NTerm).

substitute(0,_,_,_,_).
substitute(N,Term,Var,NVar,NTerm) :-
	N > 0,
	arg(N,Term,Arg),
	substitute(Arg,Var,NVar,NArg),
	arg(N,NTerm,NArg),
	N1 is N-1,
	substitute(N1,Term,Var,NVar,NTerm).
	
%
%  Substitute the actuals for the formals in the output complexity function 
%  for an output position of a buildin predicate.
%
buildin_output_comp(size,LitName,LitNum,ArgNum,Adg,Comp) :-
	buildin_output_size(LitName,LitNum,ArgNum,Adg,Comp).
buildin_output_comp(det,_,_,_,_,1).
buildin_output_comp(time,_,_,_,_,0).

%
%  Substitute the actuals for the formals in the output size function 
%  for an output position of a buildin predicate.
%
buildin_output_size((is)/2,LitNum,1,_,Pos) :-
	new_pos(LitNum,2,Pos).
buildin_output_size((=)/2,LitNum,1,Adg,Size) :-
	new_pos(LitNum,1,Pos1),
	new_pos(LitNum,2,Pos2),
	find_adg_field(Adg,Pos1,pred,Pos),
	(var(Pos) ->
		Size = bot;
		Size = Pos2).
buildin_output_size((=)/2,LitNum,2,Adg,Size) :-
	new_pos(LitNum,1,Pos1),
	new_pos(LitNum,2,Pos2),
	find_adg_field(Adg,Pos2,pred,Pos),
	(var(Pos) ->
		Size = bot;
		Size = Pos1).
buildin_output_size(functor/3,_,2,_,1).
buildin_output_size(functor/3,LitNum,3,_,arity(Pos)) :-
	new_pos(LitNum,1,Pos).
buildin_output_size(arg/3,LitNum,3,_,arg(Pos2,Pos1)) :-
	new_pos(LitNum,1,Pos1),
	new_pos(LitNum,2,Pos2).
buildin_output_size(functor1/3,_,1,_,1).
buildin_output_size(arg/4,LitNum,4,_,Pos2+Pos3) :-
	new_pos(LitNum,2,Pos2),
	new_pos(LitNum,3,Pos3).
%buildin_output_size((=..)/2,LitNum,2,_,arity(Pos)+1) :-
%	new_pos(LitNum,1,Pos).
