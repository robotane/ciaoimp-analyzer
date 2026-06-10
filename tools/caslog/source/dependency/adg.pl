%
%  adg.pl			Nai-Wei Lin			November, 1991
%
%  This file contains the procedures for manipulating the argument
%  dependency graph.
%
%  The structure of the argument dependency graph:
%	adg(Pos,pred,succ,mode)
%

%
%  Insert an entry for argument position Pos in the argument dependency graph.
%  If it is already in, return the entry as Entry;
%  otherwise, an entry Entry for Pos is inserted and returned.
%
insert_adg_entry(Adg,Pos,Entry) :- 
	var(Adg),
	Entry = adg(Pos,_,_,_),
	Adg = [Entry|_].

insert_adg_entry(Adg,Pos,Entry) :- 
	nonvar(Adg),
	Adg = [Entry|_],
	Entry = adg(Pos,_,_,_).

insert_adg_entry(Adg,Pos,Entry) :- 
	nonvar(Adg),
	Adg = [adg(P,_,_,_)|A],
	P \== Pos,
	insert_adg_entry(A,Pos,Entry).


%
%  Insert an edge for argument position Pos into the argument dependency
%  graph.
%
/*insert_adg_field(Adg,Pos,pred,Edge) :-
	insert_adg_entry(Adg,Pos,adg(Pos,EdgeList,_,_)),
	insert_adg_edge(EdgeList,Edge).
insert_adg_field(Adg,Pos,succ,Edge) :-
	insert_adg_entry(Adg,Pos,adg(Pos,_,EdgeList,_)),
	insert_adg_edge(EdgeList,Edge).
insert_adg_field(Adg,Pos,(mode),Mode) :-
	insert_adg_entry(Adg,Pos,adg(Pos,_,_,Mode)).*/

insert_adg_field(Adg,Pos,Type,Edge) :-
	(Type==pred ->
	    (
		insert_adg_entry(Adg,Pos,adg(Pos,EdgeList,_,_)),
		insert_adg_edge(EdgeList,Edge)
	    );
	    (Type==succ ->
		(
		    insert_adg_entry(Adg,Pos,adg(Pos,_,EdgeList,_)),
		    insert_adg_edge(EdgeList,Edge)
		);
		(Type==(mode) ->
		    (
		    insert_adg_entry(Adg,Pos,adg(Pos,_,_,Edge)))
		))).


insert_adg_edge(EdgeList,Edge) :-
	var(EdgeList),
	EdgeList = [Edge|_].
insert_adg_edge(EdgeList,Edge) :-
	nonvar(EdgeList),
	EdgeList = [Edge|_].
insert_adg_edge(EdgeList,Edge) :-
	nonvar(EdgeList),
	EdgeList = [E|EList],
	E \== Edge,
	insert_adg_edge(EList,Edge).

%
%  Find the entry for argument position Pos in the argument dependency graph.
%  If it is in, return the entry as Entry;
%  otherwise, Entry is returned as a variable.
%
find_adg_entry(Adg,_,_) :- 
	var(Adg).
find_adg_entry(Adg,Pos,Entry) :- 
	nonvar(Adg),
	Adg = [Entry|_],
	Entry = adg(Pos,_,_,_).
find_adg_entry(Adg,Pos,Entry) :- 
	nonvar(Adg),
	Adg = [adg(P,_,_,_)|A],
	P \== Pos,
	find_adg_entry(A,Pos,Entry).

%
%  Find a field for argument position Pos in the argument dependency graph.
%
/*
find_adg_field(Adg,Pos,pred,EdgeList) :-
	find_adg_entry(Adg,Pos,adg(Pos,EdgeList,_,_)).
find_adg_field(Adg,Pos,succ,EdgeList) :-
	find_adg_entry(Adg,Pos,adg(Pos,_,EdgeList,_)).
find_adg_field(Adg,Pos,(mode),Mode) :-
	find_adg_entry(Adg,Pos,adg(Pos,_,_,Mode)).
*/

find_adg_field(Adg,Pos,Type,Mode) :-
	(Type==pred ->
	    find_adg_entry(Adg,Pos,adg(Pos,Mode,_,_));
	    (Type==succ ->
		find_adg_entry(Adg,Pos,adg(Pos,_,Mode,_));
		(Type==(mode) ->
		    find_adg_entry(Adg,Pos,adg(Pos,_,_,Mode))
		)
	    )
	).

%
%  Print out the argument dependency graph.
%
/*
print_adg(Adg) :-
	tell(adg),
	p_adg(Adg),
	told.

p_adg([]).
p_adg([E|Adg]) :-
	write(E),
	nl,
	p_adg(Adg).
*/
