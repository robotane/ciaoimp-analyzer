%
%  diff_equ.pl			Nai-Wei Lin			February, 1992
%
%  This file contains the procedures for solving linear difference equations.
%

%
%  Solve a difference equation.
%
solve_diff_equ(Equ,Var,_,Ivalue,Sol) :-
	first_order_con_diff_equ(Equ,Var,Ivalue,An,Bn),!,
	solve_focde(Var,Ivalue,An,Bn,Sol).
solve_diff_equ(Equ,Var,_,Ivalue,Sol) :-
	first_order_var_diff_equ(Equ,Var,Ivalue,An,Bn),!,
	solve_fovde(Var,Ivalue,An,Bn,Sol).
solve_diff_equ(Equ,Var,_,Ivalue,Sol) :-
	second_order_con_diff_equ(Equ,Var,Ivalue,R1,R2,A1n,A2n,Bn),!,
	solve_socde(Var,Ivalue,R1,R2,A1n,A2n,Bn,Sol).
solve_diff_equ(Equ,Var,_,Ivalue,Sol) :-
	divide_conquer_diff_equ(Equ,Var,Ivalue,A,C,Bn),!,
	solve_dcde(Var,Ivalue,A,C,Bn,Sol).
solve_diff_equ(Equ,Var,Pred,Ivalue,Sol) :-
	mutual_size_diff_equ(Equ,Var,Pred,Ivalue,An,Bn),!,
	solve_msde(Var,Ivalue,An,Bn,Sol).
solve_diff_equ(Equ,Var,Pred,Ivalue,Sol) :-
%	write('go1'),nl,
	mutual_struct_diff_equ(Equ,Var,Pred,Ivalue,Bn),!,
%	write('go'),nl,
	solve_mstde(Var,Bn,Sol).
solve_diff_equ(Equ,Var,Pred,Ivalue,Sol) :-
%	write('go2'),nl,
	mutual_list_cas_diff_equ(Equ,Var,Pred,Ivalue,Bn),!,
%	write('go'),nl,
	solve_mlsde(Var,Bn,Sol).
solve_diff_equ(_,_,_,_,inf).

%
%  Test if a difference equation is linear first-order.
%  f(n) = a(n) * f(n-1) + b(n).
%
first_order_diff_equ(Equ,Var,An,Bn) :-
	Equ = expr([term([FuncTerm],Coeff)],ConstTerm),
	userfunc(FuncTerm),
	functor(FuncTerm,_,1),
	arg(1,FuncTerm,Arg),
	Arg = expr([],[factor([Var],1),factor([],I)]),
	I =:= -1,
	An = expr([],Coeff),
	Bn = expr([],ConstTerm).

%
%  Solve a linear first-order difference equation.
%
solve_fode(Var,BEqus,An,Bn,Sol) :-
	first_order_boundary_condition(BEqus,BCond),
	(first_order_const_solvable(An,Bn,Var) ->
		solve_focde(Var,BCond,An,Bn,Sol);
		solve_fovde(Var,BCond,An,Bn,Sol)).
	
%
%  Test if a linear first-order difference equation is solvable using
%  constant coefficient solving methods.
%
first_order_const_solvable(An,Bn,Var) :-
	first_order_const_diff_equ(An),
	const_coeff_solvable_terms(Bn,Var).
%
%  Test if a linear first-order difference equation has constant coefficient.
%
first_order_const_diff_equ(An) :-
	An = expr([],Coeff),
	Coeff = [factor([],_)].

%
%  Test if the terms of a linear first-order difference equation 
%  with constant coefficient are solvable by using constant coefficient
%  solving methods.
%
const_coeff_solvable_terms(Bn,Var) :-
	Bn = expr([],Factor),
	const_coeff_solvable_factors(Factor,Var).

%
%  Test if the factors of an equation is solvable using (1-order or 2-order)
%  constant coefficient solving methods. These methods handle several common
%  patterns efficiently.
%
const_coeff_solvable_factors([],_).
const_coeff_solvable_factors([F|Fs],Var) :-
	const_coeff_solvable_factor(F,Var),
	const_coeff_solvable_factors(Fs,Var).

