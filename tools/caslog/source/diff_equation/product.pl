%
%  product.pl 
%
%    Handle nonlinear difference equations in the form of a product.
%

%
%  Test if a difference equation is linear first-order.
%
product_diff_equ(Equ,Pred,NEqu) :-
	Equ = expr([term(Term,Factor)],[]),
	Factor = [factor([],_)],
	product_term(Term,Pred,NTerm),
	NEqu = expr(NTerm,Factor).

product_term(Term,Pred,NTerm) :-
	length_list(Term,Len), Len > 1,
	product_term(Term,Pred,0,NTerm).

product_term([],_,Count,[]) :- Count > 0.	% direct difference equation
product_term([Dvar|Term],F/N,Count,[term([Dvar],[factor([],1)])|NT]) :-
	userfunc(Dvar),
	functor(Dvar,F,1),!,		% 1-index reducible only
	Count1 is Count+1,
	product_term(Term,F/N,Count1,NT).
product_term([Dvar|Term],F/N,Count,[term([Dvar],[factor([],1)])|NT]) :-
	userfunc(Dvar),
	functor(Dvar,F1,_), F \== F1,!,
	product_term(Term,F/N,Count,NT).

%
%
log_base_equs([],[]).
log_base_equs([equ(N,I,E)|BE],[equ(N,I,NE)|NBE]) :-
	normal_form(2,Two),
	log_expr(Two,E,NE),
	log_base_equs(BE,NBE).

%
%
exp_solution(Sol,NSol) :-
	normal_form(2,Two),
	exp_expr(Two,Sol,NSol).
