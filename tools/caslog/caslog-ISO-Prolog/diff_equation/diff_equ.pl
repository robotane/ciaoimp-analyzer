%
%  diff_equ.pl			Nai-Wei Lin			February, 1992
%
%  This file contains the procedures for solving linear difference equations.
%
%  To solve diff equation with purrs, we put them in a file, 
% and we use a sh-shell (calcul_purrs) to interface with purrs

%To make a list of variable for initial condition

construct_var([],_).
construct_var([L|Ls],VarFile):-
L=equ(_,V,_),
open(VarFile,append,F1,[]),
write_term(F1,V,[]),write_term(F1,'|',[]),
close(F1),
construct_var(Ls,VarFile).

%To make a list of result for initial condition

construct_init([],_).
construct_init([L|Ls],InitFile):-
L=equ(_,_,E),general_form(E,EG),
open(InitFile,append,F2,[]),
write_term(F2,EG,[]),write_term(F2,'|',[]),
close(F2),
construct_init(Ls,InitFile).


solve_typed_diff_equ(size,DE,BE,Var,ST,Pred,Pos,Sol) :-
general_form(DE,DG),
Pred=P/_,
	open(sizefunction,append,Sz,[]),write_term(Sz,P,[]),
	write_term(Sz,'\n',[]),write_term(Sz,Var,[]),write_term(Sz,'\n',[]),
	write_term(Sz,DG,[]),
	write_term(Sz,'\n',[]),
	close(Sz),
	construct_var(BE,sizefunction),
	open(sizefunction,append,F,[]),write_term(F,'\n',[]),close(F),
	construct_init(BE,sizefunction),
	open(sizefunction,append,F0,[]),write_term(F0,'\n',[]),close(F0),


	(product_diff_equ(DE,Pred,NDE) ->
		(diff_equ_type(NDE,Var,Pred,A1n,A2n,Bn,Dtype),
		 log_base_equs(BE,NBE),
		 solve_one_index_size_diff_equ(Dtype,NBE,Var,A1n,A2n,Bn,
			ST,Pred,Pos,Sol1),
		 exp_solution(Sol1,Sol));
		(diff_equ_type(DE,Var,Pred,A1n,A2n,Bn,Dtype),
		 solve_one_index_size_diff_equ(Dtype,BE,Var,A1n,A2n,Bn,
			ST,Pred,Pos,Sol))).


solve_typed_diff_equ(comp,DE,BE,Var,ST,Pred,Pos,Sol) :-
find_symbol_field_det(ST,Pred,det,S),
general_form(DE,DG),/*BE=[equ(A,V,E)|_], general_form(E,EG),*/
Pred=P/_,
% write('\nVar='),write(Var),write('\nDEc='),write(DE),write('\nBEc='),write(BE),
(var(S) -> 
    (    
	open(solution,append,Sz,[]),write_term(Sz,P,[]),write_term(Sz,'\n',[]),
	write_term(Sz,Var,[]),write_term(Sz,'\n',[]),
	write_term(Sz,DG,[]),
	write_term(Sz,'\n',[]),
	close(Sz),
	construct_var(BE,solution),
	open(solution,append,F,[]),write_term(F,'\n',[]),close(F),
	construct_init(BE,solution),
	open(solution,append,F0,[]),write_term(F0,'\n',[]),close(F0)

);
	(
	open(time,append,Sz,[]),write_term(Sz,P,[]),
	write_term(Sz,'\n',[]),write_term(Sz,Var,[]),write_term(Sz,'\n',[]),
	write_term(Sz,DG,[]),
	write_term(Sz,'\n',[]),
	close(Sz),
	construct_var(BE,time),
	open(time,append,F,[]),write_term(F,'\n',[]),close(F),
	construct_init(BE,time),
	open(time,append,F0,[]),write_term(F0,'\n',[]),close(F0)
)
),


	( product_diff_equ(DE,Pred,NDE) ->
	    (
%write('\nNDEc='),write(NDE),
		    diff_equ_type(NDE,Var,Pred,A1n,A2n,Bn,Dtype),
		    log_base_equs(BE,NBE),
		    solve_one_index_comp_diff_equ(Dtype,NBE,Var,A1n,A2n,Bn,
		    ST,Pred,Pos,Sol1),
		    exp_solution(Sol1,Sol));
		    (
%write('\nNDEc='),write(NDE),
			diff_equ_type(DE,Var,Pred,A1n,A2n,Bn,Dtype),
				
		%	write('\nDType0='),write(Dtype),
		%	write('\nVar0='),write(Var),write('\nA1n='),write(A1n),write('\nA2n='),write(A2n),write('\n---Bn='),write(Bn),

			solve_one_index_comp_diff_equ(Dtype,BE,Var,A1n,A2n,Bn,
			ST,Pred,Pos,Sol)
		    )
		).

