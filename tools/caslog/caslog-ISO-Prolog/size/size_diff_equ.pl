%
%  size_diff_equ.pl		Nai-Wei Lin			February, 1992
%
%  This file contains the programs for solving the size difference equations.
%

%
%  Solve size equations.
%
solve_size_equs(Pred,ST,Component,Size,Sol) :-
	find_symbol_field(ST,Pred,(mode),Mode),
	%on recupere la taille des entrés dans Size
	input_sizes(Size,Mode,ISize),
	%write('\nIsize='),write(ISize),
/*Clauses recursifs : consistant_input_sizes recupere les tailles des entrees qui sont les memes pour les clauses recursifs*/
/*Clauses nonrecursif : consistant_input_size recupere les tailles des entrées qui les memes pour toutes les clauses*/
	(consistent_input_sizes(Pred,ST,Component,ISize,Isize) ->
		(
		solve_size_complexity_equs(Pred,ST,Mode,Size,ISize,Osize),
		combine_size(Mode,Isize,Osize,Sol));
		(dummy_size(Mode,1,Sol))).

%
%  Solve size complexity equations.
%
solve_size_complexity_equs(Pred,ST,Mode,Size,ISize,Sol) :-
	construct_size_comp_equs(Mode,1,Size,ISize,Equs,OIndex),
	solve_size_comp_equs(Equs,ST,Pred,OIndex,Sol).

%
%  Construct the complexity equations for each output position and
%  a list of indices for output positions.
%
construct_size_comp_equs([],_,_,_,[],[]).
construct_size_comp_equs([+|Mode],I,Size,ISize,Equs,OIndex) :-
	I1 is I+1,
	construct_size_comp_equs(Mode,I1,Size,ISize,Equs,OIndex).
construct_size_comp_equs([-|Mode],I,Size,ISize,[E|Equs],[I|OIndex]) :-
	output_sizes(Size,I,OSize),
	construct_comp_equs(ISize,OSize,1,E),
	I1 is I+1,
	construct_size_comp_equs(Mode,I1,Size,ISize,Equs,OIndex).

%
%  Solve the set of size complexity equations.
%
solve_size_comp_equs([],_,_,[],[]).
solve_size_comp_equs([E|Equs],ST,Pred,[I|OIndex],[S|Sols]) :-
	classify_equs(E,DE,BE),
%BE : l'equation d'initialisation
%DE : les autres equations
%	write('\nDE='),write(DE),
%	write('\nBE='),write(BE),
	solve_size_comp_equs1(DE,BE,ST,Pred,I,NS),
	general_form(NS,S),
	solve_size_comp_equs(Equs,ST,Pred,OIndex,Sols).

solve_size_comp_equs1(DE,BE,ST,Pred,I,Sol) :-
	abnormal_equs(BE,S),
%	write('\nS='),write(S),nl,
	(general_form(S,0) ->
(	solve_size_comp_equs2(DE,BE,ST,Pred,I,Sol));	% no abnormals
		Sol = S).

%s
%  Test if any abnormal size equation exists.
%
abnormal_equs([],Zero) :- normal_form(0,Zero).
abnormal_equs([equ(_,_,O)|BE],Sol) :-
	abnormal_equ(O,S1),
	abnormal_equs(BE,S2),
	max_expr(S1,S2,Sol).

abnormal_equ(bot,bot) :- !.
abnormal_equ(inf,inf) :- !.
abnormal_equ(_,Zero) :- normal_form(0,Zero).

%
%  Solve the set of size complexity equations corresponding one output position.
%
solve_size_comp_equs2(DE,[],_,Pred,_,Sol) :-	% no base cases
	DE \== [],!,
	(indirect_recursion(DE,Pred) ->
		solve_comp_non_diff_equs(DE,Sol);
		Sol = bot).
solve_size_comp_equs2([],BE,_,_,_,Sol) :-	% no difference equations
	BE \== [],!,
	solve_comp_non_diff_equs(BE,Sol).
solve_size_comp_equs2(DE,BE,ST,Pred,I,Sol) :-	% both diff equs and base cases
	DE \== [],
	BE \== [],
	(indirect_recursion(DE,Pred) ->
		(solve_comp_non_diff_equs(DE,S1),
		 solve_comp_non_diff_equs(BE,S2),
		 max_expr(S1,S2,Sol));
		solve_size_comp_diff_equs(DE,BE,ST,Pred,I,Sol)).

%
%
solve_size_comp_diff_equs(Equ,BEqus,ST,Pred,I,Sol) :-
%ROC pour les equations recurssifs et RBC pour la clause de depart
%ils sont de la forme expr(ClauseNum,TaillleArg,equationTailleClause),
%TailleArg : la taille de l'argument d'entrée pour la clause correspondant qui est different des autres arguments à la meme
%position dans les autres clauses
	exprs_one_index_reducible(Equ,Pred,I,IS,ROC,Pos),


	boundary_condition_one_index_reducible(BEqus,IS,Pos,RBC),

	solve_one_index_size_diff_equs(ROC,RBC,ST,Pred,Pos,Sol),!.




