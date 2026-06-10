%
%  ldg.pl			Nai-Wei Lin			November, 1991
%
%  This file contains the procedures for manipulating the literal
%  dependency graph.
%
%  The structure of the literal dependency graph:
%	ldg(Lit,edge)
%

%
%  Insert an entry for literal Lit in the literal dependency graph.
%  If it is already in, return the entry as Entry;
%  otherwise, an entry Entry for Lit is inserted and returned.
%
insert_ldg_entry(Ldg,Lit,Entry) :- 
	var(Ldg),
	Entry = ldg(Lit,_,_,_,_,_,_),
	Ldg = [Entry|_].
insert_ldg_entry(Ldg,Lit,Entry) :- 
	nonvar(Ldg),
	Ldg = [Entry|_],
	Entry = ldg(Lit,_,_,_,_,_,_).
insert_ldg_entry(Ldg,Lit,Entry) :- 
	nonvar(Ldg),
	Ldg = [ldg(Lit1,_,_,_,_,_,_)|L],
	Lit \== Lit1,
	insert_ldg_entry(L,Lit,Entry).

%
%  Insert an edge for literal Lit into the literal dependency
%  graph.
%
insert_ldg_field(Ldg,Lit,pred,Edge) :-
	insert_ldg_entry(Ldg,Lit,ldg(Lit,Pred,_,_,_,_,_)),
	insert_ldg_edge(Pred,Edge).
insert_ldg_field(Ldg,Lit,succ,Edge) :-
	insert_ldg_entry(Ldg,Lit,ldg(Lit,_,Succ,_,_,_,_)),
	insert_ldg_edge(Succ,Edge).
insert_ldg_field(Ldg,Lit,relation,Sol) :-
	insert_ldg_entry(Ldg,Lit,ldg(Lit,_,_,Sol,_,_,_)).
insert_ldg_field(Ldg,Lit,det,Sol) :-
        insert_ldg_entry(Ldg,Lit,ldg(Lit,_,_,_,Sol,_,_)).
insert_ldg_field(Ldg,Lit,redge,Maxv) :-
	insert_ldg_entry(Ldg,Lit,ldg(Lit,_,_,_,_,Maxv,_)).
insert_ldg_field(Ldg,Lit,sedge,Maxv) :-
	insert_ldg_entry(Ldg,Lit,ldg(Lit,_,_,_,_,_,Maxv)).

insert_ldg_edge(EdgeList,Edge) :-
	var(EdgeList),
	EdgeList = [Edge|_].
insert_ldg_edge(EdgeList,Edge) :-
	nonvar(EdgeList),
	EdgeList = [Edge|_].
insert_ldg_edge(EdgeList,Edge) :-
	nonvar(EdgeList),
	EdgeList = [E|EList],
	E \== Edge,
	insert_ldg_edge(EList,Edge).

%
%  Find the entry for literal Lit in the literal dependency graph.
%  If it is in, return the entry as Entry;
%  otherwise, Entry is returned as a variable.
%
find_ldg_entry(Ldg,_,_) :- 
	var(Ldg).
find_ldg_entry(Ldg,Lit,Entry) :- 
	nonvar(Ldg),
	Ldg = [Entry|_],
	Entry = ldg(Lit,_,_,_,_,_,_).
find_ldg_entry(Ldg,Lit,Entry) :- 
	nonvar(Ldg),
	Ldg = [ldg(Lit1,_,_,_,_,_,_)|L],
	Lit \== Lit1,
	find_ldg_entry(L,Lit,Entry).

%
%  Find a field for literal Lit in the literal dependency graph.
%
find_ldg_field(Ldg,Lit,pred,Pred) :-
	find_ldg_entry(Ldg,Lit,ldg(Lit,Pred,_,_,_,_,_)).
find_ldg_field(Ldg,Lit,succ,Succ) :-
	find_ldg_entry(Ldg,Lit,ldg(Lit,_,Succ,_,_,_,_)).
find_ldg_field(Ldg,Lit,relation,Sol) :-
	find_ldg_entry(Ldg,Lit,ldg(Lit,_,_,Sol,_,_,_)).
find_ldg_field(Ldg,Lit,det,Sol) :-
	find_ldg_entry(Ldg,Lit,ldg(Lit,_,_,_,Sol,_,_)).
find_ldg_field(Ldg,Lit,redge,Maxv) :-
	find_ldg_entry(Ldg,Lit,ldg(Lit,_,_,_,_,Maxv,_)).
find_ldg_field(Ldg,Lit,sedge,Maxv) :-
	find_ldg_entry(Ldg,Lit,ldg(Lit,_,_,_,_,_,Maxv)).

%
%  Create a new literal.
%
new_lit(LitNum,'$'(LitNum)).

%
%  Print out the literal dependency graph.
%
/*
print_ldg(Ldg) :-
	tell(ldg),
	p_ldg(Ldg),
	told.

p_ldg([]).
p_ldg([E|Ldg]) :-
	write(E),
	nl,
	p_ldg(Ldg).
*/