const_coeff_solvable_factor(Factor,Var) :- constant_factor(Factor,Var).
const_coeff_solvable_factor(Factor,Var) :- linear_factor(Factor,Var).
const_coeff_solvable_factor(Factor,Var) :- quadratic_factor(Factor,Var).
const_coeff_solvable_factor(Factor,Var) :- constant_base_exp_factor(Factor,Var).

constant_factor(factor([],_),_).
linear_factor(factor([Var],_),Var).
quadratic_factor(factor([exp(E1,E2)],_),Var) :-
	normal_form(Var,E1),
	normal_form(2,E2).
constant_base_exp_factor(factor([exp(E1,E2)],_),Var) :-
	E1 = expr([],[factor([],_)]),
	normal_form(Var,E2).

%
%  Solve a linear first-order constant coefficient difference equation.
%
solve_focde(Var,Ivalue,A,Bn,Sol) :-
	normal_form(1,A),!,
	solve_fovde(Var,Ivalue,A,Bn,Sol).
solve_focde(Var,Ivalue,A,Bn,Sol) :-
	Bn = expr([],BN),
	first_order_par_sol(BN,Var,A,Sol1),
	first_order_gen_sol(Var,Ivalue,A,Sol1,Sol).

%
%
%
first_order_par_sol([],_,_,Sol) :-
	normal_form(0,Sol).
first_order_par_sol([F|Fs],Var,A,Sol) :-
	first_order_par_sol1(F,Var,A,Sol1),
	first_order_par_sol(Fs,Var,A,Sols),
	add_expr(Sol1,Sols,Sol).

%
%
first_order_par_sol1(factor([],C),_,An,Sol) :-
	general_form(An,A),
	normal_form(C/(1-A),Sol).
first_order_par_sol1(factor([Var],C),Var,An,Sol) :-
	general_form(An,A),
	normal_form((C/(1-A))*Var-(A*C)/exp(1-A,2),Sol).
first_order_par_sol1(factor([exp(E1,E2)],C),Var,An,Sol) :-
	normal_form(Var,E1),
	normal_form(2,E2),
	general_form(An,A),
	normal_form((C/(1-A))*exp(Var,2)-((2*A*C)/exp(1-A,2))*Var+
		(exp(A,2)*C+A*C)/exp(1-A,3),Sol).
first_order_par_sol1(factor([exp(E1,E2)],C),Var,An,Sol) :-
	E1 = expr([],[factor([],D)]),
	normal_form(Var,E2),
	general_form(An,A),
	A =\= D,
	normal_form((C*D/(D-A))*exp(D,Var),Sol).
first_order_par_sol1(factor([exp(E1,E2)],C),Var,An,Sol) :-
	E1 = expr([],[factor([],D)]),
	normal_form(Var,E2),
	general_form(An,A),
	A =:= D,
	normal_form(C*Var*exp(D,Var),Sol).

%
%
first_order_gen_sol(Var,Ivalue,An,PSol,Sol) :-
	Ivalue = [val(Iindex,Ival)],
	general_form(PSol,PSol1),
	general_form(Iindex,Iindex1),
	substitute(PSol1,Var,Iindex1,PSol2),
	normal_form(PSol2,PSol3),
	subtract_expr(Ival,PSol3,N),
	exp_expr(An,Iindex,D),
	divide_expr(N,D,C),
	normal_form(Var,Var1),
	exp_expr(An,Var1,G1),
	multiply_expr(C,G1,G2),
	add_expr(G2,PSol,Sol).

%
%  Solve a linear first-order variable coefficient difference equation.
%
solve_fovde(Var,Ivalue,An,Bn,Sol) :-
	Ivalue = [val(Iindex,Ival)],
	substitute(An,Var,$(i),AN),
	substitute(Bn,Var,$(j),BN),
	normal_form(1,One),
	add_expr(Iindex,One,Lower1),
	normal_form(Var,Upper),
	prod_expr($(i),Lower1,Upper,AN,P1),
	multiply_expr(Ival,P1,S1),
	normal_form(($(j))+1,Lower2),
	prod_expr($(i),Lower2,Upper,AN,P2),
	multiply_expr(BN,P2,P3),
	sum_expr($(j),Lower1,Upper,P3,S2),
	add_expr(S1,S2,Sol).

