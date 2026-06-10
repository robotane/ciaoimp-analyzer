%
%  utility.pl			Nai-Wei Lin			December, 1991
%
%  This file contains the utility procedures.
%

%
%  The following procedure perform arithmetic operations.
%

%
%  Performing the symbolic addition with bottom.
%
addition(A1,A2,A) :-
	number(A1),
	number(A2),
	A is A1+A2.
addition(bot,bot,bot).
addition(A1,bot,bot) :-
	A1 \== bot.
addition(bot,A2,bot) :-
	A2 \== bot.
addition(inf,inf,inf).
addition(A1,inf,inf) :-
	A1 \== inf,
	A1 \== bot.
addition(inf,A2,inf) :-
	A2 \== inf,
	A2 \== bot.
addition(A1,A2,A1) :-
	number(A2),
	A2 =:= 0,
	nonnumber(A1),
	A1 \== inf,
	A1 \== bot.
addition(A1,A2,A2) :-
	number(A1),
	A1 =:= 0,
	nonnumber(A2),
	A2 \== inf,
	A2 \== bot.
addition(A1,A2,A1+A2) :-
	A1 \== bot,
	A1 \== inf,
	nonnumber(A1),
	A2 \== bot,
	A2 \== inf,
	nonnumber(A2).
addition(A1,A2,A1+A2) :-
	number(A1),
	A1 =\= 0,
	A2 \== bot,
	A2 \== inf,
	nonnumber(A2).
addition(A1,A2,A1+A2) :-
	number(A2),
	A2 =\= 0,
	A1 \== bot,
	A1 \== inf,
	nonnumber(A1).

%
%  Performing the symbolic subtraction with bottom.
%
subtraction(A1,A2,A) :-
	number(A1),
	number(A2),
	A is A1-A2.
subtraction(bot,bot,bot).
subtraction(A1,bot,bot) :-
	A1 \== bot.
subtraction(bot,A2,bot) :-
	A2 \== bot.
subtraction(A1,A2,A1) :-
	number(A2),
	A2 =:= 0,
	nonnumber(A1),
	A1 \== bot.
subtraction(A1,A2,-A2) :-
	number(A1),
	A1 =:= 0,
	nonnumber(A2),
	A2 \== bot.
subtraction(A1,A2,A1-A2) :-
	nonnumber(A1),
	nonnumber(A2),
	A1 \== bot,
	A2 \== bot.
subtraction(A1,A2,A1-A2) :-
	number(A1),
	A1 =\= 0,
	nonnumber(A2),
	A2 \== bot.
subtraction(A1,A2,A1-A2) :-
	nonnumber(A1),
	A1 \== bot,
	number(A2),
	A2 =\= 0.

%
%  Performing the symbolic multiplication with bottom.
%
multiply(A1,A2,A) :-
	number(A1),
	number(A2),
	A is A1*A2.
multiply(bot,bot,bot).
multiply(A1,bot,bot) :-
	A1 \== bot.
multiply(bot,A2,bot) :-
	A2 \== bot.
multiply(inf,inf,inf).
multiply(A1,inf,inf) :-
	A1 \== inf,
	A1 \== bot.
multiply(inf,A2,inf) :-
	A2 \== inf,
	A2 \== bot.
multiply(A1,A2,A2) :-
	number(A2),
	A2 =:= 0,
	nonnumber(A1),
	A1 \== inf,
	A1 \== bot.
multiply(A1,A2,A1) :-
	number(A1),
	A1 =:= 0,
	nonnumber(A2),
	A2 \== inf,
	A2 \== bot.
multiply(A1,A2,A1) :-
	number(A2),
	A2 =:= 1,
	nonnumber(A1),
	A1 \== inf,
	A1 \== bot.
multiply(A1,A2,A2) :-
	number(A1),
	A1 =:= 1,
	nonnumber(A2),
	A2 \== inf,
	A2 \== bot.
