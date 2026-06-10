%
%  first_order.pl 
%
%    Handle first-order linear difference equation.
%

%
%  Test if a difference equation is linear first-order.
%
first_order_diff_equ(Equ,Var,F/_,An,_,Bn) :-
	Equ = expr([term([Dvar],An)],Bn),
	userfunc(Dvar),
	functor(Dvar,F,1),
	arg(1,Dvar,Arg),
	Arg = expr([],[factor([Var],1),factor([],I)]),
	I =:= -1.

%
%  Test if a difference equation is linear first-order with constant 
%  coefficient.
%
first_order_con_diff_equ(Var,Ivalue,A,B,An,Bn) :-
	A = [factor([],_)],	% A constant
	An = expr([],A),
	const_coeff_solvable(B,Var),
	Bn = expr([],B),
	Ivalue = [val(Iindex,_)],
	general_form(Iindex,Index),
	integer(Index).
	
%
%  Test if a difference equation is linear first-order with variable 
%  coefficient.
%
first_order_var_diff_equ(_,Ivalue,A,B,An,Bn) :-
	An = expr([],A),
	Bn = expr([],B),
	Ivalue = [val(Iindex,_)],
	general_form(Iindex,Index),
	integer(Index).

%
%  Solve a linear first-order difference equation.
%
solve_fode(Var,Ivalue,A,B,Sol) :-
	first_order_con_diff_equ(Var,Ivalue,A,B,An,Bn),!,
	solve_focde(Var,Ivalue,An,Bn,Sol).
solve_fode(Var,Ivalue,A,B,Sol) :-
	first_order_var_diff_equ(Var,Ivalue,A,B,An,Bn),!,
	solve_fovde(Var,Ivalue,An,Bn,Sol).
solve_fode(_,_,_,_,inf).

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