solve_size_comp_diff_equs(Equ,BEqus,_,Pred,I,Sol) :-
	exprs_two_indices_reducible(Equ,Pred,I,IS,Pos),
	adjust_pos(Pos,NPos),
	reduce_two_indices_exprs(Equ,Pred,I,IS,NPos,NEqu),
	NPos = [Pos1,Pos2],
	POS1 is Pos1-2,
	POS2 is Pos2-2,
	boundary_condition_two_indices_reducible(BEqus,IS,[POS1,POS2],BCs),
	solve_two_indices_diff_equs(NEqu,BCs,Pred,Sol),!.
solve_size_comp_diff_equs(_,_,_,_,_,inf).


solve_one_index_size_diff_equs([],_,_,_,_,Zero) :- normal_form(0,Zero).
solve_one_index_size_diff_equs([equ(_,Var,OC)|OCs],BEqus,ST,Pred,Pos,Sol) :-
	%diff_equ_type(OC,Var,Pred,An1,An2,Bn,Type),
	%general_form(OC,R),
	%write(R),nl,
	%write(Var),nl,
	(indirect_recursion_expr(OC,Pred) ->
		S = OC;
		(solve_typed_diff_equ(size,OC,BEqus,Var,ST,Pred,Pos,S))),
	%general_form(S,GS),
	%write(GS),nl,
	%solve_one_index_size_diff_equ(Type,BEqus,Var,An1,An2,Bn,ST,Pred,Pos,S),
	solve_one_index_size_diff_equs(OCs,BEqus,ST,Pred,Pos,Sols),
	max_expr(Sols,S,Sol).

%
solve_one_index_size_diff_equ(second_order,BE,Var,An1,An2,Bn,_,_,_,Sol) :-
	!, 
	boundary_conds(BE,Ival),
	%write(Ival),nl,
	solve_diff_equ(second_order,Var,An1,An2,Bn,Ival,Sol).

solve_one_index_size_diff_equ(Type,BE,Var,An1,An2,Bn,ST,Pred,Pos,Sol) :-
	solve_one_index_size_diff_equ1(BE,Type,Var,An1,An2,Bn,ST,Pred,Pos,Sol).

%
solve_one_index_size_diff_equ1([],_,_,_,_,_,_,_,_,Zero) :-
	normal_form(0,Zero).
solve_one_index_size_diff_equ1([E|BE],Type,Var,An1,An2,Bn,ST,Pred,Pos,Sol) :-
	E = equ(_,Index,Val),
	(integer(Index) ->
		(boundary_conds([E],Ival),
		%write('\n\n--------Ival :'), write(Ival),nl,
		 solve_diff_equ(Type,Var,An1,An2,Bn,Ival,S));
		(size_boundary_cond(E,ST,Pred,Pos,Ival),
		% write('\n\n-------Ival :'),write(Ival),nl,
		 solve_diff_equ(Type,Var,An1,An2,Bn,Ival,TS),
		 max_expr(TS,Val,S))),
	%general_form(S,GS),
	%write(GS),nl,
	solve_one_index_size_diff_equ1(BE,Type,Var,An1,An2,Bn,ST,Pred,Pos,Sols),
	max_expr(Sols,S,Sol).

%
solve_two_indices_diff_equs([],_,_,Zero) :- normal_form(0,Zero).
solve_two_indices_diff_equs([equ(_,Vars,OC)|Equ],BCs,Pred,Sol) :-
	solve_two_indices_diff_equ(OC,BCs,Vars,Pred,Sol1),
	solve_two_indices_diff_equs(Equ,BCs,Pred,Sol2),
	max_expr(Sol1,Sol2,Sol).

solve_two_indices_diff_equ(Equ,BCs,Vars,Pred,Sol) :-
	two_indices_diff_equ_type(Equ,Vars,Pred,An,Bn,Type),
	solve_two_indices_diff_equ(Type,BCs,Vars,An,Bn,Sol),!.
solve_two_indices_diff_equ(_,_,_,_,inf).

solve_two_indices_diff_equ(first_index,BCs,Vars,An,Bn,Sol) :-
	two_indices_boundary_cond_type(BCs,Vars,_,Ivalue,_,BType),
	Vars = [Var1,_],
	((BType == exclusive; BType == both) ->
		solve_fode(Var1,Ivalue,An,Bn,Sol);
		Sol = inf).
solve_two_indices_diff_equ(second_index,BCs,Vars,An,Bn,Sol) :-
	two_indices_boundary_cond_type(BCs,Vars,_,_,Ivalue,BType),
	Vars = [_,Var2],
	((BType == exclusive; BType == both) ->
		solve_fode(Var2,Ivalue,An,Bn,Sol);
		Sol = inf).
solve_two_indices_diff_equ(both_indices,BCs,Vars,An,Bn,Sol) :-
	two_indices_boundary_cond_type(BCs,Vars,Ivalue,Ivalue1,Ivalue2,BType),
	Vars = [Var1,Var2],
	(BType == inclusive ->
		solve_fode(Var1,Ivalue,An,Bn,Sol);
	 	((BType == exclusive; BType == both) ->
			(solve_fode(Var1,Ivalue1,An,Bn,Sol1),
			 solve_fode(Var2,Ivalue2,An,Bn,Sol2),
			 max_expr(Sol1,Sol2,Sol));
			Sol = inf)).

