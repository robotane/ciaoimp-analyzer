%
%  Solve a mutual linear first-order difference equation with coeff 1.
%
solve_isde(Var,Ivalue,Bn,Sol) :-
	normal_form(0,Zero),
	normal_form(1,One),
	Ivalue = [val(Iindex,Ival)],
	(Iindex == Zero; Iindex == One),
	general_form(Ival,GIval),
	mutual_struct_solvable(Bn,Var,GIval),!,
	solve_isde1(Bn,Var,Sol).
solve_isde(_,_,_,inf).

solve_isde1([],_,Zero) :-
	normal_form(0,Zero).
solve_isde1([B|Bn],Var,Sol) :-
	solve_isde2(B,Var,Sol1),
	solve_isde1(Bn,Var,Sols),
	add_expr(Sol1,Sols,Sol).

solve_isde2(factor([],C),Var,Sol) :-
	normal_form(C*Var,Sol).
solve_isde2(factor([Var],C),Var,Sol) :-
	normal_form((C/2)*Var*(Var+1),Sol).
solve_isde2(factor([arity(E)],C),Var,Sol) :-
	normal_form(Var,E),
	normal_form(C*(Var-1),Sol).

%
%  Test if a mutual size difference equation is linear first-order with coeff 1.
%
implicit_size_diff_equ(Equ,Var,F/_,_,_,Bn) :-
	Equ = expr(Term,Bn),
	NTerm = expr(Term,[]),
	general_form(NTerm,GTerm),
	GTerm = sum(Index,1,arity(Var),Expr),
	functor(Expr,F,1),
	arg(1,Expr,arg(Var,Index)).

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
