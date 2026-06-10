%
%  Test if a difference equation based on measure term-size on a list_cas
%  is linear ``first-order'' with coefficient 1. That is,
%  f(n) = f(head(n)) + f(tail(n)) + g(n), where
%  g(n) is either d, d*n, head(n), or tail(n).
%
list_cas_size_diff_equ(Equ,Var,F/_,_,_,Bn) :-
	Equ = expr(Term,Bn),
	mutual_list_cas_term(Term,Var,F).

mutual_list_cas_term([Term1,Term2],Var,Pred) :-
	mutual_list_cas_head(Term2,Var,Pred),
	mutual_list_cas_tail(Term1,Var,Pred).

mutual_list_cas_head(term([P],[factor([],1)]),Var,Pred) :-
	userfunc(P), functor(P,Pred,1), arg(1,P,Arg),
	general_form(Arg,head(Var)).

mutual_list_cas_tail(term([P],[factor([],1)]),Var,Pred) :-
	userfunc(P), functor(P,Pred,1), arg(1,P,Arg),
	general_form(Arg,tail(Var)).

%
%  Solve a linear first-order difference equation with coefficient 1 based
%  on measure term-size on a list_cas.
%
solve_lsde(Var,Ivalue,Bn,Sol) :- 
	mutual_list_cas_solvable(Bn,Var),
	normal_form(1,One), Ivalue = [val(One,Ival)],
	general_form(Ival,GIval),!,
	solve_lsde1(Var,Bn,GIval,Sol).
solve_lsde(_,_,_,inf).

solve_lsde1(Var,[],GIval,Sol) :- normal_form(max(1,GIval)*Var,Sol).
solve_lsde1(Var,Bn,GIval,Sol) :- Bn \== [], solve_lsde2(Bn,Var,GIval,Sol).

solve_lsde2([],_,_,Zero) :- normal_form(0,Zero).
solve_lsde2([B|Bn],Var,GIval,Sol) :-
	solve_lsde3(B,Var,GIval,Sol1),
	solve_lsde2(Bn,Var,GIval,Sols),
	add_expr(Sol1,Sols,Sol).

solve_lsde3(factor([],C),Var,GIval,Sol) :- normal_form(max(C,GIval)*Var,Sol).
solve_lsde3(factor([Var],C),Var,GIval,Sol) :- 
	normal_form((max(C,GIval)/2)*Var*(Var+1),Sol).
solve_lsde3(factor([head(E)],C),Var,GIval,Sol) :-
	normal_form(Var,E), normal_form(max(C,GIval)*exp(Var-1,2)/2,Sol).
solve_lsde3(factor([tail(E)],C),Var,GIval,Sol) :-
	normal_form(Var,E), normal_form(max(C,GIval)*exp(Var-1,2)/2,Sol).

%
%
mutual_list_cas_solvable([],_).
mutual_list_cas_solvable([B|Bn],Var) :-
	mutual_list_cas_solvable1(B,Var),
	mutual_list_cas_solvable(Bn,Var).

mutual_list_cas_solvable1(factor([],_),_).	% d
mutual_list_cas_solvable1(factor([Var],_),Var).	%d*n
mutual_list_cas_solvable1(factor([head(Expr)],_),Var) :- normal_form(Var,Expr).
mutual_list_cas_solvable1(factor([tail(Expr)],_),Var) :- normal_form(Var,Expr).

