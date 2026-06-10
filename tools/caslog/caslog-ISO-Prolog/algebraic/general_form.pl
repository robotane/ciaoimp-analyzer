%
%  general_form.pl		Nai-Wei Lin			January, 1992
%
%  This file contains the procedures for transforming the normal-form
%  expressions into the general-form expressions.
%

%
%  Transform a normal-form expression into a general-form expression.
%
general_form(bot,bot).
general_form(inf,inf).
general_form(expr(T,F),Y) :-
	terms_general_form(T,0,Y1),
	factors_general_form(F,Y1,Y).

%
%  Transform the normal-form terms into a general-form expression.
%
terms_general_form([],Y,Y).
terms_general_form([term(P,F)|Ts],X,Y) :-
	primaries_general_form(P,P1),
	factors_general_form(F,0,F1),
	((integer(F1), F1 < 0) ->
		(MF1 is -F1,
		 multiply(MF1,P1,Y1),
		 subtraction(X,Y1,Y2));
		(multiply(F1,P1,Y1),
		 addition(X,Y1,Y2))),
	terms_general_form(Ts,Y2,Y).

%
%  Transform the normal-form factors into a general-form expression.
%
factors_general_form([],Y,Y).
factors_general_form([factor(I,C)|Fs],X,Y) :-
	items_general_form(I,1,I1),
	(C > 0 ->
		(multiply(C,I1,Y1),
		 addition(X,Y1,Y2));
		(MC is -C,
		 multiply(MC,I1,Y1),
		 subtraction(X,Y1,Y2))),
	factors_general_form(Fs,Y2,Y).

%
%  Transform the normal-form primaries into a general-form expression.
%
primaries_general_form(P,Y) :-
	items_general_form(P,1,Y).

%
%  Transform the normal-form items into a general-form expression.
%
items_general_form([],Y,Y).
items_general_form([I|Is],X,Y) :-
	item_general_form(I,Y1),
	multiply(X,Y1,Y2),
	items_general_form(Is,Y2,Y).

%
%  Transform a normal-form primary or item into a general-form expression.
%
item_general_form(I,I) :-
	variable(I).
item_general_form(exp(E1,E2),exp(G1,G2)) :-
	general_form(E1,G1),
	general_form(E2,G2).
item_general_form(log(E1,E2),log(G1,G2)) :-
	general_form(E1,G1),
	general_form(E2,G2).
item_general_form(fact(E),fact(G)) :-
	general_form(E,G).
item_general_form(I,Y) :-
	functor(I,sum,4),
	functor(Y,sum,4),
	function_general_form(4,I,Y).
item_general_form(I,Y) :-
	functor(I,prod,4),
	functor(Y,prod,4),
	function_general_form(4,I,Y).
item_general_form(I,Y) :-
	functor(I,arg,2),
	functor(Y,arg,2),
	function_general_form(2,I,Y).
item_general_form(I,Y) :-
	functor(I,arity,1),
	functor(Y,arity,1),
	function_general_form(1,I,Y).
item_general_form(I,Y) :-
	functor(I,head,1),
	functor(Y,head,1),
	function_general_form(1,I,Y).
item_general_form(I,Y) :-
	functor(I,tail,1),
	functor(Y,tail,1),
	function_general_form(1,I,Y).
item_general_form(I,Y) :-
	userfunc(I),
	functor(I,F,N),
	functor(Y,F,N),
	function_general_form(N,I,Y).

%
%  Transform a normal-form user-defined function into a general-form expression.
%
function_general_form(0,_,_).
function_general_form(N,I,Y) :-
	N > 0,
	arg(N,I,Arg),
	general_form(Arg,Arg1),
	arg(N,Y,Arg1),
	N1 is N-1,
	function_general_form(N1,I,Y).
