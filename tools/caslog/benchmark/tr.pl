%
%  tr.pl			Nai-Wei Lin			November 1991
%
%  This program traverses a tree in pre-order.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(append/3,[+,+,-]).
:- measure(append/3,[length,length,length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
append([],L,L).
append([X|L1],L2,[X|L3]) :-
	append(L1,L2,L3).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(pre_order/2,[+,-]).
:- measure(pre_order/2,[depth([2,3]),length]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pre_order(void,[]).
pre_order(tree(X,L,R),Xs) :-
	pre_order(L,Ls),
	pre_order(R,Rs),
	append([X|Ls],Rs,Xs).

