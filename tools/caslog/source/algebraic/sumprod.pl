%
%  Sumprod.pl			Nai-Wei Lin			January, 1992
%
%  This file contains the procedures for performing sum and product 
%  operations.
%
%  Assume both lower and upper bounds are greater than or equal to 1.
%

%
%  Simplify the sum expression.
%
sum_expr(_,_,_,bot,bot).
sum_expr(_,_,bot,Expr,bot) :-
	Expr \== bot.
sum_expr(_,bot,Upper,Expr,bot) :-
	Expr \== bot,
	Upper \== bot.
sum_expr(_,Lower,Upper,inf,inf) :-
	Upper \== bot,
	Lower \== bot.
sum_expr(_,Lower,inf,Expr,inf) :-
	Expr \== bot,
	Expr \== inf,
	Lower \== bot.
sum_expr(_,inf,Upper,Expr,bot) :-
	Expr \== bot,
	Expr \== inf,
	Upper \== bot,
	Upper \== inf.
sum_expr(Var,Low,Upper,expr(T,F),Sum) :-
	sum_factors(Var,Low,Upper,F,FSum),
	sum_terms(Var,Low,Upper,T,TSum),
	add_expr(TSum,FSum,Sum).

%
%  Simplify the sum factors.
%
sum_factors(_,_,_,[],Sum) :-
	normal_form(0,Sum).
sum_factors(Var,Low,Upper,[F|Fs],Sum) :-
	sum_factor(Var,Low,Upper,F,Sum1),
	sum_factors(Var,Low,Upper,Fs,Sum2),
	add_expr(Sum1,Sum2,Sum).

sum_factor(Var,Low,Upper,factor(I,C),Sum) :-
	rel_const_items(I,Var),!,
	const_sum_factor(Low,Upper,Sum1),
	CExpr = expr([],[factor(I,C)]),
	multiply_expr(CExpr,Sum1,Sum).
sum_factor(Var,Low,Upper,factor(I,C),Sum) :-
	rel_linear_items(I,Var),!,
	linear_items_coeff(I,Var,Coeff),
	normal_form(1,One),
	poly_sum_factor(Var,Low,Upper,One,Sum1),
	CExpr = expr([],[factor(Coeff,C)]),
	multiply_expr(CExpr,Sum1,Sum).
sum_factor(Var,Low,Upper,factor(I,C),Sum) :-
	rel_poly_items(I,Var),!,
	poly_items_coeff(I,Var,Coeff,Exp),
	poly_sum_factor(Var,Low,Upper,Exp,Sum1),
	CExpr = expr([],[factor(Coeff,C)]),
	multiply_expr(CExpr,Sum1,Sum).
sum_factor(Var,Low,Upper,factor(I,C),Sum) :-
	rel_exp_items(I,Var,0),!,
	exp_items_coeff(I,Var,Coeff,Base,ExpCoe,ExpCon),
	exp_sum_factor(Low,Upper,Base,ExpCoe,ExpCon,Sum1),
	CExpr = expr([],[factor(Coeff,C)]),
	multiply_expr(CExpr,Sum1,Sum).
sum_factor(Var,Low,Upper,factor(I,C),Sum) :-
	rel_log_items(I,Var,0),!,
	log_items_coeff(I,Var,Coeff,Base,Exp),
	log_sum_factor(Var,Low,Upper,Base,Exp,Sum1),
	CExpr = expr([],[factor(Coeff,C)]),
	multiply_expr(CExpr,Sum1,Sum).
sum_factor(Var,Low,Upper,factor(I,C),Sum) :-
	normal_form(Var,Var1),
	Expr = expr([],[factor(I,C)]),
	Sum = expr([],[factor([sum(Var1,Low,Upper,Expr)],1)]).

%
%  Simplify the sum terms.
%
sum_terms(_,_,_,[],Sum) :-
	normal_form(0,Sum).
sum_terms(Var,Low,Upper,[T|Ts],Sum) :-
	sum_term(Var,Low,Upper,T,Sum1),
	sum_terms(Var,Low,Upper,Ts,Sum2),
	add_expr(Sum1,Sum2,Sum).

sum_term(Var,Low,Upper,T,Sum) :-
	normal_form(Var,Var1),
	Sum = expr([term([sum(Var1,Low,Upper,expr([T],[]))],[factor([],1)])],
	      []).