multiply(A1,A2,A1*A2) :-
	A1 \== bot,
	A1 \== inf,
	nonnumber(A1),
	A2 \== bot,
	A2 \== inf,
	nonnumber(A2).
multiply(A1,A2,A1*A2) :-
	number(A1),
	A1 =\= 0,
	A1 =\= 1,
	A2 \== bot,
	A2 \== inf,
	nonnumber(A2).
multiply(A1,A2,A1*A2) :-
	number(A2),
	A2 =\= 0,
	A2 =\= 1,
	A1 \== bot,
	A1 \== inf,
	nonnumber(A1).

%
minus(bot,bot).
minus(inf,bot).
minus(X,Y) :-
	number(X),!,
	(X =:= 0 ->
		Y = 0;
		Y is -X).
minus(X,-X) :-
	/* not number(X), */
	X \== bot,
	X \== inf.

%
%  Performing the arithmetical addition with bottom.
%
add(bot,bot,bot).
add(A1,bot,bot) :-
	A1 \== bot.
add(bot,A2,bot) :-
	A2 \== bot.
add(A1,A2,A) :-
	A1 \== bot,
	A2 \== bot,
	A is A1+A2.

%
%  Performing the arithmetical subtraction with bottom.
%
sub(bot,bot,bot).
sub(A1,bot,bot) :-
	A1 \== bot.
sub(bot,A2,bot) :-
	A2 \== bot.
sub(A1,A2,A) :-
	A1 \== bot,
	A2 \== bot,
	A is A1-A2.

%
%  Performing the arithmetic maximum function.
%
max(N,M,N) :-
	N >= M.
max(N,M,M) :-
	N < M.

%
%  Performing the arithmetic minimum function.
%
min(N,M,N) :-
	N < M.
min(N,M,M) :-
	N >= M.

%
%  Performing the maximum function with top, bottom, infinite and negative
%  infinite.
%
maximum(N,M,S) :-
	number(N),
	number(M),
	max(N,M,S).
maximum(_,top,top).
maximum(top,M,top) :-
	M \== top.
maximum(N,bot,N) :-
	N \== top.
maximum(bot,M,M) :-
	M \== top,
	M \== bot.
maximum(N,inf,inf) :-
	N \== top,
	N \== bot.
maximum(inf,M,inf) :-
	M \== top,
	M \== bot,
	M \== inf.
maximum(N,neginf,N) :-
	N \== top,
	N \== bot,
	N \== inf.
maximum(neginf,M,M) :-
	M \== top,
	M \== bot,
	M \== inf,
	M \== neginf.
maximum(N,N,N) :-
	N \== top,
	N \== bot,
	N \== inf,
	N \== neginf,
	nonnumber(N).
maximum(N,M,S) :-
	N \== M,
	N \== top,
	N \== bot,
	N \== inf,
	N \== neginf,
	M \== top,
	M \== bot,
	M \== inf,
	M \== neginf,
	(nonnumber(N);
	 nonnumber(M)),
	S = (max(N,M)).

%
%  Performing the minimum function with top, bottom, infinite and negative
%  infinite.
%
minimum(N,M,S) :-
	integer(N),
	integer(M),
	min(N,M,S).
minimum(_,top,top).
minimum(top,M,top) :-
	M \== top.
minimum(N,bot,N) :-
	N \== top.
minimum(bot,M,M) :-
	M \== top,
	M \== bot.
minimum(N,inf,N) :-
	N \== top,
	N \== bot.
minimum(inf,M,M) :-
	M \== top,
	M \== bot,
	M \== inf.
minimum(N,neginf,neginf) :-
	N \== top,
	N \== bot,
	N \== inf.
minimum(neginf,M,neginf) :-
	M \== top,
	M \== bot,
	M \== inf,
	M \== neginf.
minimum(N,N,N) :-
	N \== top,
	N \== bot,
	N \== inf,
	N \== neginf,
	noninteger(N).
