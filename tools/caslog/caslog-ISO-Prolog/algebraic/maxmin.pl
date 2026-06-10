%
%  maxmin.pl			Nai-Wei Lin			January, 1992
%
%  This file contains the procedures for performing maximum and minimum
%  functions in normal-form.
%

%
%  Perform the maximum function in normal-form.
%
max_expr(_,bot,bot).
max_expr(bot,E2,bot) :-
	E2 \== bot.
max_expr(E1,inf,inf) :-
	E1 \== bot.
max_expr(inf,E2,inf) :-
	E2 \== bot,
	E2 \== inf.
max_expr(E1,E2,E) :-
	Minus1 is -1,
	normal_form(Minus1,Y1),
	multiply_expr(Y1,E2,Y2),
	add_expr(E1,Y2,Y),
	max_sign_expr(E1,E2,Y,E).

%
%  Determine the maximum based on the sign of the difference.
%

/*
max_sign_expr(E1,_,Y,E1) :-
	positive_expr(Y).
max_sign_expr(_,E2,Y,E2) :-
	negative_expr(Y).

max_sign_expr(E1,E2,Y,E) :-
	((positive_expr(Y);negative_expr(Y)) ->
		fail;
		(max_term_by_term(E1,E2,E))).
*/
max_sign_expr(E1,E2,Y,E) :-
	(positive_expr(Y) ->
	    E=E1;
	    (negative_expr(Y) ->
		E=E2;
		((positive_expr(Y);negative_expr(Y)) ->
		    fail;
		    (max_term_by_term(E1,E2,E))
		)
	    )
	).
	  


%
%  Perform the maximum function in normal-form.
%
min_expr(_,bot,bot).
min_expr(bot,E2,bot) :-
	E2 \== bot.
min_expr(E1,inf,E1) :-
	E1 \== bot.
min_expr(inf,E2,E2) :-
	E2 \== bot,
	E2 \== inf.
min_expr(E1,E2,E) :-
	Minus1 is -1,
	normal_form(Minus1,Y1),
	multiply_expr(Y1,E2,Y2),
	add_expr(E1,Y2,Y),
	min_sign_expr(E1,E2,Y,E).

%
%  Determine the minimum based on the sign of the difference.
%
/*
min_sign_expr(E1,_,Y,E1) :-
	negative_expr(Y).
min_sign_expr(_,E2,Y,E2) :-
	positive_expr(Y).
min_sign_expr(E1,E2,Y,E) :-
	((positive_expr(Y);negative_expr(Y)) ->
		fail;
		(ground_size(E1,S1),
		 ground_size(E2,S2),
		 (S1 =< S2 ->
			E = E1;
			E = E2))).
*/

min_sign_expr(E1,E2,Y,E) :-
	(negative_expr(Y) ->
	    E=E1;
	    (positive_expr(Y) ->
		E=E2;
		((positive_expr(Y);negative_expr(Y)) ->
		    fail;
		    (ground_size(E1,S1),
		    ground_size(E2,S2),
		    (S1 =< S2 ->
			E = E1;
			E = E2)
		    )
		)
	    )
	).



%
%  Test if a normal-form expression is positive.
%
positive_expr(expr(T,F)) :-
	positive_terms(T),
	positive_factors(F).

%
%  Test if the normal-form terms are positive.
%
positive_terms([]).
positive_terms([term(_,F)|Ts]) :-
	positive_factors(F),
	positive_terms(Ts).

%
%  Test if the normal-form factors are positive.
%
positive_factors([]).
positive_factors([F|Fs]) :-
	positive_factor(F),
	positive_factors(Fs).

positive_factor(factor(I,C)) :-
	pos_factor(I,C).

pos_factor([],C) :-
	C > 0.
pos_factor([I|Is],C) :-
	positive_item(I),
	pos_factor(Is,C).

%
%  Test if a normal-form item is positive.
%
positive_item(V) :- variable(V).
positive_item(exp(_,expr([],[factor([],_)]))).
positive_item(exp(expr([],[factor([],C)]),_)) :-
	C > 0.

%
%  Test if a normal-form expression is negative.
%
negative_expr(expr(T,F)) :-
	negative_terms(T),
	negative_factors(F).

%
%  Test if the normal-form terms are negative.
%
negative_terms([]).
negative_terms([term(_,F)|Ts]) :-
	negative_factors(F),
	negative_terms(Ts).

%
%  Test if the normal-form factors are negative.
%
negative_factors([]).
negative_factors([F|Fs]) :-
	negative_factor(F),
	negative_factors(Fs).

negative_factor(factor(I,C)) :-
	neg_factor(I,C).

neg_factor([],C) :-
	C < 0.
neg_factor([I|Is],C) :-
	positive_item(I),
	neg_factor(Is,C).

%
%  Determine the maximum of two expressions term by term.
%
max_term_by_term(expr(T1,F1),expr(T2,F2),expr(T,F)) :-
	%nl,
	%write(T1),nl,
	%write(T2),nl,
	max_terms(T1,T2,T),
	%write(T),nl,
	max_factors(F1,F2,F).

%
max_terms([term([P1],C1)],[term([P2],C2)],Term) :-
	userfunc(P1), functor(P1,F,N),
	userfunc(P2), functor(P2,F,N),
	arg(1,P1,A), arg(1,P2,A), !,
	max_terms(N,P1,P2,C1,C2,Term).
max_terms(T1,T2,T) :-
	add_terms(T1,T2,T).

%
max_terms(_,P1,P2,C1,C2,[term([P1],C)]) :-
	P1 == P2,!,
	max_factors(C1,C2,C).
max_terms(Arity,P1,P2,C1,C2,[term([P1],C1)]) :-
	P1 \== P2,
	larger_terms(3,Arity,P1,P2),
	larger_factors(C1,C2),!.
max_terms(Arity,P1,P2,C1,C2,[term([P2],C2)]) :-
	P1 \== P2,
	larger_terms(3,Arity,P2,P1),
	larger_factors(C2,C1),!.
max_terms(_,P1,P2,C1,C2,T) :-
	P1 \== P2,
	add_terms([term([P1],C1)],[term([P2],C2)],T).

%
larger_terms(I,Arity,_,_) :-
	I > Arity.
larger_terms(I,Arity,P1,P2) :-
	I =< Arity,
	arg(Arity,P1,Arg1),
	arg(Arity,P2,Arg2),
	normal_form(-1,Minus1),
	multiply_expr(Minus1,Arg2,MArg2),
	add_expr(Arg1,MArg2,Arg),
	positive_expr(Arg),
	Arity1 is Arity-1,
	larger_terms(I,Arity1,P1,P2).
	
%
larger_factors(F1,F2) :-
	normal_form(-1,Minus1),
	multiply_expr(Minus1,expr([],F2),E2),
	add_expr(expr([],F1),E2,E),
	positive_expr(E).
	
%
max_factors(F1,F2,F) :-
	add_factors(F1,F2,F).