%
%  Test if a difference equation is linear second-order with constant 
%  coefficient.
%
second_order_con_diff_equ(Equ,Var,Ivalue,R1,R2,A1,A2,Bn) :-
	second_order_diff_equ(Equ,Var,Ivalue,An1,An2,B),
	An1 = [factor([],A1)],
	An2 = [factor([],A2)],
	real_quadratic_roots(A1,A2,R1,R2),
	const_coeff_solvable(B,Var),
	Bn = expr([],B).
	
%
%  Test if a difference equation is linear second-order.
%
second_order_diff_equ(Equ,Var,Ivalue,A1,A2,Bn) :-
	Equ = expr([term([Dvar1],A1),term([Dvar2],A2)],Bn),!,
	userfunc(Dvar1),
	functor(Dvar1,F,1),
	arg(1,Dvar1,Arg1),
	Arg1 = expr([],[factor([Var],1),factor([],I1)]),
	First is -1,
	I1 =:= First,
	userfunc(Dvar2),
	functor(Dvar2,F,1),
	arg(1,Dvar2,Arg2),
	Arg2 = expr([],[factor([Var],1),factor([],I2)]),
	Second is -2,
	I2 =:= Second,
	Ivalue = [val(Iindex1,_),val(Iindex2,_)],
	general_form(Iindex1,Index1),
	integer(Index1),
	general_form(Iindex2,Index2),
	integer(Index2),
	(Index1 > Index2 ->
		D is Index1-Index2;
		D is Index2-Index1),
	D =:= 1.
second_order_diff_equ(Equ,Var,Ivalue,A1,A2,Bn) :-
	Equ = expr([term([Dvar2],A2)],Bn),
	userfunc(Dvar2),
	functor(Dvar2,_,1),
	arg(1,Dvar2,Arg2),
	Arg2 = expr([],[factor([Var],1),factor([],I2)]),
	Second is -2,
	I2 =:= Second,
	A1 = [factor([],0)],
	Ivalue = [val(Iindex1,_),val(Iindex2,_)],
	general_form(Iindex1,Index1),
	integer(Index1),
	general_form(Iindex2,Index2),
	integer(Index2),
	(Index1 > Index2 ->
		D is Index1-Index2;
		D is Index2-Index1),
	D =:= 1.

%
%  Solve a linear second-order constant coefficient difference equation.
%
solve_socde(Var,Ivalue,R1,R2,A1,A2,Bn,GSol) :-
	Bn = expr([],BN),
	second_order_par_sol(BN,Var,R1,R2,A1,A2,PSol),
	second_order_gen_sol(Var,Ivalue,R1,R2,PSol,GSol).

%
%
second_order_par_sol([],_,_,_,_,_,Sol) :-
	normal_form(0,Sol).
second_order_par_sol([F|Fs],Var,R1,R2,A1,A2,Sol) :-
	second_order_par_sol1(F,Var,R1,R2,A1,A2,Sol1),
	second_order_par_sol(Fs,Var,R1,R2,A1,A2,Sols),
	add_expr(Sol1,Sols,Sol).

%
%
second_order_par_sol1(factor([],C),Var,R1,R2,A1,A2,Sol) :-
	unit_count(R1,R2,U),
	(U =:= 0 ->
		normal_form(C/(1-A1-A2),Sol);
		(U =:= 1 ->
			normal_form((C/(A1+2*A2))*Var,Sol);
			normal_form((C/2)*exp(Var,2),Sol))).