%
%  Simplify the constant sum factor.
%
const_sum_factor(Low,Upper,Sum) :-
	subtract_expr(Upper,Low,E1),
	normal_form(1,One),
	add_expr(E1,One,Sum).

%
%  Simplify the polynomial sum factor.
%
poly_sum_factor(Var,Lower,Upper,Order,Sum) :-
	general_form(Order,Order1),
	poly_indef_sum(Order1,Var,Upper,USum),
	(default_lower_bound(Lower) ->
		Sum = USum;
		(normal_form(1,One),
		 subtract_expr(Lower,One,Lower1),
		 poly_indef_sum(Order1,Var,Lower1,LSum),
		 subtract_expr(USum,LSum,Sum))).

%
%  Compute the polynomial indefinite sum.
%
poly_indef_sum(1,_,Upper,Sum) :-
	normal_form(1,One),
	add_expr(Upper,One,E1),
	multiply_expr(Upper,E1,E2),
	normal_form(2,Two),
	divide_expr(E2,Two,Sum).
poly_indef_sum(I,Var,Upper,Sum) :-
	I > 1,
	gen_subsum_expr(I,Var,E1),
	normal_form(exp(Var,I),E2),
	subtract_expr(E1,E2,Expr1),
	normal_form(1,One),
	sum_expr(Var,One,Upper,Expr1,Sum1),
	gen_subsum(I,Upper,Sum2),
	subtract_expr(Sum2,Sum1,Sum).

%
%  Generate the polynomial indefinite subsum expressions.
%
gen_subsum_expr(1,Var,Expr) :-
	normal_form(Var,Expr).
gen_subsum_expr(I,Var,Expr) :-
	I > 1,
	I1 is I-1,
	gen_subsum_expr(I1,Var,Expr1),
	normal_form(Var-I1,Expr2),
	multiply_expr(Expr1,Expr2,Expr).

%
%  Generate the polynomial indefinite subsum.
%
gen_subsum(I,Upper,Sum) :-
	gen_subsum_seq(I,Upper,Sum1),
	normal_form(I+1,Sum2),
	divide_expr(Sum1,Sum2,Sum).

gen_subsum_seq(0,Upper,Prod) :-
	normal_form(1,S1),
	add_expr(Upper,S1,Prod).
gen_subsum_seq(I,Upper,Prod) :-
	I > 0,
	I1 is I-1,
	normal_form(I1,S1),
	subtract_expr(Upper,S1,P1),
	gen_subsum_seq(I1,Upper,P2),
	multiply_expr(P1,P2,Prod).

%
%  Simplify an exponential sum factor.
%
exp_sum_factor(Lower,Upper,Base,ExpCoe,ExpCon,Sum) :-
	normal_form(1,One),
	add_expr(Upper,One,S1),
	multiply_expr(S1,ExpCoe,S2),
	exp_expr(Base,S2,E1),
	multiply_expr(Lower,ExpCoe,S3),
	exp_expr(Base,S3,E2),
	subtract_expr(E1,E2,E),
	exp_expr(Base,ExpCoe,S4),
	subtract_expr(S4,One,D),
	divide_expr(E,D,S5),
	exp_expr(Base,ExpCon,Coeff),
	multiply_expr(Coeff,S5,Sum).

%
%  Simplify a logarithm sum factor.
%
log_sum_factor(Var,Lower,Upper,Base,Exp,Sum) :-
	prod_expr(Var,Lower,Upper,Exp,Prod),
	log_expr(Base,Prod,Sum).


%
%  Simplify the product expression.
%
prod_expr(_,_,_,bot,bot).
prod_expr(_,_,bot,Expr,bot) :-
	Expr \== bot.
prod_expr(_,bot,Upper,Expr,bot) :-
	Expr \== bot,
	Upper \== bot.
prod_expr(_,Lower,Upper,inf,inf) :-
	Upper \== bot,
	Lower \== bot.
prod_expr(_,Lower,inf,Expr,inf) :-
	Expr \== bot,
	Expr \== inf,
	Lower \== bot.
prod_expr(_,inf,Upper,Expr,bot) :-
	Expr \== bot,
	Expr \== inf,
	Upper \== bot,
	Upper \== inf.
