%
%  Test if an equation is solvable using constant coefficient solving method.
%
const_coeff_solvable([],_).
const_coeff_solvable([factor(I,_)|F],Var) :-
	const_coeff_solvable1(I,Var),
	const_coeff_solvable(F,Var).

const_coeff_solvable1([],_).
const_coeff_solvable1([Var],Var).
const_coeff_solvable1([exp(E1,E2)],Var) :-
	normal_form(Var,E1),
	normal_form(2,E2).
const_coeff_solvable1([exp(E1,E2)],Var) :-
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
