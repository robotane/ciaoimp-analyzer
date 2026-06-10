%
%  algebraic.pl			Nai-Wei Lin			January, 1992
%
%  This file contains the procedures for performing algebraic computations
%  in normal-form.
%

%
%  add two normal-form expressions.
%
add_expr(_,bot,bot).
add_expr(bot,A2,bot) :-
	A2 \== bot.
add_expr(A1,inf,inf) :-
	A1 \== bot.
add_expr(inf,A2,inf) :-
	A2 \== bot,
	A2 \== inf.
add_expr(expr(T1,F1),expr(T2,F2),expr(T,F)) :-
	add_terms(T1,T2,T),
	add_factors(F1,F2,F).

%
%  add two normal-form terms.
%
add_terms(T1,[],T1).
add_terms([],T2,T2) :-
	T2 \== [].
add_terms([T|T1],T2,NT) :-
	T2 \== [],
	add_terms(T1,T2,Ts),
	add_term(Ts,T,NT).

add_term([],T,[T]).
add_term([term(T1,C1)|Ts],term(T2,C2),NT) :-
	T1 == T2,
	add_factors(C1,C2,C),
	(C == [] ->
		NT = Ts;
		NT = [term(T1,C)|Ts]).
add_term([term(T1,C1)|Ts],term(T2,C2),[term(T2,C2),term(T1,C1)|Ts]) :-
	T1 @< T2.
add_term([term(T1,C1)|Ts1],term(T2,C2),[term(T1,C1)|Ts]) :-
	T1 @> T2,
	add_term(Ts1,term(T2,C2),Ts).
	
%
%  add two normal-form factors.
%
add_factors(F1,[],F1).
add_factors([],F2,F2) :-
	F2 \== [].
add_factors([F|F1],F2,NF) :-
	F2 \== [],
	add_factors(F1,F2,Fs),
	add_factor(Fs,F,NF).

add_factor([],F,[F]).
add_factor([factor(F1,C1)|Fs],factor(F2,C2),NF) :-
	F1 == F2,
	C is C1+C2,
	(C =:= 0 ->
		NF = Fs;
		NF = [factor(F1,C)|Fs]).
add_factor([factor(F1,C1)|Fs],factor(F2,C2),[factor(F2,C2),factor(F1,C1)|Fs]) :-
	F1 @< F2.
add_factor([factor(F1,C1)|Fs1],factor(F2,C2),[factor(F1,C1)|Fs]) :-
	F1 @> F2,
	add_factor(Fs1,factor(F2,C2),Fs).

%
%  Subtract two normal-form expressions.
%
subtract_expr(_,bot,bot).
subtract_expr(bot,A2,bot) :-
	A2 \== bot.
subtract_expr(A1,inf,bot) :-
	A1 \== bot.
subtract_expr(inf,A2,inf) :-
	A2 \== bot,
	A2 \== inf.
subtract_expr(E1,E2,E) :-
	Minus1 is -1,
	normal_form(Minus1,MinusOne),
	multiply_expr(MinusOne,E2,E3),
	add_expr(E1,E3,E).

%
%  multiply two normal-form expressions.
%
multiply_expr(_,bot,bot).
multiply_expr(bot,A2,bot) :-
	A2 \== bot.
multiply_expr(A1,inf,inf) :-
	A1 \== bot.
multiply_expr(inf,A2,inf) :-
	A2 \== bot,
	A2 \== inf.
multiply_expr(expr(T1,F1),expr(T2,F2),expr(T,F)) :-
	multiply_terms(T1,T2,T3),
	multiply_term_factor(T1,F2,T4),
	multiply_term_factor(T2,F1,T5),
	add_terms(T3,T4,T6),
	add_terms(T5,T6,T),
	multiply_factors(F1,F2,F).
	
%
%  multiply two normal-form terms.
%
multiply_terms(_,[],[]).
multiply_terms([],T2,[]) :-
	T2 \== [].
multiply_terms([T|T1],T2,NT) :-
	T2 \== [],
	multiply_term(T2,T,T3),
	multiply_terms(T1,T2,T4),
	add_terms(T3,T4,NT).

multiply_term([],_,[]).
multiply_term([term(P1,F1)|Ts1],term(P2,F2),[term(P,F)|Ts]) :-
	multiply_factors(F1,F2,F),
	multiply_primaries(P1,P2,P),
	multiply_term(Ts1,term(P2,F2),Ts).

%
%  multiply two normal-form primaries.
%
multiply_primaries(P1,[],P1).
multiply_primaries([],P2,P2) :-
	P2 \== [].
multiply_primaries([P|P1],P2,NP) :-
	P2 \== [],
	multiply_primaries(P1,P2,Ps),
	multiply_primary(Ps,P,NP).