prod_expr(Var,Lower,Upper,Expr,Prod) :-
	Expr = expr([],[factor(I,C)]),!,
	prod_items(Var,Lower,Upper,I,Prod1),
	normal_form(C,C1),
	const_prod_expr(Lower,Upper,C1,Prod2),
	multiply_expr(Prod1,Prod2,Prod).
prod_expr(Var,Lower,Upper,Expr,Prod) :-
	Expr = expr([],F),
	rel_const_factor(F,Var),!,
	const_prod_expr(Lower,Upper,Expr,Prod).
prod_expr(Var,Lower,Upper,Expr,Prod) :-
	normal_form(Var,Var1),
	Prod = expr([],[factor([prod(Var1,Lower,Upper,Expr)],1)]).

%
%  Simplify the product items.
%
prod_items(_,_,_,[],Prod) :-
	normal_form(1,Prod).
prod_items(Var,Lower,Upper,[I|Is],Prod) :-
	prod_item(Var,Lower,Upper,I,Prod1),
	prod_items(Var,Lower,Upper,Is,Prod2),
	multiply_expr(Prod1,Prod2,Prod).

%
%  Simplify the product items.
%
prod_item(Var,Lower,Upper,Item,Prod) :-
	rel_const_item(Item,Var),!,
	Expr = expr([],[factor([Item],1)]),
	const_prod_expr(Lower,Upper,Expr,Prod).
prod_item(Var,Lower,Upper,Var,Prod) :-
	!,
	linear_prod_expr(Lower,Upper,Prod).
prod_item(Var,Lower,Upper,Item,Prod) :-
	rel_poly_item1(Item,Var),!,
	poly_items_coeff([Item],Var,_,Order),
	linear_prod_expr(Lower,Upper,P1),
	exp_expr(P1,Order,Prod).
prod_item(Var,Lower,Upper,Item,Prod) :-
	rel_exp_item1(Item,Var),!,
	Item = exp(E1,E2),
	sum_expr(Var,Lower,Upper,E2,Sum),
	exp_expr(E1,Sum,Prod).
prod_item(Var,Lower,Upper,Item,Prod) :-
	normal_form(Var,Var1),
	Expr = expr([],[factor([Item],1)]),
	Prod = expr([],[factor([prod(Var1,Lower,Upper,Expr)],1)]).

%
%  Simplify the constant product expression.
%
const_prod_expr(Low,Upper,Const,Prod) :-
	subtract_expr(Upper,Low,E1),
	normal_form(1,One),
	add_expr(E1,One,E2),
	exp_expr(Const,E2,Prod).

%
%  Simplify the linear product expression.
%
linear_prod_expr(Low,Upper,Prod) :-
	factorial_expr(Upper,E1),
	normal_form(1,One),
	subtract_expr(Low,One,E2),
	factorial_expr(E2,E3),
	divide_expr(E1,E3,Prod).

%
%  Test if an expression is constant w.r.t. a variable.
%
rel_const_expr(Var,expr([],F)) :-
	rel_const_factor(F,Var).

%
%  Test if a factor is constant w.r.t. a variable.
%
rel_const_factor([],_).
rel_const_factor([factor(I,_)|Fs],Var) :-
	rel_const_items(I,Var),
	rel_const_factor(Fs,Var).

rel_const_items([],_).
rel_const_items([I|Is],Var) :-
	rel_const_item(I,Var),
	rel_const_items(Is,Var).

%
%  Test if an item is constant w.r.t. a variable.
%
rel_const_item(Var1,Var) :-
	variable(Var1),
	Var1 \== Var.
rel_const_item(exp(E1,E2),Var) :-
	rel_const_expr(Var,E1),
	rel_const_expr(Var,E2).
rel_const_item(log(E1,E2),Var) :-
	rel_const_expr(Var,E1),
	rel_const_expr(Var,E2).
rel_const_item(fact(E),Var) :-
	rel_const_expr(Var,E).

%
%  Test if an expression is linear w.r.t. a variable.
%
rel_linear_expr(Var,expr([],F)) :-
	rel_linear_factor(F,Var).

%
%  Test if a factor is linear w.r.t. a variable.
%
rel_linear_factor([],_).
rel_linear_factor([factor(I,_)|F],Var) :-
	rel_linear_items(I,Var),
	rel_linear_factor(F,Var).

