%
%  Solve a mutual linear first-order difference equation with coeff 1.
%
solve_msde(Var,Ivalue,An,Bn,Sol) :-
%write('\n****************************'),
%write('\nIvalue='),write(Ivalue),
%write('\nAn='),write(An),
%write('\nBn='),write(Bn),
%write('\n****************************'),
	normal_form(0,Zero),
	Ivalue = [val(Zero,_)],!,
	normal_form(1,A),
	solve_fovde(Var,Ivalue,A,Bn,Sol1),
	substitute(An,Var,$(i),AN),
	normal_form(Var,Upper),
	sum_expr($(i),A,Upper,AN,Sol2),
	add_expr(Sol1,Sol2,Sol).
solve_msde(_,_,_,_,inf).

%
%  Test if a difference equation, obtained from an auxiliary predicate
%  based on measure term-size and builtins functor/3 and arg/3, is 
%  linear first-order with coefficient 1. That is,
%  f(n) = f(n-1) + g(arg(x,n)).
%
mutual_size_diff_equ(Equ,Var,Pred,A,_,B) :-
	  Equ = expr(Terms,Bn),
	primary_term(Terms,Pred,Var,MTerm),
	mutual_size_solvable(Bn,Var),
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
	I =:= -1.
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