multiply_primary(Ps,P,NP) :-
	multiply_primary(Ps,P,Done,TP),
	(Done == 1 ->
		NP = TP;
		insert_order_list_cas(Ps,P,NP)).

multiply_primary([],_,0,[]).
multiply_primary([P1|Ps],P1,1,[exp(expr([P1],[factor([],1)]),
	      expr([],[factor([],2)]))|Ps]) :-
	functor(P1,F,N),
	(F,N) \== (exp,2).
multiply_primary([exp(P1,C1)|Ps],exp(P1,C2),1,[exp(P1,C)|Ps]) :-
	add_expr(C1,C2,C).
multiply_primary([P1|Ps],exp(Expr,Exp),1,[exp(Expr,NExp)|Ps]) :-
	Expr = expr([P1],[factor([],1)]),
	normal_form(1,One),
	add_expr(One,Exp,NExp).
multiply_primary([exp(Expr,Exp)|Ps],P1,1,[exp(Expr,NExp)|Ps]) :-
	Expr = expr([P1],[factor([],1)]),
	normal_form(1,One),
	add_expr(One,Exp,NExp).
multiply_primary([P1|Ps1],P2,Done,[P1|Ps]) :-
	functor(P1,F1,N1),
	(F1,N1) \== (exp,2),
	functor(P2,F2,N2),
	(F2,N2) \== (exp,2),
	P1 \== P2,
	multiply_primary(Ps1,P2,Done,Ps).
multiply_primary([exp(P1,C1)|Ps1],exp(P2,C2),Done,[exp(P1,C1)|Ps]) :-
	P1 \== P2,
	multiply_primary(Ps1,exp(P2,C2),Done,Ps).
multiply_primary([P1|Ps1],exp(Expr,Exp),Done,[P1|Ps]) :-
	Expr \== expr([P1],[factor([],1)]),
	multiply_primary(Ps1,exp(Expr,Exp),Done,Ps).
multiply_primary([exp(Expr,Exp)|Ps1],P1,Done,[exp(Expr,Exp)|Ps]) :-
	Expr \== expr([P1],[factor([],1)]),
	multiply_primary(Ps1,P1,Done,Ps).


%
%  multiply a normal-form term and a normal-form factor.
%
multiply_term_factor(_,[],[]).
multiply_term_factor([],F2,[]) :-
	F2 \== [].
multiply_term_factor([term(T,F1)|Ts1],F2,[term(T,F)|Ts]) :-
	F2 \== [],
	multiply_factors(F1,F2,F),
	multiply_term_factor(Ts1,F2,Ts).

%
%  multiply two normal-form factors.
%
multiply_factors(_,[],[]).
multiply_factors([],F2,[]) :-
	F2 \== [].
multiply_factors([F|F1],F2,NF) :-
	F2 \== [],
	multiply_factor(F2,F,F3),
	multiply_factors(F1,F2,F4),
	add_factors(F3,F4,NF).

multiply_factor([],_,[]).
multiply_factor([factor(I1,C1)|Fs1],factor(I2,C2),[factor(I,C)|Fs]) :-
	C is C1*C2,
%	C=C1*C2,
  multiply_items(I1,I2,I),
	multiply_factor(Fs1,factor(I2,C2),Fs).

%
%  multiply two normal-form items.
%
multiply_items(I1,[],I1).
multiply_items([],I2,I2) :-
	I2 \== [].
multiply_items([I|I1],I2,NI) :-
	I2 \== [],
	multiply_items(I1,I2,Is),
	multiply_item(Is,I,NI).

multiply_item(Is,I,NI) :-
	multiply_item(Is,I,Done,TI),
	(Done == 1 ->
		NI = TI;
		insert_order_list_cas(Is,I,NI)).

multiply_item([],_,0,[]).
multiply_item([I1|Is],I1,1,[exp(expr([],[factor([I1],1)]),
	      expr([],[factor([],2)]))|Is]) :-
	functor(I1,F,N),
	(F,N) \== (exp,2).
multiply_item([exp(I1,C1)|Is],exp(I1,C2),1,[exp(I1,C)|Is]) :-
	add_expr(C1,C2,C).
multiply_item([I1|Is],exp(Expr,Exp),1,[exp(Expr,NExp)|Is]) :-
	Expr = expr([],[factor([I1],1)]),
	normal_form(1,One),
	add_expr(One,Exp,NExp).
multiply_item([exp(Expr,Exp)|Is],I1,1,[exp(Expr,NExp)|Is]) :-
	Expr = expr([],[factor([I1],1)]),
	normal_form(1,One),
	add_expr(One,Exp,NExp).
