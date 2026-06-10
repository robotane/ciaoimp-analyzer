%
%  diff_equ.pl			Nai-Wei Lin			February, 1992
%
%  This file contains the procedures for solving linear difference equations.
%
%  To solve diff equation with purrs, we put them in a file, 
% and we use a sh-shell (calcul_purrs) to interface with purrs

%To make a list of variable for initial condition

solve_typed_diff_equ(size,DE,BE,Var,ST,Pred,Pos,Sol) :-	    
	    (product_diff_equ(DE,Pred,NDE) ->
		(diff_equ_type(NDE,Var,Pred,A1n,A2n,Bn,Dtype),
		log_base_equs(BE,NBE),
		solve_one_index_size_diff_equ(Dtype,NBE,Var,A1n,A2n,Bn,
		ST,Pred,Pos,Sol1),
		exp_solution(Sol1,Sol));
		(diff_equ_type(DE,Var,Pred,A1n,A2n,Bn,Dtype),
		solve_one_index_size_diff_equ(Dtype,BE,Var,A1n,A2n,Bn,ST,Pred,Pos,Sol)
	    )
	).





solve_typed_diff_equ(comp,DE,BE,Var,ST,Pred,Pos,Sol) :-
	( product_diff_equ(DE,Pred,NDE) ->
	    (

		    diff_equ_type(NDE,Var,Pred,A1n,A2n,Bn,Dtype),
		    log_base_equs(BE,NBE),
		    solve_one_index_comp_diff_equ(Dtype,NBE,Var,A1n,A2n,Bn,
		    ST,Pred,Pos,Sol1),
		    exp_solution(Sol1,Sol));
		    (

			diff_equ_type(DE,Var,Pred,A1n,A2n,Bn,Dtype),
				
			solve_one_index_comp_diff_equ(Dtype,BE,Var,A1n,A2n,Bn,
			ST,Pred,Pos,Sol)
		    )
		).



%
%  Determine the type of a difference equation.
%


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



%
%  Solve a difference equation.
%

solve_diff_equ(Type,Var,An,Cn,Bn,Ivalue,Sol) :-
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
							solve_esde(Var,Ivalue,Bn,Sol)

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

			