minimum(N,M,S) :-
	N \== M,
	N \== top,
	N \== bot,
	N \== inf,
	N \== neginf,
	M \== top,
	M \== bot,
	M \== inf,
	M \== neginf,
	(noninteger(N)-> S = min(N,M);
	 (noninteger(M)-> S = (min(N,M)))).

%
%  The following precedures perform list_cas operations.
%

%
%  Close a partial list_cas.
%
close_list_cas(List) :-
	var(List),
	List = [].
close_list_cas(List) :-
	nonvar(List),
	List = [_|VList],
	close_list_cas(VList).

%
%  Test the member_casship of an element in a list_cas.
%
member_cas([],_) :- fail.
member_cas([E|_],Ele) :-
	E == Ele.
member_cas([E|List],Ele) :-
	E \== Ele,
	member_cas(List,Ele).

%
%  Get the ith element in the list_cas.
%
ith_list_cas_element(_,List,_) :-
	var(List),
	fail.
ith_list_cas_element(_,List,_) :-
	nonvar(List),
	List == [],
	fail.
ith_list_cas_element(I,List,Element) :-
	I > 1,
	nonvar(List),
	List = [_|L],
	I1 is I-1,
	ith_list_cas_element(I1,L,Element).
ith_list_cas_element(1,List,Element) :-
	nonvar(List),
	List = [Element|_].

%
%  Select the set of elements in a list_cas according to a given number list_cas
%  that specifies the order of the desired elements in the list_cas.
%
select_list_cas_elements([],_,[]).
select_list_cas_elements([N|NumList],List,[E|EleList]) :-
	ith_list_cas_element(N,List,E),
	select_list_cas_elements(NumList,List,EleList).

%
%  Append two list_cass into a list_cas.
%
append_cas([],L,L).
append_cas([H|L1],L2,[H|L3]) :-
	append_cas(L1,L2,L3).

%
%  The following precedures perform queue operations.
%

%
%  Initialize a queue.
%
init_queue(QHead,QHead).


%
%  Test if a queue is empty.
%
empty_queue(QHead,QTail) :-
	QHead == QTail.

%
%  Test if a queue is nonempty.
%
nonempty_queue(QHead,QTail) :-
	QHead \== QTail.

%
%  Get an element from a queue.
%
get_queue([Pos|QHead],Pos,QHead).

%
%  Put an element into a queue.
%
put_queue([Pos|QTail],Pos,QTail).

%
%  Put a set of elements into a queue.
%
set_put_queue(QTail,List,QTail) :-
	var(List).
set_put_queue(QTail,List,QTail) :-
	nonvar(List),
	List = [].
set_put_queue(QTail,List,NTail) :-
	nonvar(List),
	List = [Ele|NList],
	put_queue(QTail,Ele,QTail1),
	set_put_queue(QTail1,NList,NTail).

%
%  Print out the elements in a queue.
%
print_queue(QHead,QTail) :-
	empty_queue(QHead,QTail).
print_queue(QHead,QTail) :-
	nonempty_queue(QHead,QTail),
	get_queue(QHead,Pos,NHead),
	write(Pos),nl,
	print_queue(NHead,QTail).

%
%  The following precedures perform stack operations.
%

%
%  Test if a stack is empty.
%
empty_stack([]).

%
%  Test if a stack is nonempty.
%
nonempty_stack(Stack) :-
	Stack \== [].

%
%  Push an element into a stack.
%
push(Stack,Element,[Element|Stack]).

%
%  Pop an element out of a stack.
%
pop([],_,[]).
pop([Element|Stack],Element,Stack).

%
%  The following precedures perform set operations.
%

%
%  Test if two opened sets Set1 and Set2 are equivalent.
%
opened_set_equivalent(Set1,Set2) :-
	opened_set_inclusion(Set1,Set2),
	opened_set_inclusion(Set2,Set1).

%
%  Test if opened set Set1 is included in opened set Set2.
%
opened_set_inclusion(Set1,_) :-
	var(Set1).