second_order_par_sol1(factor([Var],C),Var,R1,R2,A1,A2,Sol) :-
	unit_count(R1,R2,U),
	(U =:= 0 ->
/*
		(normal_form(C/(1-A1-A2),D1),
		 normal_form(-(A1+2*A2)/(1-A1-A2),D2),
		 multiply_expr(D1,D2,D0),
		 normal_form(Var,Var1),
		 multiply_expr(D1,Var1,E1),
		 add_expr(E1,D0,Sol));
*/
		normal_form((C/(1-A1-A2))*Var+
			    (-C*(A1+2*A2)/exp(1-A1-A2,2)),Sol);
		(U =:= 1 ->
			normal_form((C/(2*(A1+2*A2)))*exp(Var,2)+
			     ((C*(A1+4*A2))/(2*exp(A1+2*A2,2)))*Var,Sol);
			normal_form((C/6)*exp(Var,3)+(C/2)*exp(Var,2),Sol))).
second_order_par_sol1(factor([exp(E1,E2)],C),Var,R1,R2,A1,A2,Sol) :-
	normal_form(Var,E1),
	normal_form(2,E2),
	unit_count(R1,R2,U),
	(U =:= 0 ->
		(normal_form(C/(1-A1-A2),D2),
		 normal_form(-2*(A1+2*A2)/(1-A1-A2),TD1),
		 multiply_expr(TD1,D2,D1),
		 normal_form((A1+2*A2)/(1-A1-A2),TD01),
		 multiply_expr(TD01,D1,TD03),
		 normal_form((A1+4*A2)/(1-A1-A2),TD02),
		 multiply_expr(TD02,D2,TD04),
		 subtract_expr(TD04,TD03,D0),
		 normal_form(exp(Var,2),Var2),
		 multiply_expr(D2,Var2,E2),
		 normal_form(Var,Var1),
		 multiply_expr(D1,Var1,E1),
		 add_expr(E2,E1,Sol1),
		 add_expr(Sol1,D0,Sol));
		(U =:= 1 ->
			normal_form((C/(3*(A1+2*A2)))*exp(Var,3)+
			   ((C*(A1+4*A2))/(2*exp(A1+2*A2,2)))*exp(Var,2)+
			   ((C*(A1*A1+4*A1*A2+16*A2*A2))/(6*exp(A1+2*A2,3)))*
				Var,Sol);
			normal_form((C/12)*exp(Var,4)+(C/3)*exp(Var,3)+
			   (5*C/12)*exp(Var,2),Sol))).
second_order_par_sol1(factor([exp(E1,E2)],C),Var,R1,R2,A1,A2,Sol) :-
	E1 = expr([],[factor([],D)]),
	normal_form(Var,E2),
	R1 =\= D,
	R2 =\= D,
	normal_form(((C*exp(D,2))/(exp(D,2)-A1*D-A2))*exp(D,Var),Sol).

%
%
second_order_gen_sol(Var,Ivalue,R1,R2,PSol,GSol) :-
	R1 =\= R2,
	Ivalue = [val(Iindex1,Ival1),val(Iindex2,Ival2)],
	general_form(PSol,GPSol),
	general_form(Iindex1,Index1),
	general_form(Ival1,Val1),
	substitute(GPSol,Var,Index1,GPSol1),
	general_form(Iindex2,Index2),
	general_form(Ival2,Val2),
	substitute(GPSol,Var,Index2,GPSol2),
	N2 = exp(R1,Index1)*(Val2-GPSol2)-exp(R1,Index2)*(Val1-GPSol1),
	D2 = exp(R2,Index2)*exp(R1,Index1)-exp(R2,Index1)*exp(R1,Index2),
	C2 = N2/D2,
	C1 = (Val1-GPSol1-(C2*exp(R2,Index1)))/exp(R1,Index1),
	normal_form(C1*exp(R1,Var)+C2*exp(R2,Var)+GPSol,GSol).
second_order_gen_sol(Var,Ivalue,R1,R2,PSol,GSol) :-
	R1 =:= R2,
	Ivalue = [val(Iindex1,Ival1),val(Iindex2,Ival2)],
	general_form(PSol,GPSol),
	general_form(Iindex1,Index1),
	general_form(Ival1,Val1),
	substitute(GPSol,Var,Index1,GPSol1),
	general_form(Iindex2,Index2),
	general_form(Ival2,Val2),
	substitute(GPSol,Var,Index2,GPSol2),
	N2 = exp(R1,Index1)*(Val2-GPSol2)-exp(R1,Index2)*(Val1-GPSol1),
	D2 = Index2*exp(R2,Index2)*exp(R1,Index1)-
	     Index1*exp(R2,Index1)*exp(R1,Index2),
	C2 = N2/D2,
	C1 = (Val1-GPSol1-(C2*Index1*exp(R2,Index1)))/exp(R1,Index1),
	normal_form(C1*exp(R1,Var)+C2*Var*exp(R2,Var)+GPSol,GSol).

