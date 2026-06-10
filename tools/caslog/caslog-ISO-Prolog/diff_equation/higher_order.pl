%
%  higher_order.pl 
%
%    Handle higher-order linear difference equation.
%

%
%  Test if a difference equation is linear higher-order.
%
higher_order_diff_equ(Equ,Var,F/_,A,_,Bn) :-
	Equ = expr([term([Dvar],An)],Bn),
	userfunc(Dvar),
	functor(Dvar,F,1),
	arg(1,Dvar,Arg),
	Arg = expr([],[factor([Var],1),factor([],I)]),
	integer(I),
	I < 0,
	A is -I,
	An = [factor([],1)].

%
%  Solve a linear higher-order difference equation.
%
solve_hode(Var,Ivalue,A,B,Sol) :-
	Ivalue = [val(Iindex,_)],
	general_form(Iindex,0),!,
	solve_hovde(Var,Ivalue,A,B,Sol).
solve_hode(_,_,_,_,inf).

%
%  Solve a linear first-order variable coefficient difference equation.
%
solve_hovde(Var,Ivalue,An,Bn,Sol) :-
	Ivalue = [val(_,Ival)],
	write(Ival),nl,
	B = expr([],Bn),
	general_form(B,GB),
	substitute(GB,Var,(An*($(i))),BN),
	write(BN),nl,
	normal_form(BN,NN),
	normal_form(1,One),
	normal_form((Var/An),Upper),
	sum_expr($(i),One,Upper,NN,S),
	write(S),nl,
	add_expr(Ival,S,Sol).