multiply_item([I1|Is1],I2,Done,[I1|Is]) :-
	functor(I1,F1,N1),
	(F1,N1) \== (exp,2),
	functor(I2,F2,N2),
	(F2,N2) \== (exp,2),
	I1 \== I2,
	multiply_item(Is1,I2,Done,Is).
multiply_item([exp(I1,C1)|Is1],exp(I2,C2),Done,[exp(I1,C1)|Is]) :-
	I1 \== I2,
	multiply_item(Is1,exp(I2,C2),Done,Is).
multiply_item([I1|Is1],exp(Expr,Exp),Done,[I1|Is]) :-
	Expr \== expr([],[factor([I1],1)]),
	multiply_item(Is1,exp(Expr,Exp),Done,Is).
multiply_item([exp(Expr,Exp)|Is1],I1,Done,[exp(Expr,Exp)|Is]) :-
	Expr \== expr([],[factor([I1],1)]),
	multiply_item(Is1,I1,Done,Is).

%
%  Divide two normal-form expressions.
%
divide_expr(_,bot,bot).
divide_expr(bot,A2,bot) :-
	A2 \== bot.
divide_expr(A1,inf,Zero) :-
	A1 \== bot,
	normal_form(0,Zero).
divide_expr(inf,A2,inf) :-
	A2 \== bot,
	A2 \== inf.
divide_expr(E1,E2,E) :-
	general_form(E2,E3),
	(number(E3) ->
		(X is  1/E3,
		 %X=1/E3,
		% write('X='),
		% write(X),
		 normal_form(X,E4));
		(Minus1 is -1,
		 normal_form(Minus1,MinusOne),
		 exp_expr(E2,MinusOne,E4))),
	multiply_expr(E1,E4,E).

%
%  compute the exponent in normal-form.
%
exp_expr(_,bot,bot).
exp_expr(bot,A2,bot) :-
	A2 \== bot.
exp_expr(A1,inf,inf) :-
	A1 \== bot.
exp_expr(inf,A2,inf) :-
	A2 \== bot,
	A2 \== inf.
exp_expr(_,E2,expr([],[factor([],1)])) :-
	E2 == expr([],[]),!.
exp_expr(E1,E2,E1) :-
	E2 = expr([],[factor([],I)]),
	I =:= 1,!.
exp_expr(E1,_,expr([],[])) :-
	E1 == expr([],[]),!.
exp_expr(E1,_,expr([],[factor([],1)])) :-
	E1 = expr([],[factor([],I)]),
	I =:= 1,!.
exp_expr(E1,E2,expr([],[factor([],E)])) :-
	E1 = expr([],[factor([],I1)]),
	E2 = expr([],[factor([],I2)]),!,
	F1 is float(I1),
	F2 is float(I2),
	pow(F1,F2,E).
exp_expr(E1,E2,expr([],[factor([exp(E1,E2)],1)])).

%
%  compute the logarithm in normal-form.
%
log_expr(_,bot,bot).
log_expr(bot,A2,bot) :-
	A2 \== bot.
log_expr(A1,inf,inf) :-
	A1 \== bot.
log_expr(inf,A2,bot) :-
	A2 \== bot,
	A2 \== inf.
log_expr(E1,E1,expr([],[factor([],1)])).
log_expr(E1,E2,expr([],[])) :-
	E1 \== E2,
	E2 = expr([],[factor([],I)]),
	I =:= 1,!.
log_expr(E1,E2,expr([],[factor([],F)])) :-
	E1 \== E2,
	E1 = expr([],[factor([],I1)]),
	E2 = expr([],[factor([],I2)]),!,
	F1 is float(I1),
	log2(F1,NF1),
	F2 is float(I2),
	log2(F2,NF2),
	F is NF2/NF1.
log_expr(E1,E2,expr([],[factor([log(E1,E2)],1)])) :-
	E1 \== E2.

%
%  compute the factorial of a normal-form expression.
%
factorial_expr(bot,bot).
factorial_expr(inf,inf).
factorial_expr(E,expr([],[factor([],1)])) :-
	E == expr([],[]),!.
factorial_expr(E,expr([],[factor([],1)])) :-
	E = expr([],[factor([],I)]),
	I =:= 1,!.
factorial_expr(E,expr([],[factor([fact(E)],1)])).

%
%  Insert an element into a list_cas based on standard order.
%
insert_order_list_cas([],I2,[I2]).
insert_order_list_cas([I1|Is],I2,[I2,I1|Is]) :-
	I1 @< I2.
insert_order_list_cas([I1|Is1],I2,[I1|Is]) :-
	I1 @> I2,
	insert_order_list_cas(Is1,I2,Is).