/*
solve_typed_diff_equ(Type,DE,BE,Var,ST,Pred,Pos,Sol) :-
	(Type==size ->
	    (product_diff_equ(DE,Pred,NDE) ->
		(diff_equ_type(NDE,Var,Pred,A1n,A2n,Bn,Dtype),
		 log_base_equs(BE,NBE),
		 solve_one_index_size_diff_equ(Dtype,NBE,Var,A1n,A2n,Bn,
			ST,Pred,Pos,Sol1),
		 exp_solution(Sol1,Sol));
		(diff_equ_type(DE,Var,Pred,A1n,A2n,Bn,Dtype),
		 solve_one_index_size_diff_equ(Dtype,BE,Var,A1n,A2n,Bn,
			ST,Pred,Pos,Sol)));
			(Type==comp ->
			    (product_diff_equ(DE,Pred,NDE) ->
				(diff_equ_type(NDE,Var,Pred,A1n,A2n,Bn,Dtype),
				log_base_equs(BE,NBE),
				solve_one_index_comp_diff_equ(Dtype,NBE,Var,A1n,A2n,Bn,
				ST,Pred,Pos,Sol1),
				exp_solution(Sol1,Sol));
				(diff_equ_type(DE,Var,Pred,A1n,A2n,Bn,Dtype),
				(Dtype,BE,Var,A1n,A2n,Bn,
				ST,Pred,Pos,Sol)))
			    )
			).


*/

%
%  Determine the type of a difference equation.
%

/*
diff_equ_type(Equ,Var,Pred,A1n,A2n,Bn,first_order) :-
	first_order_diff_equ(Equ,Var,Pred,A1n,A2n,Bn),!.
diff_equ_type(Equ,Var,Pred,A1n,A2n,Bn,second_order) :-
	second_order_diff_equ(Equ,Var,Pred,A1n,A2n,Bn),!.
diff_equ_type(Equ,Var,Pred,A1n,A2n,Bn,higher_order) :-
	higher_order_diff_equ(Equ,Var,Pred,A1n,A2n,Bn),!.
diff_equ_type(Equ,Var,Pred,A1n,A2n,Bn,divide_conquer) :-
	divide_conquer_diff_equ(Equ,Var,Pred,A1n,A2n,Bn),!.
diff_equ_type(Equ,Var,Pred,A1n,A2n,Bn,mutual_size) :-
	mutual_size_diff_equ(Equ,Var,Pred,A1n,A2n,Bn),!.
diff_equ_type(Equ,Var,Pred,A1n,A2n,Bn,implicit_size) :-
	implicit_size_diff_equ(Equ,Var,Pred,A1n,A2n,Bn),!.
diff_equ_type(Equ,Var,Pred,A1n,A2n,Bn,explicit_size) :-
	explicit_size_diff_equ(Equ,Var,Pred,A1n,A2n,Bn),!.
diff_equ_type(Equ,Var,Pred,A1n,A2n,Bn,list_cas_size) :-
	list_cas_size_diff_equ(Equ,Var,Pred,A1n,A2n,Bn),!.
diff_equ_type(_,_,_,_,_,_,no_match).
*/

