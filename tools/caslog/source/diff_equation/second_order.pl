%
%  second_order.pl
%
%    Handle linear second-order difference equations

%
%  Test if a difference equation is linear second-order.
%
second_order_diff_equ(Equ,Var,F/_,A1,A2,Bn) :-	% f(n) = f(n-1)+f(n-2)
	Equ = expr([term([Dvar1],A1),term([Dvar2],A2)],Bn),!,
	userfunc(Dvar1),
	functor(Dvar1,F,1),
	arg(1,Dvar1,Arg1),
	Arg1 = expr([],[factor([Var],1),factor([],I1)]),
	I1 =:= -1,
	userfunc(Dvar2),
	functor(Dvar2,F,1),
	arg(1,Dvar2,Arg2),
	Arg2 = expr([],[factor([Var],1),factor([],I2)]),
	I2 =:= -2.
second_order_diff_equ(Equ,Var,F/_,A1,A2,Bn) :-	% f(n) = f(n-2)
	Equ = expr([term([Dvar2],A2)],Bn),
	userfunc(Dvar2),
	functor(Dvar2,F,1),
	arg(1,Dvar2,Arg2),
	Arg2 = expr([],[factor([Var],1),factor([],I2)]),
	I2 =:= -2,
	A1 = [factor([],0)].

%
%  Test if a difference equation is linear second-order with constant 
%  coefficient.
%
second_order_con_diff_equ(Var,Ivalue,A1,A2,B,R1,R2,A1n,A2n,Bn) :-
	A1 = [factor([],A1n)],
	A2 = [factor([],A2n)],
	real_quadratic_roots(A1n,A2n,R1,R2),
	const_coeff_solvable(B,Var),
	Bn = expr([],B),
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
%  Solve a linear second-order difference equation.
%
solve_sode(Var,Ivalue,A1,A2,B,Sol) :-
	second_order_con_diff_equ(Var,Ivalue,A1,A2,B,R1,R2,A1n,A2n,Bn),!,
	solve_socde(Var,Ivalue,R1,R2,A1n,A2n,Bn,Sol).
solve_sode(_,_,_,_,_,inf).

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