two_indices_diff_equ_type(Equ,[Var1,Var2],F/_,An,Bn,Type) :-
	Equ = expr([term([DVar],An)],Bn),
	userfunc(DVar),
	functor(DVar,F,2),
	arg(1,DVar,Arg1),
	arg(2,DVar,Arg2),
	two_indices_equ_type(Arg1,Arg2,Var1,Var2,Type).

two_indices_equ_type(Arg1,Arg2,Var1,Var2,first_index) :-
	normal_form(Var1-1,Arg1),
	normal_form(Var2,Arg2).
two_indices_equ_type(Arg1,Arg2,Var1,Var2,second_index) :-
	normal_form(Var1,Arg1),
	normal_form(Var2-1,Arg2).
two_indices_equ_type(Arg1,Arg2,Var1,Var2,both_indices) :-
	normal_form(Var1-1,Arg1),
	normal_form(Var2-1,Arg2).

two_indices_boundary_cond_type([equ(_,[0,0],Expr)],_,[val(Zero,Expr)],_,_,
	inclusive) :- normal_form(0,Zero).
two_indices_boundary_cond_type([equ(_,[0,Var2],Expr1),equ(_,[Var1,0],Expr2)],
	[Var1,Var2],_,[val(Zero,Expr1)],[val(Zero,Expr2)],exclusive) :-
	normal_form(0,Zero).
two_indices_boundary_cond_type([equ(_,[Var1,0],Expr2),equ(_,[0,Var2],Expr1)],
	[Var1,Var2],_,[val(Zero,Expr1)],[val(Zero,Expr2)],exclusive) :-
	normal_form(0,Zero).
two_indices_boundary_cond_type([equ(_,[0,0],Expr),equ(_,[0,Var2],Expr1),
	equ(_,[Var1,0],Expr2)],[Var1,Var2],[val(Zero,Expr)],[val(Zero,Expr1)],
	[val(Zero,Expr2)],both) :-
	normal_form(0,Zero).
two_indices_boundary_cond_type([equ(_,[0,0],Expr),equ(_,[Var1,0],Expr2),
	equ(_,[0,Var2],Expr1)],[Var1,Var2],[val(Zero,Expr)],[val(Zero,Expr1)],
	[val(Zero,Expr2)],both) :-
	normal_form(0,Zero).
two_indices_boundary_cond_type([equ(_,[0,Var2],Expr1),equ(_,[0,0],Expr),
	equ(_,[Var1,0],Expr2)],[Var1,Var2],[val(Zero,Expr)],[val(Zero,Expr1)],
	[val(Zero,Expr2)],both) :-
	normal_form(0,Zero).
two_indices_boundary_cond_type([equ(_,[0,Var2],Expr1),equ(_,[Var1,0],Expr2),
	equ(_,[0,0],Expr)],[Var1,Var2],[val(Zero,Expr)],[val(Zero,Expr1)],
	[val(Zero,Expr2)],both) :-
	normal_form(0,Zero).
two_indices_boundary_cond_type([equ(_,[Var1,0],Expr2),equ(_,[0,0],Expr),
	equ(_,[0,Var2],Expr1)],[Var1,Var2],[val(Zero,Expr)],[val(Zero,Expr1)],
	[val(Zero,Expr2)],both) :-
	normal_form(0,Zero).
two_indices_boundary_cond_type([equ(_,[Var1,0],Expr2),equ(_,[0,Var2],Expr1),
	equ(_,[0,0],Expr)],[Var1,Var2],[val(Zero,Expr)],[val(Zero,Expr1)],
	[val(Zero,Expr2)],both) :-
	normal_form(0,Zero).
two_indices_boundary_cond_type(_,_,_,_,_,no_match).

%
%  Reduce a difference equation to an one-index difference equation.
%
exprs_one_index_reducible([],_,_,_,[],_).
exprs_one_index_reducible([equ(Num,IS,OC)|Equ],Pred,I,IS,
		[equ(Num,Var,ROC)|OCs],Pos) :-
	expr_one_index_reducible(OC,Pred,I,IS,ROC,Pos),
	ith_list_cas_element(Pos,IS,Var),
	exprs_one_index_reducible(Equ,Pred,I,IS,OCs,Pos).

expr_one_index_reducible(expr(T,F),Pred,I,ISize,expr(NT,F),Pos) :-
	term_one_index_reducible(T,Pred,I,ISize,0,NT,Pos1),
	Pos is Pos1-2.

term_one_index_reducible([],_,_,_,0,[],_) :- fail.
term_one_index_reducible([],_,_,_,Flag,[],_) :-
	Flag > 0.
term_one_index_reducible([term(P,F)|T],Pred,I,ISize,Flag,[term(NP,F)|NT],Pos) :-
	primary_one_index_reducible(P,Pred,I,ISize,Flag1,NP,Pos),
	Flag2 is Flag1+Flag,
	term_one_index_reducible(T,Pred,I,ISize,Flag2,NT,Pos).