diff_equ_type(Equ,Var,Pred,A1n,A2n,Bn,Type) :-
(first_order_diff_equ(Equ,Var,Pred,A1n,A2n,Bn) ->
    (Type=first_order);
	(second_order_diff_equ(Equ,Var,Pred,A1n,A2n,Bn) ->
	    (Type=second_order);
		(higher_order_diff_equ(Equ,Var,Pred,A1n,A2n,Bn) ->
		    (Type=higher_order);
			(divide_conquer_diff_equ(Equ,Var,Pred,A1n,A2n,Bn) ->
			    (Type=divide_conquer);
				(mutual_size_diff_equ(Equ,Var,Pred,A1n,A2n,Bn) ->
				    (Type=mutual_size);
					(implicit_size_diff_equ(Equ,Var,Pred,A1n,A2n,Bn) ->
					    (Type=implicit_size);
						(explicit_size_diff_equ(Equ,Var,Pred,A1n,A2n,Bn) ->
						    (Type=explicit_size);
							(list_cas_size_diff_equ(Equ,Var,Pred,A1n,A2n,Bn) ->
							    (Type=list_cas_size)
							)
						    )
						)
					    )
					)
				  )
				)
			    ).
diff_equ_type(_,_,_,_,_,_,no_match).



%
%  Solve a difference equation.
%
/*
solve_diff_equ(first_order,Var,An,_,Bn,Ivalue,Sol) :-
	solve_fode(Var,Ivalue,An,Bn,Sol).
solve_diff_equ(second_order,Var,A1n,A2n,Bn,Ivalue,Sol) :-
	solve_sode(Var,Ivalue,A1n,A2n,Bn,Sol).
solve_diff_equ(higher_order,Var,A1n,_,Bn,Ivalue,Sol) :-
	solve_hode(Var,Ivalue,A1n,Bn,Sol).
solve_diff_equ(divide-conquer,Var,A1n,A2n,Bn,Ivalue,Sol) :-
	solve_dcde(Var,Ivalue,A1n,A2n,Bn,Sol).
solve_diff_equ(mutual_size,Var,An,_,Bn,Ivalue,Sol) :-
	solve_msde(Var,Ivalue,An,Bn,Sol).
solve_diff_equ(implicit_size,Var,_,_,Bn,Ivalue,Sol) :-
	solve_isde(Var,Ivalue,Bn,Sol).
solve_diff_equ(explicit_size,Var,_,_,Bn,Ivalue,Sol) :-
	solve_esde(Var,Ivalue,Bn,Sol).
solve_diff_equ(list_cas_size,Var,_,_,Bn,Ivalue,Sol) :-
	solve_lsde(Var,Ivalue,Bn,Sol).
solve_diff_equ(no_match,_,_,_,inf).
*/

solve_diff_equ(Type,Var,An,Cn,Bn,Ivalue,Sol) :-
%write('\n\n*******************************************'),write('\nIValue='),write(Ivalue),write('\nVar='),write(Var),write('\nAn='),write(An),write('\nCn='),write(Cn),write('\nBn='),write(Bn),write('\n\n*******************************************'),
(Type==first_order ->
    (solve_fode(Var,Ivalue,An,Bn,Sol));
	(Type==second_order ->
	    (solve_sode(Var,Ivalue,An,Cn,Bn,Sol));
		(Type==higher_order ->
		    (solve_hode(Var,Ivalue,An,Bn,Sol));
			(Type==divide-conquer ->
			    (solve_dcde(Var,Ivalue,An,Cn,Bn,Sol));
				(Type==mutual_size ->
				    (solve_msde(Var,Ivalue,An,Bn,Sol));
					(Type==implicit_size ->
					    (solve_isde(Var,Ivalue,Bn,Sol));
						(Type==explicit_size ->
						    (
%write('\nIValue='),write(Ivalue),write('\nVar='),write(Var),write('\nAn='),write(An),write('\nCn='),write(Cn),write('\nBn='),write(Bn),
							solve_esde(Var,Ivalue,Bn,Sol)
%write('\nSol='),write(Sol)
							);
							(Type==list_cas_size ->
							    (solve_lsde(Var,Ivalue,Bn,Sol))
							)
						    )
						)
					    )
					)
				    )
				)
			    ).

solve_diff_equ(no_match,_,_,_,inf).

			

