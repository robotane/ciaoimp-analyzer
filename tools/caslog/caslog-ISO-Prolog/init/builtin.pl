%
%  builtin.pl			Nai-Wei Lin			December, 1991
%
%  This file contains the procedures for initializing builtin table.
%
%  The structure of the builtin table:
%	st(Pred/Arity,clause,mode,measure,mutex,det,size,solution,time,domain)
%

%
%  Initialize the buildin table.
%
init_buildin_table(BT) :-
	insert_symbol_entry(BT,(is)/2,st((is)/2,_,[-,+],[int,int],_,[1],[],
			    inf,[0],_)),
%	insert_symbol_entry(BT,(=)/2,st((=)/2,_,[(?),(?)],[(?),(?)],_,[1],[],
%			    inf,[0],_)),
	insert_symbol_entry(BT,functor/3,st(functor/3,_,[+,-,-],
			    [size,size,int],_,[1],[],inf,[0],_)),
	insert_symbol_entry(BT,arg/3,st(arg/3,_,[+,+,-],
			    [int,size,size],_,[1],[],inf,[0],_)),
	insert_symbol_entry(BT,functor1/3,st(functor1/3,_,[-,+,+],
			    [size,size,int],_,[1],[],inf,[0],_)),
	insert_symbol_entry(BT,arg/4,st(arg/4,_,[+,+,+,-],
			    [int,size,size,size],_,[1],[],inf,[0],_)),
%	insert_symbol_entry(BT,(=..)/2,st((=..)/2,_,[+,-],
%			    [size,length],_,[1],[],inf,[0],_)),
	insert_symbol_entry(BT,(==)/2,st((==)/2,_,[+,+],[(?),(?)],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,(\==)/2,st((\==)/2,_,[+,+],[(?),(?)],_,[1],_,
			    inf,[0],_)),
	insert_symbol_entry(BT,(=:=)/2,st((=:=)/2,_,[+,+],[int,int],_,[1],_,
			    inf,[0],_)),
	insert_symbol_entry(BT,(=\=)/2,st((=\=)/2,_,[+,+],[int,int],_,[1],_,
			    inf,[0],_)),
	insert_symbol_entry(BT,(<)/2,st((<)/2,_,[+,+],[int,int],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,(>)/2,st((>)/2,_,[+,+],[int,int],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,(=<)/2,st((=<)/2,_,[+,+],[int,int],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,(>=)/2,st((>=)/2,_,[+,+],[int,int],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,atomic/1,st(atomic/1,_,[+],[void],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,atom/1,st(atom/1,_,[+],[void],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,number/1,st(number/1,_,[+],[void],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,integer/1,st(integer/1,_,[+],[void],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,float/1,st(float/1,_,[+],[void],_,[1],_,inf,[0],_)),
%	insert_symbol_entry(BT,var/1,st(var/1,_,[+],[void],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,nonvar/1,st(nonvar/1,_,[+],[void],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,write/1,st(write/1,_,[+],[void],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,tab/1,st(tab/1,_,[+],[void],_,[1],_,inf,[0],_)),
	insert_symbol_entry(BT,nl/0,st(nl/0,_,[],[],_,[1],_,1,[0],_)),
	insert_symbol_entry(BT,fail/0,st(fail/0,_,[],[],_,[0],_,0,[0],_)),
	insert_symbol_entry(BT,true/0,st(true/0,_,[],[],_,[1],_,1,[0],_)),
	insert_symbol_entry(BT,(!)/0,st((!)/0,_,[],[],_,[1],_,1,[0],_)),
	insert_symbol_entry(BT,findall/3,st(findall/3,_,[-,+,-],[void,void,length],_,[1],_,inf,[0],_)).

second_order_predicate(findall/3).

second_order_predicate_pred_arg(findall(_,P,_),P).

second_order_predicate_pred_num(Body,LitNum,Num) :-
	number_of_literals(Body,1,Num1),
	Num is Num1+LitNum.

legal_pred_arg(Pred) :-
	functor(Pred,F,N),
	F/N \== '.'/2,			% single literal
	\+ second_order_predicate(F/N).	% non-second-order predicate
%
%  Print out the buildin table.
%
print_buildin_table(BT) :-
	tell(buildin_table),
	p_buildin_table(BT),
	told.

p_buildin_table(BT) :-
	var(BT).
p_buildin_table(BT) :-
	nonvar(BT),
	BT = [E|B],
	write(E),
	nl,
	p_buildin_table(B).

