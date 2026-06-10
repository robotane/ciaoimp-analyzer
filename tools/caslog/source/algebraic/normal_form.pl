%
%  normal_form.pl		Nai-Wei Lin			January, 1992
%
%  This file contains the procedures for transforming general-form 
%  expressions into normal-form expressions, and performing algebraic
%  simplification.
%

%
%  Simplify a list_cas of general-form expressions.
%
list_cas_simplification([],[]).
list_cas_simplification([X|Xs],[Y|Ys]) :-
	simplification(X,Y),
	list_cas_simplification(Xs,Ys).

%
%  Simplify a general-form expression.
%
simplification(X,Y) :-
	normal_form(X,Z),
	general_form(Z,Y).

%
%  Transform a general-form expression into a normal-form expression.
%
normal_form(bot,bot).
normal_form(inf,inf).
normal_form(X,Y) :-
	number(X),
	number_normal_form(X,Y).

/*normal_form(X,Y) :-
((A/B=X,number(A),number(B)) ->
	number_normal_form(X,Y);
	compound_cas(X),
	comp_normal_form(X,Y)).
*/
normal_form(X,Y) :-
	compound_cas(X),
	comp_normal_form(X,Y).

%
%  Transform a general-form number into a normal-form number.
%
number_normal_form(X,expr([],[factor([],X)])) :-
	X =\= 0.
number_normal_form(X,expr([],[])) :-
	X =:= 0.

%
%  Transform a general-form compound_cas expression into a normal-form compound_cas 
%  expression.
%
comp_normal_form(X,Y) :-
	variable(X),
	var_normal_form(X,Y).
comp_normal_form(X+Y,Z) :-
	normal_form(X,X1),
	normal_form(Y,Y1),
	add_expr(X1,Y1,Z).
comp_normal_form(X-Y,Z) :-
	normal_form(X,X1),
	normal_form(Y,Y1),
	subtract_expr(X1,Y1,Z).
comp_normal_form(X*Y,Z) :-
	normal_form(X,X1),
	normal_form(Y,Y1),
	multiply_expr(X1,Y1,Z).
comp_normal_form(X/Y,Z) :-
	normal_form(X,X1),
	normal_form(Y,Y1),
	divide_expr(X1,Y1,Z).
comp_normal_form(-X,Y) :-
	Minus1 is -1,
	normal_form(Minus1,X1),
	normal_form(X,X2),
	multiply_expr(X1,X2,Y).
comp_normal_form(exp(X,Y),Z) :-
	normal_form(X,X1),
	normal_form(Y,Y1),
	exp_expr(X1,Y1,Z).
comp_normal_form(log(X,Y),Z) :-
	normal_form(X,X1),
	normal_form(Y,Y1),
	log_expr(X1,Y1,Z).
comp_normal_form(fact(X),Y) :-
	normal_form(X,X1),
	factorial_expr(X1,Y).
comp_normal_form(max(X,Y),Z) :-
	normal_form(X,X1),
	normal_form(Y,Y1),
	max_expr(X1,Y1,Z).
comp_normal_form(min(X,Y),Z) :-
	normal_form(X,X1),
	normal_form(Y,Y1),
	min_expr(X1,Y1,Z).
comp_normal_form(X,Y) :-
	functor(X,sum,4),
	sum_normal_form(X,Y).
comp_normal_form(X,Y) :-
	functor(X,prod,4),
	prod_normal_form(X,Y).
comp_normal_form(X,Y) :-
	functor(X,arg,2),
	function_expr(X,Y).
comp_normal_form(X,Y) :-
	functor(X,arity,1),
	function_expr(X,Y).
comp_normal_form(X,Y) :-
	functor(X,head,1),
	function_expr(X,Y).
comp_normal_form(X,Y) :-
	functor(X,tail,1),
	function_expr(X,Y).
comp_normal_form(X,Y) :-
	userfunc(X),
	userfunc_normal_form(X,Y).

%
%  Transform a general-form variable into a normal-form variable.
%
var_normal_form(X,expr([],[factor([X],1)])).

sum_normal_form(X,Y) :-
	functor(X,sum,4),
	arg(1,X,Index),
	arg(2,X,1),
	arg(3,X,arity(Var)),
	arg(4,X,arg(Var,Index)),!,
	normal_form(Var-1,Y).
sum_normal_form(X,Y) :-
	functor(X,sum,4),
	arg(1,X,Var),
	arg(2,X,Lower),
	normal_form(Lower,NLower),
	arg(3,X,Upper),
	normal_form(Upper,NUpper),
	arg(4,X,Expr),
	normal_form(Expr,NExpr),
	sum_expr(Var,NLower,NUpper,NExpr,Y).

prod_normal_form(X,Y) :-
	functor(X,prod,4),
	arg(1,X,Var),
	arg(2,X,Lower),
	normal_form(Lower,NLower),
	arg(3,X,Upper),
	normal_form(Upper,NUpper),
	arg(4,X,Expr),
	normal_form(Expr,NExpr),
	prod_expr(Var,NLower,NUpper,NExpr,Y).

%
%  Transform a general-form sum or prod function into a normal-form 
%  sum or product function.
%
function_expr(X,expr([],[factor([Y],1)])) :-
	functor(X,F,N),
	functor(Y,F,N),
	function_normal_form(N,X,Y).

function_normal_form(0,_,_).
function_normal_form(N,X,Y) :-
	N > 0,
	arg(N,X,Arg),
	normal_form(Arg,NArg),
	arg(N,Y,NArg),
	N1 is N-1,
	function_normal_form(N1,X,Y).

%
%  Transform a general-form user-defined function into a normal-form 
%  user-defined function.
%
userfunc_normal_form(X,expr([term([Y],[factor([],1)])],[])) :-
	functor(X,F,N),
	functor(Y,F,N),
	function_normal_form(N,X,Y).

%
%  Test if a term is a variable.
%
variable($(_)).
variable($(_,_)).


%
%  Test if a term is a user-defined function.
%
/*
userfunc(X) :-
    functor(X,F,N),
    \==((F,N), (('$'),1)), 
    \==((F,N), (('$'),2)), 
    \==((F,N),(('+'),2)),
    \==((F,N),(('-'),2)),
    \==((F,N),(('*'),2)),
    \==((F,N),(('/'),2)),
    \==((F,N),(('-'),1)),
    \==((F,N),(exp,2)),
    \==((F,N),(log,2)),
    \==((F,N),(fact,1)),
    \==((F,N),(max,2)),
    \==((F,N),(min,2)),
    \==((F,N), (arg,2)),
    \==((F,N),(arity,1)),
    \==((F,N),(head,1)),
    \==((F,N),(tail,1)),
    \==((F,N),(sum,4)),
    \==((F,N),(prod,4)).

*/
userfunc(X) :-
	functor(X,F,N),
	(F,N) \== (('$'),1), (F,N) \== (('$'),2), (F,N) \== (('+'),2),
	(F,N) \== (('-'),2), (F,N) \== (('*'),2), (F,N) \== (('/'),2),
	(F,N) \== (('-'),1), (F,N) \== (exp,2), (F,N) \== (log,2),
	(F,N) \== (fact,1),(F,N) \== (max,2), (F,N) \== (min,2),
	(F,N) \== (arg,2), (F,N) \== (arity,1),(F,N) \== (head,1),
	(F,N) \== (tail,1),(F,N) \== (sum,4), (F,N) \== (prod,4).