primary_one_index_reducible([],_,_,_,0,[],_).
primary_one_index_reducible([P|Ps],F/A,I,ISize,Flag,[R|Rs],Pos) :- % direct recursion
	userfunc(P), functor(P,F,N), arg(1,P,Arity),
	normal_form(A,Arity),
	arg(2,P,Index),
	normal_form(I,Index),
	one_arg_diff(3,N,P,ISize,0,RArg,Pos),
	functor(R,F,1), arg(1,R,RArg),
	primary_one_index_reducible(Ps,F/A,I,ISize,Flag1,Rs,Pos),
	Flag is Flag1+1.
primary_one_index_reducible([P|Ps],F/A,I,ISize,Flag,[P|Rs],Pos) :-	% indirect recursion
	userfunc(P), functor(P,F1,_),
	F1 \== F,
	primary_one_index_reducible(Ps,F/A,I,ISize,Flag,Rs,Pos).
primary_one_index_reducible([P|Ps],F/A,I,ISize,Flag,[P|Rs],Pos) :-	% indirect recursion
	userfunc(P), functor(P,F,_), arg(1,P,Arity),
	general_form(Arity,GArity),
	GArity \== A,
	primary_one_index_reducible(Ps,F/A,I,ISize,Flag,Rs,Pos).
primary_one_index_reducible([P|Ps],F/A,I,ISize,Flag,[R|Rs],Pos) :- % direct recursion
	P = sum(Index,Lower,Upper,Expr),
	Expr = expr([term([P1],FS)],CS),
	userfunc(P1), functor(P1,F,N), arg(1,P1,Arity),
	normal_form(A,Arity),
	arg(2,P1,OPos),
	normal_form(I,OPos),
	one_arg_diff(3,N,P1,ISize,0,RArg,Pos),
	functor(R1,F,1), arg(1,R1,RArg),
	RExpr = expr([term([R1],FS)],CS),
	R = sum(Index,Lower,Upper,RExpr),
	primary_one_index_reducible(Ps,F/A,I,ISize,Flag1,Rs,Pos),
	Flag is Flag1+1.

%
%  Test if the number of different arguments is 1.
%
one_arg_diff(M,N,_,[],1,_,_) :- M > N.
one_arg_diff(M,N,F,[S|ISize],Count,RArg,I) :- M =< N,
	arg(M,F,Arg), normal_form(S,Arg),!,
	M1 is M+1,
	one_arg_diff(M1,N,F,ISize,Count,RArg,I).
one_arg_diff(M,N,F,[S|ISize],0,Arg,M) :- M =< N,
	arg(M,F,Arg), normal_form(S,S1),
	S1 \== Arg, variable(S),
	M1 is M+1,
	one_arg_diff(M1,N,F,ISize,1,Arg,M).

%
%  Reduce a difference equation to an two-indices difference equation.
%
exprs_two_indices_reducible(Equ,Pred,I,IS,Pos) :-
	exprs_two_indices_reducible1(Equ,Pred,I,IS,Pos),
	length(Pos,Len), Len =:= 2.

exprs_two_indices_reducible1([],_,_,_,[]).
exprs_two_indices_reducible1([equ(_,IS,OC)|Equ],Pred,I,IS,Pos) :-
	expr_two_indices_reducible(OC,Pred,I,IS,Pos1),
	exprs_two_indices_reducible1(Equ,Pred,I,IS,Pos2),
	union(Pos1,Pos2,Pos).

expr_two_indices_reducible(expr(T,_),Pred,I,ISize,Pos) :-
	term_two_indices_reducible(T,Pred,I,ISize,0,Pos),
	length(Pos,Len), Len =< 2.

term_two_indices_reducible([],_,_,_,0,_) :- fail.
term_two_indices_reducible([],_,_,_,Flag,[]) :- Flag > 0.
term_two_indices_reducible([term(P,_)|T],Pred,I,ISize,Flag,Pos) :-
	primary_two_indices_reducible(P,Pred,I,ISize,Flag1,Pos1),
	Flag2 is Flag1+Flag,
	term_two_indices_reducible(T,Pred,I,ISize,Flag2,Pos2),
	union(Pos1,Pos2,Pos).

primary_two_indices_reducible([P],F/A,I,ISize,1,Pos) :- % direct recursion
	userfunc(P), functor(P,F,N), arg(1,P,Arity),
	normal_form(A,Arity), arg(2,P,Index),
	normal_form(I,Index),
	two_arg_diff(3,N,P,ISize,0,Count,[],Pos), Count > 0. 
primary_two_indices_reducible([P],F/_,_,_,0,[]) :-	% indirect recursion
	userfunc(P), functor(P,F1,_), F1 \== F.
primary_two_indices_reducible([P],F/A,_,_,0,[]) :-	% indirect recursion
	userfunc(P), functor(P,F,_), arg(1,P,Arity),
	general_form(Arity,GArity), GArity \== A.
primary_two_indices_reducible([P],F/A,I,ISize,1,Pos) :- % direct recursion
	P = sum(_,_,_,Expr),
	Expr = expr([term([P1],_)],_),
	userfunc(P1), functor(P1,F,N), arg(1,P1,Arity),
	normal_form(A,Arity), arg(2,P1,OPos),
	normal_form(I,OPos),
	two_arg_diff(3,N,P1,ISize,0,Count,[],Pos), Count > 0.

