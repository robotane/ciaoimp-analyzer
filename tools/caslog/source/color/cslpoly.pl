%
%  csl_poly.pl			Nai-Wei Lin			November 1990
%
%  This file contains the procedures for estimating the chromatic polynomial
%  of a graph.
%

/*********************************************************************
  Given a graph GRAPH, csl_poly(GRAPH,UPOLY,LPOLY,EXACT) returns the 
  upper bound UPOLY and lower bound LPOLY of the chromatic polynomial 
  beas on complete-smallest-last order. EXACT is 1 if the solution is
  exact solution, 0 otherwise.
 *********************************************************************/
csl_poly(Graph,Upoly,Lpoly,Exact) :-
	csl_order(Graph,Order,Exact),
	chro_poly(Graph,Order,Upoly,Lpoly).
%	output(Upoly,Lpoly).
/*********************************************************************
  Given a graph GRAPH, csl_oredr(GRAPH,CSLGRAPH) returns a graph 
  CSLGRAPH in complete-smallest-last order. The status STATUS is 1 
  if the order is complete; 0 otherwise.
 *********************************************************************/
csl_order(Graph,Cslgraph,St) :-
	csf_order(Graph,Csfgraph,1,St),
	gcp_reverse(Csfgraph,Cslgraph).

/*********************************************************************
  Given a graph GRAPH, csf_oredr(GRAPH,CSLGRAPH) returns a graph 
  CSFGRAPH in complete-smallest-first order. The status STATUS is 1 
  if the order is complete; 0 otherwise.
 *********************************************************************/
csf_order([],[],St,St).
csf_order(Graph,[Node|Nodes],St,FinalSt) :-
	iqsort(Graph,SortGraph),
	csf_node(SortGraph,Node,NewGraph,CurSt),
	NewSt is St*CurSt,
	csf_order(NewGraph,Nodes,NewSt,FinalSt).

/*********************************************************************
  iqsort(GRAPH,SORTGRAPH) applies quick sort to the graph GRAPH based 
  on the degrees of nodes and returns a graph SORTGRAPH in increasing
  order.
 *********************************************************************/
iqsort([],[]).
iqsort([N|Graph],SortGraph) :-
	split(N,Graph,Small,Large),
	iqsort(Small,Sgraph),
	iqsort(Large,Lgraph),
	append_cas(Sgraph,[N|Lgraph],SortGraph).

split(_,[],[],[]).
split(node(N,D,Node),[node(N1,D1,Node1)|Rest],[node(N1,D1,Node1)|S],L) :-
	D1 =< D,
	split(node(N,D,Node),Rest,S,L).
split(node(N,D,Node),[node(N1,D1,Node1)|Rest],S,[node(N1,D1,Node1)|L]) :-
	D1 > D,
	split(node(N,D,Node),Rest,S,L).

/*
append_cas([],L,L).
append_cas([H|L1],L2,[H|L3]) :-
	append_cas(L1,L2,L3).
*/

/*********************************************************************
  Given a graph GRAPH sorted in increasing order of degrees of nodes,
  csf_node(GRAPH,NODE,NEWGRAPH,STATUS) finds the node NODE in GRAPH 
  that has smallest degree and its corresponding interfacing subgraph 
  is complete, and returns a graph NEWGRAPH by deleting NODE from GRAPH.
  The status STATUS is 1 if the interfacing subgraph is complete; 0
  otherwise.
 *********************************************************************/
csf_node(Graph,Node,NewGraph,St) :-
	csf_node(Graph,Graph,Node,NewGraph,St).

csf_node([],[node(Name,D,Nodes)|Rest],node(Name,D,Nodes),NewGraph,0) :-
	gcp_delete(Name,Rest,NewGraph).
csf_node([node(Name,D,Nodes)|_],Graph,node(Name,D,Nodes),NewGraph,1) :-
	complete(Nodes,Graph),!,	
	gcp_delete(Name,Graph,NewGraph).
csf_node([_|Rest],Graph,Node,NewGraph,St) :-
	csf_node(Rest,Graph,Node,NewGraph,St).

/*********************************************************************
  complete(NODES,GRAPH) checks if the induced subgraph by NODES is 
  complete in graph GRAPH.
 *********************************************************************/
complete(Nodes,Graph) :-
	complete(Nodes,Nodes,Graph).

complete([],_,_).
complete([N|Rest],Nodes,Graph) :-
	join(N,Nodes,Graph),
	complete(Rest,Nodes,Graph).

/*********************************************************************
  join(NODE,NODES,GRAPH) checks if the node NODE joins all the nodes 
  of NODES-{NODE} in graph GRAPH.
 *********************************************************************/
join(Node,Nodes,[node(Node,_,Adj)|_]) :-
	!,subset(Node,Nodes,Adj).
join(Node,Nodes,[_|Rest]) :-
	join(Node,Nodes,Rest).

/*********************************************************************
  subset(N,SET1,SET2) checks if the set SET1-{N} is a subset of the
  set SET2.
 *********************************************************************/
subset(_,[],_).
subset(N,[N|SET1],SET2) :-
	subset(N,SET1,SET2).
subset(N,[M|SET1],SET2) :-
	N \== M,
	gcp_member_cas(M,SET2),
	subset(N,SET1,SET2).

/*********************************************************************
  gcp_member_cas(N,SET) checks the member_casship of N in a set SET.
 *********************************************************************/
gcp_member_cas(N,[N|_]) :- !.
gcp_member_cas(N,[M|Rest]) :-
	N \== M,
	gcp_member_cas(N,Rest).