%
%
divide_conquer_diff_equ(Equ,Var,Ivalue,A,C,Bn) :-
	Equ = expr([term([Dvar],An)],Bn),
	userfunc(Dvar),
	functor(Dvar,_,1),
	arg(1,Dvar,Arg),
	Arg = expr([],[factor([Var],I)]),
	I < 1,
	C is 1/I,
	An = [factor([],A)],
	divide_conquer_solvable(Bn,Var),
	Ivalue = [val(Iindex,_)],
	normal_form(1,Iindex).

%
%
solve_dcde(Var,[val(_,Ival)],A,C,Bn,Sol) :-
	divide_conquer_par_sol(Bn,Var,A,C,PSol),
	normal_form(exp(Var,log(C,A)),E),
	multiply_expr(Ival,E,GSol),
	add_expr(GSol,PSol,Sol).

%
%
divide_conquer_par_sol([],_,_,_,Sol) :-
	normal_form(0,Sol).
divide_conquer_par_sol([factor(I,D)|F],Var,A,C,Sol) :-
	divide_conquer_order(I,Var,O),
	simplification(exp(C,O),X),
	divide_conquer_par_sol1(O,X,Var,A,C,Sol1),
	normal_form(D,D1),
	multiply_expr(D1,Sol1,Sol2),
	divide_conquer_par_sol(F,Var,A,C,Sols),
	add_expr(Sol2,Sols,Sol).

%
%
divide_conquer_par_sol1(O,E,Var,A,C,Sol) :-
	A =:= E,
	normal_form(exp(Var,O)*log(C,Var),Sol).
divide_conquer_par_sol1(O,E,Var,A,C,Sol) :-
	A =\= E,
	N = exp(Var,log(C,A))-exp(Var,O),
	D = A-exp(C,O),
	Exp = exp(C,O)*(N/D),
	normal_form(Exp,Sol).

%
%
divide_conquer_order([],_,0).
divide_conquer_order([Var],Var,1).
divide_conquer_order([exp(E1,E2)],Var,I) :-
	normal_form(Var,E1),
	general_form(E2,E),
	I is integer(E).

%
%  Test if the factors of an equation is solvable using (1-order or 2-order)
%  constant coefficient solving methods. These methods handle several common
%  patterns efficiently.
%
const_coeff_solvable_factors([],_).
const_coeff_solvable_factors([F|Fs],Var) :-
	const_coeff_solvable_factor(F,Var),
	const_coeff_solvable_factors(Fs,Var).

const_coeff_solvable_factor(Factor,Var) :- constant_factor(Factor,Var).
const_coeff_solvable_factor(Factor,Var) :- linear_factor(Factor,Var).
const_coeff_solvable_factor(Factor,Var) :- quadratic_factor(Factor,Var).
const_coeff_solvable_factor(Factor,Var) :- constant_base_exp_factor(Factor,Var).

constant_factor(factor([],_),_).
linear_factor(factor([Var],_),Var).
quadratic_factor(factor([exp(E1,E2)],_),Var) :-
	normal_form(Var,E1),
	normal_form(2,E2).
constant_base_exp_factor(factor([exp(E1,E2)],_),Var) :-
	E1 = expr([],[factor([],_)]),
	normal_form(Var,E2).
%
%
exp_only_expr([],_,_,_).
exp_only_expr([factor(I,_)|F],Var,R1,R2) :-
	exp_only_expr1(I,Var,R1,R2),
	exp_only_expr(F,Var,R1,R2).

