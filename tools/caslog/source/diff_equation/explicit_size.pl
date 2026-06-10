%
%  Test if a difference equation based on measure term-size on a structure
%  is linear ``first-order'' with coefficient 1. That is,
%  f(n) = f(arg(n,m)) + f(arg(n,m-1)) + ... + g(n), where
%  g(n) is either d, d*n, or arg(n,i).
%
explicit_size_diff_equ(Equ,Var,F/_,_,_,Bn) :-

	Equ = expr(Term,Bn),
	explicit_size_terms(Term,Var,F).

explicit_size_terms([],_,_).
explicit_size_terms([Term|Terms],Var,Pred) :-
	explicit_size_term(Term,Var,Pred),
	explicit_size_terms(Terms,Var,Pred).

explicit_size_term(term([P],[factor([],1)]),Var,Pred) :-
	userfunc(P), functor(P,Pred,1), arg(1,P,Arg),
	general_form(Arg,arg(Var,I)),
	integer(I).

%
%  Solve a linear first-order difference equation with coefficient 1 based
%  on measure term-size on a structure.
%
solve_esde(Var,Ivalue,Bn,Sol) :- 
	%nl,write(Bn),nl,
	explicit_size_solvable(Bn,Var),!,
	%write('esde2'),nl,
	%write(Bn),nl,
	Ivalue = [val(_,Ival)],
	general_form(Ival,GIval),
	%write(GIval),nl,
	solve_esde1(Var,Bn,GIval,Sol).
solve_esde(_,_,_,inf).

solve_esde1(Var,[],GIval,Sol) :- !,normal_form(GIval*Var,Sol).
solve_esde1(Var,Bn,GIval,Sol) :- Bn \== [], solve_esde2(Bn,Var,GIval,Sol).

solve_esde2([],_,_,Zero) :- normal_form(0,Zero).
solve_esde2([B|Bn],Var,GIval,Sol) :-
	%write(B),nl,
	solve_esde3(B,Var,GIval,Sol1),
	%general_form(Sol1,GSol),nl,
	%write(GSol),nl,nl,
	solve_esde2(Bn,Var,GIval,Sols),
	add_expr(Sol1,Sols,Sol).

solve_esde3(factor([],C),Var,GIval,Sol) :- 	% d
	!, normal_form((max(C,GIval)*Var),Sol).
solve_esde3(factor([Var],C),Var,GIval,Sol) :- 	% d*x
	!, normal_form(((max(C,GIval)/2)*Var*(Var+1)),Sol).
solve_esde3(factor([arg(_,_)],C),Var,GIval,Sol) :- % an approx. same as d*x
	!, normal_form(((max(C,GIval)/2)*Var*(Var+1)),Sol).
solve_esde3(factor([exp(E1,E2)],C),Var,GIval,Sol) :- 	% d*2^x
	normal_form(Var,E2), general_form(E1,I), integer(I),!,
	(number(GIval) ->
		normal_form(max(C,GIval)*(exp(I,Var+1)-1)/(I-1),Sol);
		normal_form(C*(exp(I,Var+1)-1)/(I-1)+(GIval*Var),Sol)).
solve_esde3(factor([exp(E1,E2)],C),Var,GIval,Sol) :- 	% d*i^arg(x,n)
	general_form(E2,arg(Var,N)), integer(N),
	general_form(E1,I), integer(I),
	(number(GIval) ->
		normal_form(max(C,GIval)*(exp(I,Var+1)-1)/(I-1),Sol);
		normal_form(C*(exp(I,Var+1)-1)/(I-1)+(GIval*Var),Sol)).

%
explicit_size_solvable([],_).
explicit_size_solvable([B|Bn],Var) :-
	explicit_size_solvable1(B,Var),
	explicit_size_solvable(Bn,Var).

explicit_size_solvable1(factor([],_),_).	% d
explicit_size_solvable1(factor([Var],_),Var).	%d*x
explicit_size_solvable1(factor([arg(Expr1,Expr2)],_),Var) :- 	% arg(x,i)
	normal_form(Var,Expr1), general_form(Expr2,I), integer(I).
explicit_size_solvable1(factor([exp(Expr1,Expr2)],_),Var) :-	%d*i^x
	normal_form(Var,Expr2), general_form(Expr1,I), integer(I),!.
explicit_size_solvable1(factor([exp(Expr1,Expr2)],_),Var) :-	%d*i^arg(x,n)
	general_form(Expr2,arg(Var,N)), integer(N),
	general_form(Expr1,I), integer(I).