%
%  Test if the number of different arguments is at most 2.
%
two_arg_diff(M,N,_,[],Count,Count,Pos,Pos) :- M > N, Count =< 2.
two_arg_diff(M,N,F,[S|ISize],Count,FCount,Pos,FPos) :- M =< N,
	arg(M,F,Arg), normal_form(S,Arg),!,
	M1 is M+1,
	two_arg_diff(M1,N,F,ISize,Count,FCount,Pos,FPos).
two_arg_diff(M,N,F,[S|ISize],0,Count,Pos,FPos) :- M =< N,
	arg(M,F,Arg), normal_form(S,S1),
	S1 \== Arg, variable(S),
	M1 is M+1,
	two_arg_diff(M1,N,F,ISize,1,Count,[M|Pos],FPos).
two_arg_diff(M,N,F,[S|ISize],1,Count,Pos,FPos) :- M =< N,
	arg(M,F,Arg), normal_form(S,S1),
	S1 \== Arg, variable(S),
	M1 is M+1,
	two_arg_diff(M1,N,F,ISize,2,Count,[M|Pos],FPos).

adjust_pos([Pos1,Pos2],[Pos1,Pos2]) :- Pos1 < Pos2, !.
adjust_pos([Pos1,Pos2],[Pos2,Pos1]).

reduce_two_indices_exprs(Equ,Pred,I,IS,Pos,NEqu) :-
	Pos = [Pos1,Pos2],
	POS1 is Pos1-2,
	POS2 is Pos2-2,
	ith_list_cas_element(POS1,IS,Var1),
	ith_list_cas_element(POS2,IS,Var2),
	reduce_two_indices_exprs(Equ,Pred,I,Var1,Var2,Pos,NEqu).

reduce_two_indices_exprs([],_,_,_,_,_,[]).
reduce_two_indices_exprs([equ(Num,_,OC)|Equ],Pred,I,Var1,Var2,Pos,
		[equ(Num,[Var1,Var2],ROC)|OCs]) :-
	reduce_two_indices_expr(OC,Pred,I,Pos,ROC),
	reduce_two_indices_exprs(Equ,Pred,I,Var1,Var2,Pos,OCs).

reduce_two_indices_expr(expr(T,F),Pred,I,Pos,expr(ROC,F)) :-
	reduce_two_indices_term(T,Pred,I,Pos,ROC).

reduce_two_indices_term([],_,_,_,[]).
reduce_two_indices_term([term(P,F)|T],Pred,I,Pos,[term(NP,F)|NT]) :-
	reduce_two_indices_primary(P,Pred,I,Pos,NP),
	reduce_two_indices_term(T,Pred,I,Pos,NT).

reduce_two_indices_primary([P],F/A,I,Pos,[R]) :- % direct recursion
	userfunc(P), functor(P,F,_), arg(1,P,Arity),
	normal_form(A,Arity),
	arg(2,P,Index),
	normal_form(I,Index),
	Pos = [Pos1,Pos2], functor(R,F,2), 
	arg(Pos1,P,Arg1), arg(1,R,Arg1),
	arg(Pos2,P,Arg2), arg(2,R,Arg2).
reduce_two_indices_primary([P],F/_,_,_,[P]) :-	% indirect recursion
	userfunc(P), functor(P,F1,_),
	F1 \== F.
reduce_two_indices_primary([P],F/A,_,_,[P]) :-	% indirect recursion
	userfunc(P), functor(P,F,_), arg(1,P,Arity),
	general_form(Arity,GArity),
	GArity \== A.
	

	
reduce_two_indices_primary([P],F/A,I,Pos,[R]) :- % direct recursion
	P = sum(Index,Lower,Upper,Expr),
	Expr = expr([term([P1],FS)],CS),
	userfunc(P1), functor(P1,F,_), arg(1,P1,Arity),
	normal_form(A,Arity),
	arg(2,P1,OPos),
	normal_form(I,OPos),
	Pos = [Pos1,Pos2], functor(R1,F,2), 
	arg(Pos1,P1,Arg1),arg(1,R1,Arg1),
	arg(Pos2,P1,Arg2), arg(2,R1,Arg2),
	RExpr = expr([term([R1],FS)],CS),
	R = sum(Index,Lower,Upper,RExpr).

%
%  Test if boundary conditions are one index reducible. If it is,
%  the reduced conditions are returned.
%

boundary_condition_one_index_reducible([],_,_,[]).
/*boundary_condition_one_index_reducible([equ(N,S,C)|Equ],IS,Pos,
		[equ(N,I,C)|RBC]) :-
	bc_one_index_reducible(S,IS,Pos,1),
	ith_list_cas_element(Pos,S,I),
	boundary_condition_one_index_reducible(Equ,IS,Pos,RBC).
*/


boundary_condition_one_index_reducible(L,IS,Pos,RBE):-

(L==[] ->
   (RBE=[]);
	(L=[equ(N,S,C)|Equ] ->
	    (
		bc_one_index_reducible(S,IS,Pos,1),
		ith_list_cas_element(Pos,S,I),RBE=[equ(N,I,C)|RBC],
		boundary_condition_one_index_reducible(Equ,IS,Pos,RBC)
	    )
	)
).




bc_one_index_reducible([],[],_,_).
bc_one_index_reducible([S|S1],[S|S2],Pos,I) :-
	Pos \== I, I1 is I+1,
	bc_one_index_reducible(S1,S2,Pos,I1).