rel_linear_items([],_).
rel_linear_items([I|Is],Var) :-
	rel_linear_item(I,Var),
	rel_linear_items(Is,Var).

%
%  Test if an item is linear w.r.t. a variable.
%
rel_linear_item(Var1,Var) :-
	variable(Var1),
	Var1 \== Var.
rel_linear_item(exp(E1,E2),Var) :-
	rel_const_expr(Var,E1),
	rel_const_expr(Var,E2).
rel_linear_item(log(E1,E2),Var) :-
	rel_const_expr(Var,E1),
	rel_const_expr(Var,E2).
rel_linear_item(fact(E),Var) :-
	rel_const_expr(Var,E).
rel_linear_item(Var,Var).

%
%  Get the coefficient of a linear expression w.r.t. a variable.
%
linear_expr_coeff(Var,expr([],F),expr([],NCoeF),expr([],NConF)) :-
	linear_factor_coeff(F,Var,NCoeF,NConF).

linear_factor_coeff([],_,[],[]).
linear_factor_coeff([factor(I,C)|F],Var,NCoeF,NConF) :-
	linear_factor_coeff(F,Var,CoeF,ConF),
	linear_items_coeff(I,Var,Coeff),
	(I == Coeff ->
		(add_factor(ConF,factor(Coeff,C),NConF),
		 NCoeF = CoeF);
		(add_factor(CoeF,factor(Coeff,C),NCoeF),
		 NConF = ConF)).

linear_items_coeff([],_,[]).
linear_items_coeff([I|Is],Var,Coeff) :-
	(I == Var ->
		Coeff = NCoeff;
		Coeff = [I|NCoeff]),
	linear_items_coeff(Is,Var,NCoeff).

%
%  Test if an expression is polynomial w.r.t. a variable.
%
rel_poly_expr(Var,expr([],F)) :-
	rel_poly_factor(F,Var).

%
%  Test if a factor is polynomial w.r.t. a variable.
%
rel_poly_factor([factor(I,_)],Var) :-
	rel_poly_items(I,Var).

rel_poly_items([],_).
rel_poly_items([I|Is],Var) :-
	rel_poly_item(I,Var),
	rel_poly_items(Is,Var).

%
%  Test if an item is polynomial w.r.t. a variable.
%
rel_poly_item(Var1,Var) :-
	variable(Var1),
	Var1 \== Var.
rel_poly_item(exp(E1,E2),Var) :-
	rel_const_expr(Var,E1),
	rel_const_expr(Var,E2).
rel_poly_item(log(E1,E2),Var) :-
	rel_const_expr(Var,E1),
	rel_const_expr(Var,E2).
rel_poly_item(fact(E),Var) :-
	rel_const_expr(Var,E).
rel_poly_item(exp(E1,E2),Var) :-
	normal_form(Var,E1),
	general_form(E2,E),
	integer(E).

rel_poly_item1(exp(Var1,E),Var) :-
	normal_form(Var,Var1),
	general_form(E,E1),
	integer(E1).

%
%  Get the coefficient and the order of a polynomial expression w.r.t. 
%  a variable.
%
poly_expr_coeff(Var,expr([],F),expr([],Coeff),Exp) :-
	poly_factor_coeff(F,Var,Coeff,Exp).

poly_factor_coeff([factor(I,C)],Var,[factor(Coeff,C)],Exp) :-
	poly_items_coeff(I,Var,Coeff,Exp).

poly_items_coeff([],_,[],_).
poly_items_coeff([I|Is],Var,Coeff,Exp) :-
	(I = exp(E1,E2),normal_form(Var,E1),general_form(E2,E),integer(E) ->
		(Coeff = NCoeff,
		 Exp = E2);
		(Coeff = [I|NCoeff],
		 Exp = Exp1)),
	poly_items_coeff(Is,Var,NCoeff,Exp1).

%
%  Test if an expression is exponential w.r.t. a variable.
%
rel_exp_expr(Var,expr([],F)) :-
	rel_exp_factor(F,Var).

%
%  Test if a factor is exponential w.r.t. a variable.
%
rel_exp_factor([factor(I,_)],Var) :-
	rel_exp_items(I,Var,0).

rel_exp_items([],_,_).
rel_exp_items([I|Is],Var,Flag) :-
	rel_exp_item(I,Var,Flag,NFlag),
	rel_exp_items(Is,Var,NFlag).