opened_set_inclusion(Set1,Set2) :-
	nonvar(Set2),
	nonvar(Set1),
	Set1 = [E|S1],
	opened_set_member_cas(Set2,E),
	opened_set_inclusion(S1,Set2).
		
%
%  Test if E is an element of an opened set Set.
%
opened_set_member_cas(Set,E) :-
	nonvar(Set),
	Set = [E1|S1],
	(E == E1 ->
		true;
		opened_set_member_cas(S1,E)).

%
%  Insert an element into an opened set represented by a non-ordered partial 
%  list_cas.
%
opened_set_insertion(Set,Ele) :-
	var(Set),!,
	Set = [Ele|_].
opened_set_insertion(Set,Ele) :-
	nonvar(Set),
	Set = [Ele1|Set1],
	(Ele == Ele1 ->
		true;
		opened_set_insertion(Set1,Ele)).

%
%  Perform the union of a closed set and an opened set.
%
opened_set_union([],_).
opened_set_union([Ele|Set1],Set2) :-
	opened_set_insertion(Set2,Ele),
	opened_set_union(Set1,Set2).

%
%  Get the intersection of two sets.
%
intersection([],_,[]).
intersection([X|S1],S2,S) :-
	(member_cas(S2,X) ->
		S = [X|SList];
		S = SList),
	intersection(S1,S2,SList).

union([],S,S).
union([X|S1],S2,S) :-
	(member_cas(S2,X) ->
		S = SList;
		S = [X|SList]),
	union(S1,S2,SList).

%
%  The following are predicate procedures.
%

%
%  Test if a term is compound_cas.
%
compound_cas(Term) :-
	nonvar(Term),
	functor(Term,_,N),
	N > 0.

%
%  Test if a term is noncompound_cas.
%
noncompound_cas(Term) :-
	var(Term).
noncompound_cas(Term) :-
	atomic(Term).

%
%  Test if a term is noninteger.
%
noninteger(Term) :-
	var(Term).
noninteger(Term) :-
	compound_cas(Term).
noninteger(Term) :-
	atom(Term).
noninteger(Term) :-
	float(Term).

%
%  Test if a term is nonnumber.
%
nonnumber(Term) :-
	var(Term).
nonnumber(Term) :-
	compound_cas(Term).
nonnumber(Term) :-
	atom(Term).

%
%  Test if a term is a list_cas.
%
list_cas([]).
list_cas([_|_]).

%
%  Test if a term is nonlist_cas.
%
nonlist_cas(Term) :-
	var(Term).
nonlist_cas(Term) :-
	atomic(Term),
	Term \== [].
nonlist_cas(Term) :-
	compound_cas(Term),
	functor(Term,F,N),
	F/N \== '.'/2.

%
%  Test if a term is nonsequence.
%
nonsequence(Term) :-
	var(Term).
nonsequence(Term) :-
	functor(Term,F,N),
	F/N \== '.'/2.

%
%  Test if a term is ground.
%
/*
ground(Term) :-
	atomic(Term).
ground(Term) :-
	compound_cas(Term),
	functor(Term,_,N),
	ground(N,Term).

ground(0,_).
ground(N,Term) :-
	N > 0,
	arg(N,Term,Arg),
	ground(Arg),
	N1 is N-1,
	ground(N1,Term).
*/

%
%  Test if a term is a subterm of another term.
%
subterm(Term,Term).
subterm(Sub,Term) :-
	Sub \== Term,
	compound_cas(Term),
	functor(Term,_,N),
	subterm(N,Sub,Term).

subterm(N,Sub,Term) :-
	N > 1,
	N1 is N-1,
	subterm(N1,Sub,Term).
subterm(N,Sub,Term) :-
	arg(N,Term,Arg),
	subterm(Sub,Arg).


%
% length_list compute the length of list
%

length_list([],0).
length_list([_|Ys],S):- length_list(Ys,Y),S is 1+Y.