bc_one_index_reducible([_|S1],[_|S2],Pos,Pos) :-
	I1 is Pos+1,
	bc_one_index_reducible(S1,S2,Pos,I1).

boundary_condition_two_indices_reducible([],_,_,[]).
boundary_condition_two_indices_reducible([equ(N,S,C)|Equ],IS,Pos,
		[equ(N,[I1,I2],C)|RBC]) :-
	bc_two_indices_reducible(S,IS,Pos,1),
	Pos = [Pos1,Pos2],
	ith_list_cas_element(Pos1,S,I1),
	ith_list_cas_element(Pos2,S,I2),
	boundary_condition_two_indices_reducible(Equ,IS,Pos,RBC).

bc_two_indices_reducible([],[],_,_).
bc_two_indices_reducible([H1|S1],[H2|S2],Pos,I) :-
	(member_cas(Pos,I) ->
		true;
		H1 == H2),
	I1 is I+1,
	bc_two_indices_reducible(S1,S2,Pos,I1).

boundary_conds([],[]).
boundary_conds([equ(_,Index,Ival)|Equ],[val(NIndex,Ival)|Ivalue]) :-
	normal_form(Index,NIndex),
	boundary_conds(Equ,Ivalue).

%
%  Compute the boundary condition for a size difference equation.
%  Main task is to estimate the minimum unifiable input term size.
%
size_boundary_cond(equ(Num,Var,Val),ST,Pred,Pos,[val(Iind,Ival)]) :-
	min_unifiable_term_size(ST,Pred,Num,Pos,MinSize),
%write('\nMinsize='),write(MinSize),
	(integer(MinSize) ->
		(normal_form(MinSize,Iind),
		 general_form(Val,Nval),
		 substitute(Nval,Var,MinSize,Sval),
		 normal_form(Sval,Ival));
		(Iind = bot,
		 Ival = bot)).

%
%  Find out the minimum unifiable size of a term in clause CNum at position Pos.
%
min_unifiable_term_size(ST,Pred,CNum,Pos,MinSize) :-
	find_symbol_field_measure(ST,Pred,measure,Measure),
	find_symbol_field(ST,Pred,(mode),Mode),
	real_pos(Mode,Pos,1,RealPos),
	ith_list_cas_element(RealPos,Measure,M),
	find_symbol_field_clause(ST,Pred,clause,Clauses),
	ith_list_cas_element(CNum,Clauses,Clause),
	min_unifiable_term_size1(M,Clause,RealPos,MinSize).

%
real_pos([+|_],1,Pos,Pos).
real_pos([+|Mode],PrincipalPos,I,Pos) :-
	PrincipalPos > 1,
	PrincipalPos1 is PrincipalPos-1,
	I1 is I+1,
	real_pos(Mode,PrincipalPos1,I1,Pos).
real_pos([-|Mode],PrincipalPos,I,Pos) :-
	I1 is I+1,
	real_pos(Mode,PrincipalPos,I1,Pos).

%

/*
min_unifiable_term_size1(int,Clause,PrincipalPos,Size) :-
	clause_type(Clause,Type),
	(Type =:= 2 ->
		arg(1,Clause,Head);
		Head = Clause),
	arg(PrincipalPos,Head,Term),
	(var(Term) ->
		(Type =:= 2 ->
			(arg(2,Clause,Body),
			 min_unifiable_int(Body,Term,Size));
			Size = 0);	% may unify with any integer
		Size = bot).

min_unifiable_term_size1(length,Clause,Pos,Size) :-
	clause_type(Clause,Type),
	(Type =:= 2 ->
		arg(1,Clause,Head);
		Head = Clause),
	arg(Pos,Head,Term),
	min_length(Term,Size).

min_unifiable_term_size1(depth(R),Clause,PrinciplePos,Size) :-
	clause_type(Clause,Type),
	(Type =:= 2 ->
		arg(1,Clause,Head);
		Head = Clause),
	arg(PrinciplePos,Head,Term),
	min_depth(Term,R,Size).

min_unifiable_term_size1(size,Clause,PrinciplePos,Size) :-
	clause_type(Clause,Type),
	(Type =:= 2 ->
		arg(1,Clause,Head);
		Head = Clause),
	arg(PrinciplePos,Head,Term),
	min_size(Term,Size).

*/

min_unifiable_term_size1(T,Clause,PrinciplePos,Size) :-
	clause_type(Clause,Type),
	(Type =:= 2 ->
	    arg(1,Clause,Head);
	    Head = Clause),
	    arg(PrinciplePos,Head,Term),
	    (T==int ->
		(
		    (var(Term) ->
			(Type =:= 2 ->
			    (arg(2,Clause,Body),
			    min_unifiable_int(Body,Term,Size));
			    Size = 0);	% may unify with any integer
			    Size = bot)
			);
			(T==length ->
			    (min_length(Term,Size));
				(T==deph(R) ->
				    (min_depth(Term,R,Size));
					(T==size ->
					    (min_size(Term,Size))
					)
				    )
				)
			    ).

