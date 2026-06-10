%
%  callgraph.pl			Nai-Wei Lin			November, 1991
%
%  This file contains the procedures for handling the call graph.
%  
%  The structure of the call graph:
%	cg(Pred/Arity,edge,number,component).
%

%
%  Insert an entry Entry for predicate Pred in call graph CG.
%  If it is already in, return the entry as Entry; 
%  otherwise an entry is inserted and returned.
%
/*
insert_call_entry(CG,Pred,Entry) :-
	var(CG),
	Entry = cg(Pred,_,_,_),
	CG = [Entry|_].
insert_call_entry(CG,Pred,Entry) :-
	nonvar(CG),
	CG = [Entry|_],
	Entry = cg(Pred,_,_,_).
insert_call_entry(CG,Pred,Entry) :-
	nonvar(CG),
	CG = [E|G],
	E \== cg(Pred,_,_,_),
	insert_call_entry(G,Pred,Entry).
*/
insert_call_entry(CG,Pred,Entry):-
  (var(CG) ->
      ( Entry=cg(Pred,_,_,_), CG = [Entry|_]);
	(nonvar(CG) -> 
	    (CG = [E|G],
	    (E = cg(Pred,_,_,_) ->
		Entry=E;
		(E \== cg(Pred,_,_,_) ->
		      insert_call_entry(G,Pred,Entry)
		  )
	      )
	  )
      )
  ).


%
%  Insert a literal into the edge field of the call graph.
%
insert_call_field(CG,Pred,edge,Lit) :-
	insert_call_entry(CG,Pred,cg(Pred,EdgeList,_,_)),
	insert_call_edge(EdgeList,Lit).

insert_call_edge(EdgeList,Lit) :-
	var(EdgeList),
	EdgeList = [Lit|_].
insert_call_edge(EdgeList,Lit) :-
	nonvar(EdgeList),
	EdgeList = [Lit|_].
insert_call_edge(EdgeList,Lit) :-
	nonvar(EdgeList),
	EdgeList = [E|Edge],
	E \== Lit,
	insert_call_edge(Edge,Lit).

%
%  Insert a DFS number into the number field of the call graph.
%
insert_call_field_number(CG,Pred,number,DFSNumber) :-

	insert_call_entry(CG,Pred,cg(Pred,_,DFSNumber,_)).

%
%  Insert a component number into the component field of the call graph.
%
insert_call_field_component(CG,Pred,component,Component) :-

%	write('\nCG='),write(CG),write('\nPred='),write(Pred),write('\nComponent='),write(Component),
	insert_call_entry(CG,Pred,cg(Pred,_,_,Component)).


%
%  Find the entry for predicate Pred in call graph.
%  If it is in, return the entry as Entry; 
%  otherwise Entry is returned as a variable.
%
/*
find_call_entry(CG,_,_) :-
	var(CG).
find_call_entry(CG,Pred,Entry) :-
	nonvar(CG),
	CG = [Entry|_],
	Entry = cg(Pred,_,_,_).
find_call_entry(CG,Pred,Entry) :-
	nonvar(CG),
	CG = [E|G],
	E \== cg(Pred,_,_,_),
	find_call_entry(G,Pred,Entry).
*/

find_call_entry(CG,Pred,Entry) :-
	(var(CG) -> !;
	    (nonvar(CG) ->
		(CG = [E|G],
		(E=cg(Pred,_,_,_) ->
		    Entry=E;
		    (E \== cg(Pred,_,_,_) ->
			find_call_entry(G,Pred,Entry)
		    )
		)
	    )
	)
    ).



%
%  Find a field for the predicate Pred in call graph.
%

find_call_field(CG,Pred,edge,EdgeList) :-
	find_call_entry(CG,Pred,cg(Pred,EdgeList,_,_)).
find_call_field(CG,Pred,number,DFSNumber) :-
	find_call_entry(CG,Pred,cg(Pred,_,DFSNumber,_)).
find_call_field(CG,Pred,component,Component) :-
	find_call_entry(CG,Pred,cg(Pred,_,_,Component)).

%
%  Find an entry in call graph which has not instantiated its number field.
%  If there is such an entry, return the name of the predicate as Pred;
%  otherwise Pred is returned as a variable.
%
find_call_vertex(CG,_) :-
	var(CG).
find_call_vertex(CG,Pred) :-
	nonvar(CG),
	CG = [cg(Pred,_,DFSNumber,_)|_],
	var(DFSNumber).
find_call_vertex(CG,Pred) :-
	nonvar(CG),
	CG = [cg(_,_,DFSNumber,_)|G],
	nonvar(DFSNumber),
	find_call_vertex(G,Pred).

%
%  Print out the call graph.
%
/*
print_call_graph(CG) :-
	tell(call_graph),
	p_call_graph(CG),
	told.

p_call_graph(CG) :-
	var(CG).
p_call_graph(CG) :-
	nonvar(CG),
	CG = [E|G],
	write(E),
	nl,
	p_call_graph(G).

*/