/*********************************************************************
  gcp_delete(NAME,GRAPH,NEWGRAPH) deletes a node named NAME from a graph 
  GRAPH and returns the resultant graph NEWGRAPH.
 *********************************************************************/
gcp_delete(_,[],[]).
gcp_delete(Name,[node(Name,_,_)|Graph],NewGraph) :-
	gcp_delete(Name,Graph,NewGraph).
gcp_delete(Name,[node(N,D,Nodes)|Graph],[node(N,NewDeg,NewNodes)|NewGraph]) :-
	Name \== N,
	remove(Name,Nodes,D,NewNodes,NewDeg),
	gcp_delete(Name,Graph,NewGraph).

/*********************************************************************
  remove(N,LIST,LENGTH,NEWLIST,NEWLENGTH) removes an element N from 
  a list_cas LIST with length LENGTH and returns the resultant list_cas 
  NEWLIST and its new length NEWLENGTH. 
 *********************************************************************/
remove(_,[],D,[],D).
remove(Name,[Name|Nodes],D,Nodes,NewDeg) :-
	NewDeg is D-1,!.
remove(Name,[N|Nodes],D,[N|NewNodes],NewDeg) :-
	Name \== N,
	remove(Name,Nodes,D,NewNodes,NewDeg).

/*********************************************************************
  gcp_reverse(LIST,NEWLIST) returns the reversed list_cas NEWLIST of a list_cas 
  LIST.
 *********************************************************************/
gcp_reverse(L1,L2) :- gcp_reverse(L1,[],L2).

gcp_reverse([],L,L).
gcp_reverse([H|L1],L2,L3) :-
	gcp_reverse(L1,[H|L2],L3).

/*********************************************************************
  chro_poly(GRAPH,ORDER,POLY) computes the chromatic polynomial POLY
  of a graph GRAPH according to the order ORDER.
 *********************************************************************/
chro_poly(_,[],[],[]).
chro_poly(Graph,[node(_,D,Nodes)|Orders],[Upoly|Upolys],[k-D|Lpolys]) :-
	subgraph(Graph,Nodes,Sgraph),
	ubound(Sgraph,D,Upoly),
	chro_poly(Graph,Orders,Upolys,Lpolys).

/*********************************************************************
  Given a graph GRAPH, subgraph(GRAPH,NODES,SUBGRAPH) returns the
  subgraph SUBGRAPH of GRAPH induced by the set of vertices NODES.
 *********************************************************************/
subgraph([],_,[]).
subgraph([node(N,_,Nodes)|Graph],Adj,[node(N,Size,NewNodes)|Sgraph]) :-
	gcp_member_cas(N,Adj), !,
	gcp_intersect(Nodes,Adj,NewNodes,Size),
	subgraph(Graph,Adj,Sgraph).
subgraph([_|Graph],Adj,Sgraph) :-
	subgraph(Graph,Adj,Sgraph).

/*********************************************************************
  gcp_intersect(SET1,SET2,NEWSET,SIZE) returns the intersection 
  NEWSET of SET1 and SET2, and its size SIZE.
 *********************************************************************/
gcp_intersect(Nodes,Adj,NewNodes,Size) :-
	gcp_intersect(Nodes,Adj,NewNodes,0,Size).

gcp_intersect([],_,[],D,D).
gcp_intersect([Node|Nodes],Adj,[Node|NewNodes],Size,Fsize) :-
	gcp_member_cas(Node,Adj), !,
	Size1 is Size+1,
	gcp_intersect(Nodes,Adj,NewNodes,Size1,Fsize).
gcp_intersect([_|Nodes],Adj,NewNodes,Size,Fsize) :-
	gcp_intersect(Nodes,Adj,NewNodes,Size,Fsize).

/*********************************************************************
  ubound(GRAPH,ORDER,TERM) returns one term TERM of the chromatic 
  polynomial corresponding to the interfacing subgraph GRAPH of
  oredr ORDER.
 *********************************************************************/
ubound(Graph,N,k-Bound) :-
	lbound(Graph,N,Bound).

/*********************************************************************
  lbound(GRAPH,ORDER,BOUND) returns the lower bound of the chromatic 
  number of a graph GRAPH of order ORDER based on Bondy's Theorem.
 *********************************************************************/
lbound(Graph,N,Bound) :-
	dqsort(Graph,SortGraph),
	lbound(SortGraph,N,0,0,Bound).

lbound(_,N,_,N,N).
lbound(Graph,N,Delta,K,Bound) :-
	Index is Delta+1,
	getdeg(Graph,Index,Deg),
	NewDelta is N-Deg+Delta,
	K1 is K+1,
	(NewDelta >= N ->
	   (Bound = K1);
	   (lbound(Graph,N,NewDelta,K1,Bound))).

/*********************************************************************
  getdeg(GRAPH,I,DEG) returns the Ist largest degree DEG of a graph 
  GRAPH.
 *********************************************************************/
getdeg([node(_,D,_)|_],1,D).
getdeg([_|Graph],Index,Deg) :-
	Index > 1,
	NewIndex is Index-1,
	getdeg(Graph,NewIndex,Deg).

/*********************************************************************
  dqsort(GRAPH,SORTGRAPH) applies quick sort to the graph GRAPH based 
  on the degrees of nodes and returns a graph SORTGRAPH in decreasing
  order.
 *********************************************************************/
dqsort([],[]).
dqsort([H|Graph],SortGraph) :-
	split(H,Graph,Small,Large),
	dqsort(Small,Sgraph),
	dqsort(Large,Lgraph),
	append_cas(Lgraph,[H|Sgraph],SortGraph).

/*
output([],[]).
output([k-N|U],[k-M|L]) :-
	write(N),write(' '),
	write(M), nl,
	output(U,L).
*/