exp_only_expr1([exp(E1,E2)],Var,R1,R2) :-
	E1 = expr([],[factor([],C)]),
	C =\= R1,
	C =\= R2,
	normal_form(Var,E2).

%
%
real_quadratic_roots(A1,A2,R1,R2) :-
	D is A1*A1+4*A2,
	(D >= 0 ->
		normal_form(exp(D,0.5),ND),
		general_form(ND,D1),
		R1 is (A1+D1)/2,
		R2 is (A1-D1)/2).

%
%
unit_count(R1,R2,I) :-
	unit_count(R1,I1),
	unit_count(R2,I2),
	I is I1+I2.

unit_count(R,1) :-
	R =:= 1.
unit_count(R,0) :-
	R =\= 1.

%
%
divide_conquer_solvable([],_).
divide_conquer_solvable([factor(I,_)|F],Var) :-
	divide_conquer_solvable1(I,Var),
	divide_conquer_solvable(F,Var).

divide_conquer_solvable1([],_).
divide_conquer_solvable1([Var],Var).
divide_conquer_solvable1([exp(E1,E2)],Var) :-
	normal_form(Var,E1),
	general_form(E2,I),
	I1 is integer(I),
	I =:= I1.

%
%  Solve a mutual linear first-order difference equation with coeff 1.
%
solve_msde(Var,Ivalue,An,Bn,Sol) :-
	normal_form(1,A),
	solve_fovde(Var,Ivalue,A,Bn,Sol1),
	substitute(An,Var,$(i),AN),
	normal_form(Var,Upper),
	sum_expr($(i),A,Upper,AN,Sol2),
	add_expr(Sol1,Sol2,Sol).

%
%  Test if a mutual difference equation is linear first-order with coeff 1.
%
mutual_size_diff_equ(Equ,Var,Pred,Ivalue,A,B) :-
	Equ = expr(Terms,Bn),
	primary_term(Terms,Pred,Var,MTerm),
	mutual_size_solvable(Bn,Var),
	normal_form(0,Zero),
	Ivalue = [val(Zero,_)],
	A = expr([MTerm],[]),
	B = expr([],Bn).

%
%
primary_term([T1,T2],Pred,Var,T2) :-
	primary_term(T1,Pred,Var),
	nonprimary_term(T2).
primary_term([T1,T2],Pred,Var,T1) :-
	primary_term(T2,Pred,Var),
	nonprimary_term(T1).

primary_term(term([P],[factor([],1)]),Pred,Var) :-
	userfunc(P),
	functor(P,F,1),
	Pred = F/_,
	arg(1,P,Arg),
	Arg = expr([],[factor([Var],1),factor([],I)]),
	First is -1,
	I =:= First.
nonprimary_term(term([P],[factor([],1)])) :-
	userfunc(P),
	functor(P,_,N),
	N =\= 1.

%
%
mutual_size_solvable([],_).
mutual_size_solvable([factor(I,_)|F],Var) :-
	const_coeff_solvable(I,Var),
	mutual_size_solvable(F,Var).
mutual_size_solvable([factor(I,_)|F],Var) :-
	I = [arg(E1,E2)],
	general_form(E1,Var1),
	variable(Var1),
	normal_form(Var,E2),
	mutual_size_solvable(F,Var).

%
%  Solve a mutual linear first-order difference equation with coeff 1.
%
solve_mstde(Var,Bn,Sol) :-
	solve_mstde1(Bn,Var,Sol).

solve_mstde1([],_,Zero) :-
	normal_form(0,Zero).
solve_mstde1([B|Bn],Var,Sol) :-
	solve_mstde2(B,Var,Sol1),
	solve_mstde1(Bn,Var,Sols),
	add_expr(Sol1,Sols,Sol).

solve_mstde2(factor([],C),Var,Sol) :-
	normal_form(C*Var,Sol).
solve_mstde2(factor([Var],C),Var,Sol) :-
	normal_form((C/2)*Var*(Var+1),Sol).
solve_mstde2(factor([arity(E)],C),Var,Sol) :-
	normal_form(Var,E),
	normal_form(C*(Var-1),Sol).

