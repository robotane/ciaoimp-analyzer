%
%  divide_conquer.pl
%
%    Handle difference equations from divide-and-conquer paradigm.
%

%
%  Test if a difference equation is linear divide-and-conquer.
%
divide_conquer_diff_equ(Equ,Var,F/_,A,C,Bn) :-
	Equ = expr([term([Dvar],An)],Bn),
	userfunc(Dvar),
	functor(Dvar,F,1),
	arg(1,Dvar,Arg),
	Arg = expr([],[factor([Var],I)]),
	I < 1,
	C is 1/I,
	An = [factor([],A)],
	divide_conquer_solvable(Bn,Var).

%
%  Solve a linear divide-and-conquer difference equation.
%
solve_dcde(Var,[val(Iindex,Ival)],A,C,Bn,Sol) :-
	normal_form(1,Iindex),!,
	divide_conquer_par_sol(Bn,Var,A,C,PSol),
	normal_form(exp(Var,log(C,A)),E),
	multiply_expr(Ival,E,GSol),
	add_expr(GSol,PSol,Sol).
solve_dcde(_,_,_,_,_,inf).

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