%
%  Test if an item is exponential w.r.t. a variable.
%
rel_exp_item(Var1,Var,Flag,Flag) :-
	variable(Var1),
	Var1 \== Var.
rel_exp_item(exp(E1,E2),Var,Flag,Flag) :-
	rel_const_expr(Var,E1),
	rel_const_expr(Var,E2).
rel_exp_item(log(E1,E2),Var,Flag,Flag) :-
	rel_const_expr(Var,E1),
	rel_const_expr(Var,E2).
rel_exp_item(fact(E),Var,Flag,Flag) :-
	rel_const_expr(Var,E).
rel_exp_item(exp(E1,E2),Var,0,1) :-
	rel_const_expr(Var,E1),
	rel_linear_expr(Var,E2).

rel_exp_item1(exp(E1,_),Var) :-
	rel_const_expr(Var,E1).

%
%  Get the coefficient, the base and the exponent of an exponential 
%  expression w.r.t. a variable.
%
exp_expr_coeff(Var,expr([],F),expr([],Coeff),Base,ExpCoe,ExpCon) :-
	exp_factor_coeff(F,Var,Coeff,Base,ExpCoe,ExpCon).

exp_factor_coeff([factor(I,C)],Var,[factor(Coeff,C)],Base,ExpCoe,ExpCon) :-
	exp_items_coeff(I,Var,Coeff,Base,ExpCoe,ExpCon).

exp_items_coeff([],_,[],_,_,_).
exp_items_coeff([I|Is],Var,Coeff,Base,ExpCoe,ExpCon) :-
	(I = exp(E1,E2),rel_const_expr(Var,E1),rel_linear_expr(Var,E2) ->
		(Base = E1,
		 linear_expr_coeff(Var,E2,ExpCoe,ExpCon),
		 Coeff = NCoeff);
		(Base = NBase,
		 ExpCoe = NExpCoe,
		 ExpCon = NExpCon,
		 Coeff = [I|NCoeff])),
	exp_items_coeff(Is,Var,NCoeff,NBase,NExpCoe,NExpCon).

%
%  Test if an expression is logarithmic w.r.t. a variable.
%
rel_log_expr(Var,expr([],F)) :-
	rel_log_factor(F,Var).

%
%  Test if a factor is logarithmic w.r.t. a variable.
%
rel_log_factor([factor(I,_)],Var) :-
	rel_log_items(I,Var,0).

rel_log_items([],_,_).
rel_log_items([I|Is],Var,Flag) :-
	rel_log_item(I,Var,Flag,NFlag),
	rel_log_items(Is,Var,NFlag).

%
%  Test if an item is logarithmic w.r.t. a variable.
%
rel_log_item(Var1,Var,Flag,Flag) :-
	variable(Var1),
	Var1 \== Var.
rel_log_item(exp(E1,E2),Var,Flag,Flag) :-
	rel_const_expr(Var,E1),
	rel_const_expr(Var,E2).
rel_log_item(fact(E),Var,Flag,Flag) :-
	rel_const_expr(Var,E).
rel_log_item(log(E1,_),Var,0,1) :-
	rel_const_expr(Var,E1).

%
%  Get the coefficient, the base and the exponent of a logarithmic 
%  expression w.r.t. a variable.
%
log_expr_coeff(Var,expr([],F),expr([],Coeff),Base,Exp) :-
	log_factor_coeff(F,Var,Coeff,Base,Exp).

log_factor_coeff([factor(I,C)],Var,[factor(Coeff,C)],Base,Exp) :-
	log_items_coeff(I,Var,Coeff,Base,Exp).

log_items_coeff([],_,[],_,_).
log_items_coeff([I|Is],Var,Coeff,Base,Exp) :-
	(I = log(E1,E2),rel_const_expr(Var,E1) ->
		(Base = E1,
		 Exp = E2,
		 Coeff = NCoeff);
		(Base = NBase,
		 Exp = NExp,
		 Coeff = [I|NCoeff])),
	log_items_coeff(Is,Var,NCoeff,NBase,NExp).

%
%  Test if the lower bound of a sum or product is 1.
%
default_lower_bound(Lower) :-
	general_form(Lower,Lower1),
	number(Lower1),
	Lower1 =:= 1.