%
%  Test if a mutual size difference equation is linear first-order with coeff 1.
%
mutual_struct_diff_equ(Equ,Var,F/_,Ivalue,Bn) :-
	Equ = expr(Term,Bn),
	NTerm = expr(Term,[]),
	general_form(NTerm,GTerm),
	GTerm = sum(Index,1,arity(Var),Expr),
	functor(Expr,F,1),
	arg(1,Expr,arg(Var,Index)),
	normal_form(1,One),
	Ivalue = [val(One,Ival)],
	general_form(Ival,GIval),
	mutual_struct_solvable(Bn,Var,GIval).

%
%
mutual_struct_solvable([],_,_).
mutual_struct_solvable([B|Bn],Var,GIval) :-
	mutual_struct_solvable1(B,Var,GIval),
	mutual_struct_solvable(Bn,Var,GIval).

mutual_struct_solvable1(factor([],Val),_,GIval) :-
	Val >= GIval.
mutual_struct_solvable1(factor([Var],Val),Var,GIval) :-
	Val >= GIval.
mutual_struct_solvable1(factor([arity(Expr)],_),Var,_) :-
	normal_form(Var,Expr).

%
%  Solve a mutual linear first-order difference equation with coeff 1.
%
solve_mlsde(Var,[],Sol) :-
	normal_form(Var,Sol).
solve_mlsde(Var,Bn,Sol) :-
	Bn \== [],
	solve_mlsde1(Bn,Var,Sol).

solve_mlsde1([],_,Zero) :-
	normal_form(0,Zero).
solve_mlsde1([B|Bn],Var,Sol) :-
	solve_mlsde2(B,Var,Sol1),
	solve_mlsde1(Bn,Var,Sols),
	add_expr(Sol1,Sols,Sol).

solve_mlsde2(factor([],C),Var,Sol) :-
	normal_form(C*Var,Sol).
solve_mlsde2(factor([Var],C),Var,Sol) :-
	normal_form((C/2)*Var*(Var+1),Sol).
solve_mlsde2(factor([head(E)],C),Var,Sol) :-
	normal_form(Var,E),
	normal_form(C*exp(Var-1,2)/2,Sol).
solve_mlsde2(factor([tail(E)],C),Var,Sol) :-
	normal_form(Var,E),
	normal_form(C*exp(Var-1,2)/2,Sol).

%
%  Test if a mutual size difference equation is linear first-order with coeff 1.
%
mutual_list_cas_diff_equ(Equ,Var,F/_,Ivalue,Bn) :-
	Equ = expr(Term,Bn),
	mutual_list_cas_term(Term,Var,F),
	normal_form(1,One),
	Ivalue = [val(One,Ival)],
	general_form(Ival,GIval),
	mutual_list_cas_solvable(Bn,Var,GIval).

mutual_list_cas_term([Term1,Term2],Var,Pred) :-
	mutual_list_cas_head(Term2,Var,Pred),
	mutual_list_cas_tail(Term1,Var,Pred).

mutual_list_cas_head(term([P],[factor([],1)]),Var,Pred) :-
	userfunc(P),
	functor(P,Pred,1),
	arg(1,P,Arg),
	general_form(Arg,head(Var)).

mutual_list_cas_tail(term([P],[factor([],1)]),Var,Pred) :-
	userfunc(P),
	functor(P,Pred,1),
	arg(1,P,Arg),
	general_form(Arg,tail(Var)).

%
%
mutual_list_cas_solvable([],_,_).
mutual_list_cas_solvable([B|Bn],Var,GIval) :-
	mutual_list_cas_solvable1(B,Var,GIval),
	mutual_list_cas_solvable(Bn,Var,GIval).

mutual_list_cas_solvable1(factor([],Val),_,GIval) :-
	Val >= GIval.
mutual_list_cas_solvable1(factor([Var],Val),Var,GIval) :-
	Val >= GIval.
mutual_list_cas_solvable1(factor([head(Expr)],_),Var,_) :-
	normal_form(Var,Expr).
mutual_list_cas_solvable1(factor([tail(Expr)],_),Var,_) :-
	normal_form(Var,Expr).