/*
min_unifiable_int(Lit,Var,Size) :-
	nonsequence(Lit),
	functor(Lit,F,N),
	(comparison_op(F/N) ->
		min_lit_int(Lit,Var,Size);
		Size = 0).
min_unifiable_int((Lit,Body),Var,Size) :-
	functor(Lit,F,N),
	(comparison_op(F/N) ->
		min_lit_int(Lit,Var,S);
		S = 0),
	min_unifiable_int(Body,Var,Sizes),
	maximum(S,Sizes,Size).
*/

min_unifiable_int(L,Var,Size) :-
	(L=(Lit,Body) ->
	    (functor(Lit,F,N),
	    (comparison_op(F/N) ->
		min_lit_int(Lit,Var,S);
		S = 0),
		min_unifiable_int(Body,Var,Sizes),
		maximum(S,Sizes,Size)
	    );
	    (L=Lit ->
		(nonsequence(Lit) ->
		    (functor(Lit,F,N),
		    (
			comparison_op(F/N) ->
			min_lit_int(Lit,Var,Size);
			Size = 0)
		    )
		)
	    )
	).



min_lit_int(Lit,Var,Size) :-
	arg(1,Lit,Arg1),
	Arg1 == Var,!,
	arg(2,Lit,Arg2),
	(integer(Arg2) ->
		(functor(Lit,F,_),
		 min_lit_int1(F,Arg2,Size));
		Size = 0).
min_lit_int(Lit,Var,Size) :-
	arg(2,Lit,Arg2),
	Arg2 == Var,!,
	arg(1,Lit,Arg1),
	(integer(Arg1) ->
		(functor(Lit,F,_),
		 min_lit_int2(F,Arg1,Size));
		Size = 0).
min_lit_int(_,_,0).

min_lit_int1((=:=),N,N).
min_lit_int1((==),N,N).
min_lit_int1((>=),N,N).
min_lit_int1((>),N,M) :- M is N+1.
min_lit_int1((=<),_,0).
min_lit_int1((<),_,0).
min_lit_int1((=\=),_,0).
min_lit_int1((\==),_,0).

min_lit_int2((=:=),N,N).
min_lit_int2((==),N,N).
min_lit_int2((>=),_,0).
min_lit_int2((>),_,0).
min_lit_int2((=<),N,N).
min_lit_int2((<),N,M) :- M is N+1.
min_lit_int2((=\=),_,0).
min_lit_int2((\==),_,0).


min_length(Term,0) :- var(Term).
min_length(Term,Size) :- nonvar(Term), Term = [_|L],
	min_length(L,S), Size is S+1.



min_depth(Term,_,0) :- var(Term).
min_depth(Term,R,Size) :- compound_cas(Term), 
	functor(Term,_,N), 
	min_depth1(N,Term,R,S), Size is S+1.

min_depth1(0,_,_,0).
min_depth1(N,Term,R,Size) :- N > 0,
	(member_cas(R,N) ->
		(arg(N,Term,Arg),
		 min_depth(Arg,R,S));
		S = 0),
	N1 is N-1,
	min_depth1(N1,Term,R,Ss),
	max(S,Ss,Size).



min_size(Term,1) :- var(Term).
min_size(Term,Size) :- compound_cas(Term), 
	functor(Term,_,N), 
	min_size1(N,Term,S), Size is S+1.

min_size1(0,_,0).
min_size1(N,Term,Size) :- N > 0,
	arg(N,Term,Arg),
	min_size(Arg,S),
	N1 is N-1,
	min_size1(N1,Term,Ss),
	add(S,Ss,Size).

%
%  Solve the complexity non-difference equations.
%
solve_comp_non_diff_equs(Equ,Sol) :-
	comp_list_cas(Equ,Comp),
	maximum_list_cas(Comp,Sol).

comp_list_cas([],[]).
comp_list_cas([equ(_,_,C)|Equ],[C|Comp]) :-
	comp_list_cas(Equ,Comp).

%
%  Compute the maximum of a list_cas of normal form expressions.
%
maximum_list_cas([],Zero) :- normal_form(0,Zero).
maximum_list_cas([S|Size],Sol) :-
	maximum_list_cas(Size,Sols),
	%general_form(Sols,GSol),
	%write(GSol),nl,
	max_expr(Sols,S,Sol).

%
%  Fetch the input sizes for the clauses of a predicate.
%
input_sizes([],_,[]).
input_sizes([S|Size],Mode,[IS|ISize]) :-
	input_size(Mode,S,IS),
	input_sizes(Size,Mode,ISize).

%
%  Fetch the input sizes for a clause.
%
input_size([],_,[]).
input_size([(+)|Mode],[S|Size],[S|ISize]) :-
	input_size(Mode,Size,ISize).
%write('\nIsize(+)='),write(ISize).
input_size([(-)|Mode],[_|Size],ISize) :-
	input_size(Mode,Size,ISize).
%write('\nIsize(-)='),write(ISize).

%
%  Fetch the nth output sizes for the clauses of a predicate.
%
output_sizes([],_,[]).
output_sizes([S|Size],N,[O|OSize]) :-
	ith_list_cas_element(N,S,O),
	output_sizes(Size,N,OSize).

