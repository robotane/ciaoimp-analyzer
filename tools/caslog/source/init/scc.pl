%
%  scc.pl			Nai-Wei Lin			November, 1991
%
%  This file contains the procedures for finding the strongly connected
%  components of the call graph.
%  These procedures are based on the algorithm in Udi Manber's book
%  "Introduction to Algorithms - A Creative Approach", page 231.
%

%
%  Find the strongly connected components of the call graph.
%
strongly_connected_component(CG,SCCG) :-
	strongly_connected_component(CG,SCCG,[],-1,_,0,_,[],_).

strongly_connected_component(CG,SCCG,NewSCCG,DFS_N,NewDFS_N,
			     Component,New_Component,Stack,NewStack) :-
	find_call_vertex(CG,V),
	(var(V) ->
		SCCG = NewSCCG;
		(scc(V,CG,SCCG,SCCG1,DFS_N,DFS_N1,Component,Component1,
		    Stack,Stack1,_), 
		 strongly_connected_component(CG,SCCG1,NewSCCG,DFS_N1,NewDFS_N,
			     Component1,New_Component,Stack1,NewStack))).

%
%  Investigate a vertex.
%
scc(V,CG,SCCG,NewSCCG,DFS_N,NewDFS_N,Component,NewComponent,Stack,NewStack,
    VHigh) :- 
	insert_call_field_number(CG,V,number,DFS_N),
	DFS_N1 is DFS_N-1,
	push(Stack,V,Stack1),  
	find_call_field(CG,V,edge,EdgeList),
	scc_edges(EdgeList,V,DFS_N,VHigh,CG,SCCG,SCCG1,DFS_N1,NewDFS_N,
		  Component,Component1,Stack1,Stack2),
	generate_new_component(VHigh,DFS_N,V,CG,SCCG1,NewSCCG,Component1,
			       NewComponent,Stack2,NewStack).

%
%  Investigate all the edges out of a vertex.
%
scc_edges(EdgeList,_,VHigh,VHigh,_,SCCG,SCCG,DFS_N,DFS_N,
	  Component,Component,Stack,Stack) :-
	var(EdgeList).
scc_edges(EdgeList,V,VHigh,NewVHigh,CG,SCCG,NewSCCG,DFS_N,NewDFS_N,
	  Component,NewComponent,Stack,NewStack) :-
	nonvar(EdgeList),
	EdgeList = [W|Edge],
	find_call_field(CG,W,number,WDFSNumber),
	find_call_field(CG,W,component,WComponent),
	scc_edge(W,WDFSNumber,WComponent,VHigh,VHigh1,CG,SCCG,SCCG1,
		 DFS_N,DFS_N1,Component,Component1,Stack,Stack1),
	scc_edges(Edge,V,VHigh1,NewVHigh,CG,SCCG1,NewSCCG,DFS_N1,NewDFS_N,
	  	  Component1,NewComponent,Stack1,NewStack).

%
%  Investigate a single edge out of a vertex.
%
scc_edge(W,WDFSNumber,_,VHigh,NewVHigh,CG,SCCG,NewSCCG,DFS_N,NewDFS_N,
	 Component,NewComponent,Stack,NewStack) :-
	var(WDFSNumber),
	scc(W,CG,SCCG,NewSCCG,DFS_N,NewDFS_N,Component,NewComponent,
	    Stack,NewStack,WHigh),
	max(VHigh,WHigh,NewVHigh).
scc_edge(_,WDFSNumber,WComponent,VHigh,NewVHigh,_,SCCG,SCCG,DFS_N,DFS_N,
	 Component,Component,Stack,Stack) :-
	nonvar(WDFSNumber),
	var(WComponent),
	max(VHigh,WDFSNumber,NewVHigh).
scc_edge(_,WDFSNumber,WComponent,VHigh,VHigh,_,SCCG,SCCG,DFS_N,DFS_N,
	 Component,Component,Stack,Stack) :-
	nonvar(WDFSNumber),
	nonvar(WComponent).

%
%  Generate a new component.
%
generate_new_component(VHigh,VDFSNumber,_,_,SCCG,SCCG,Component,Component,
		       Stack,Stack) :-
	VHigh =\= VDFSNumber.
generate_new_component(VHigh,VHigh,V,CG,[G|SCCG],SCCG,Component,
		       NewComponent,Stack,NewStack) :-
	NewComponent is Component+1,
	gen_new_component(V,CG,G,NewComponent,Stack,NewStack).

%
%  Collect the elements in the component by popping them
%  out of the stack.
%
gen_new_component(V,CG,G,Component,Stack,NewStack) :-

	pop(Stack,Element,Stack1),
	
	insert_call_field_component(CG,Element,component,Component),
	G = [Element|G1],
	(Element == V ->
		(NewStack = Stack1,
		 G1 = []);
		gen_new_component(V,CG,G1,Component,Stack1,NewStack)).

%
%  Print out the strongly connected components of the call graph.
%
/*
print_scc_list_cas(SCCG) :-
	tell(scc_list_cas),
	p_scc_list_cas(SCCG),
	told.

p_scc_list_cas([]).
p_scc_list_cas([Component|SCCG]) :-
	write(Component),
	nl,
	p_scc_list_cas(SCCG).
*/