%
%  Check if the input sizes of the clauses of a predicate is consistant.
%  recursive and nonrecursive predicates are considered differently.
%
consistent_input_sizes(Pred,ST,Component,ISize,Size) :-
	(recursive_predicate(Pred,ST,Component) ->
		(find_symbol_field_clause(ST,Pred,clause,Clause),
		 recursive_consistent_input(Clause,Component,ISize,0,Size));
		nonrecursive_consistent_input(ISize,0,Size)).
	
%
%  If the predicate is recursive, the input sizes of recursive clauses must
%  be the same.
%
%Size represente les tailles des entrés qui sont exactement les memes
recursive_consistent_input(Clauses,_,_,_,_) :- var(Clauses).
/*
recursive_consistent_input(Clauses,Component,[IS|ISize],0,Size) :-
	nonvar(Clauses),
	Clauses = [C|Clause],
	(recursive_clause(C,Component) ->
		(Size = IS,
		 recursive_consistent_input(Clause,Component,ISize,1,Size));
		recursive_consistent_input(Clause,Component,ISize,0,Size)).
recursive_consistent_input(Clauses,Component,[IS|ISize],1,Size) :-

	nonvar(Clauses),
	Clauses = [C|Clause],
	(recursive_clause(C,Component) ->
		(Size == IS,
		 recursive_consistent_input(Clause,Component,ISize,1,Size));
		recursive_consistent_input(Clause,Component,ISize,1,Size)).
*/

recursive_consistent_input(Clauses,Component,[IS|ISize],I,Size) :-
	nonvar(Clauses),
	Clauses = [C|Clause],
	(
	    recursive_clause(C,Component) ->
	    (
		Size = IS, recursive_consistent_input(Clause,Component,ISize,1,Size)
	    );
	    (
		(I==0 -> ( recursive_consistent_input(Clause,Component,ISize,0,Size));
		    (I==1 ->(recursive_consistent_input(Clause,Component,ISize,1,Size))))
	    )
	).




%
%  If the predicate is nonrecursive, the input sizes for all the clauses
%  must be the same.
%
nonrecursive_consistent_input([],_,_).

nonrecursive_consistent_input([IS|ISize],0,Size) :-
	Size = IS,
	nonrecursive_consistent_input(ISize,1,Size).
nonrecursive_consistent_input([IS|ISize],1,Size) :-
	Size == IS,
	nonrecursive_consistent_input(ISize,1,Size).

/*

nonrecursive_consistent_input([IS|ISize],I,Size) :-
	Size == IS,
	nonrecursive_consistent_input(ISize,1,Size).

*/


%
%  Construct the complexity equations.
%
construct_comp_equs([],_,_,[]).
construct_comp_equs([I|ISize],[C|Comp],ClauseNum,[equ(ClauseNum,I,NC)|Equs]) :-
	normal_form(C,NC),
	ClauseNum1 is ClauseNum+1,
	construct_comp_equs(ISize,Comp,ClauseNum1,Equs).

classify_equs([],[],[]).
classify_equs([E|Equs],DEqu,BEqu) :-
	E = equ(_,_,O),
	%general_form(O,GO),

	(diff_equ(O) ->
		(DEqu = [E|DEqus],
		 BEqu = BEqus);
		(DEqu = DEqus,
		 BEqu = [E|BEqus])),
	classify_equs(Equs,DEqus,BEqus).
%
%  Combine the input sizes and output sizes.
%
combine_size([],_,_,[]).
combine_size([+|Mode],[I|Isize],Osize,[S|Size]) :-
	simplification(I,S),
	combine_size(Mode,Isize,Osize,Size).
combine_size([-|Mode],Isize,[O|Osize],[S|Size]) :-
	simplification(O,S),
	combine_size(Mode,Isize,Osize,Size).

%
%  Construct a list_cas of dummy sizes.
%
dummy_size([],_,[]).
dummy_size([+|Mode],I,[($(0,I))|Size]) :-
	I1 is I+1,
	dummy_size(Mode,I1,Size).
dummy_size([-|Mode],I,[inf|Size]) :-
	I1 is I+1,
	dummy_size(Mode,I1,Size).

%
%  Test if an equation is a difference equation or not.
%
diff_equ(expr(T,_)) :-
	T \== [].

non_diff_equ(expr([],_)).
%non_diff_equ(bot).
non_diff_equ(inf).

%
indirect_recursion([],_).
indirect_recursion([equ(_,_,E)|DE],Pred) :-
	%general_form(E,GE),
	%write(GE),nl,
	indirect_recursion_expr(E,Pred),
	indirect_recursion(DE,Pred).

indirect_recursion_expr(expr(T,_),Pred) :-
	indirect_recursion_term(T,Pred).

indirect_recursion_term([],_).
indirect_recursion_term([term(P,_)|Ts],Pred) :-
	indirect_recursion_primary(P,Pred),
	indirect_recursion_term(Ts,Pred).

indirect_recursion_primary([],_).
indirect_recursion_primary([DVar|P],F/N) :-
	userfunc(DVar),
	functor(DVar,F1,_), F1 \== F, !,
	indirect_recursion_primary(P,F/N).
indirect_recursion_primary([DVar|P],F/N) :-
	userfunc(DVar),
	functor(DVar,F,M), M > 2,
	arg(1,DVar,Arity), general_form(Arity,A), A \== N,
	indirect_recursion_primary(P,F/N).
