%
%  clique.pl			Nai-Wei Lin			April, 1992
%
%  This file contains the procedures for estimating the number of n-cliques
%  of a consistency graph.
%

%
%  Estimate the number of n-cliques in a weighted consistency graph.
%
number_n_cliques([_],Domain,_,Sols) :-
	!,length_list(Domain,Sols).
number_n_cliques([_,_],_,Graph,Sols) :-
	!,number_2_clique(Graph,Sols).
number_n_cliques(Vars,Domain,Graph,Sols) :-
	number_n_cliques1(Vars,Domain,Graph,Sols).

number_n_cliques1([V|Vars],[domain(V,D)|Domain],[cgraph(V,CV)|Graph],Sols) :-
	consistency_graph_reduction(D,CV,Graph,[],NGraph),
	number_n_cliques(Vars,Domain,NGraph,Sols).

number_n_cliques2([V|Vars],[domain(V,D)|Domain],[cgraph(V,CV)|Graph],Sols) :-
	consistency_graph_reduction2(D,CV,Vars,Domain,Graph,0,Sols).

%
%  Estimate the number of 2-cliques in a weighted bipartite graph.
%
number_2_clique([cgraph(_,Var)|_],Sols) :-
	number_2_clique2(Var,Sols).

number_2_clique2([cvar(_,Edge)|_],Sols) :-
	number_2_clique3(Edge,0,Sols).

number_2_clique3([],Sols,Sols).
number_2_clique3([cedge(_,E)|Edge],Sol,Sols) :-
	number_2_clique4(E,0,Sol1),
	Sol2 is Sol+Sol1,
	number_2_clique3(Edge,Sol2,Sols).

number_2_clique4([],Sols,Sols).
number_2_clique4([weight(_,W)|E],Sol,Sols) :-
	Sol1 is W+Sol,
	number_2_clique4(E,Sol1,Sols).

%
%  Perform one step of consistency graph reduction.
%
consistency_graph_reduction([],_,_,Graph,Graph).
consistency_graph_reduction([D|Domain],CV,Graph,IGraph,OGraph) :-
	adjacent_nodes(CV,D,Nodes),
	adjacent_graph(Nodes,Graph,Graph1),
	graph_addition(IGraph,Graph1,Graph2),
	consistency_graph_reduction(Domain,CV,Graph,Graph2,OGraph).

consistency_graph_reduction2([],_,_,_,_,Sols,Sols).
consistency_graph_reduction2([D|Dom],CV,Vars,Domain,Graph,Sol,Sols) :-
	write(D),write(' '),
%tab(1),
	adjacent_nodes(CV,D,Nodes),
	adjacent_graph(Nodes,Graph,G1),
	number_n_cliques(Vars,Domain,G1,Sol1),
	write(Sol1),nl,
	Sol2 is Sol+Sol1,
	consistency_graph_reduction2(Dom,CV,Vars,Domain,Graph,Sol2,Sols).

%
%  Compute the adjacent nodes.
%
adjacent_nodes([],_,[]).
adjacent_nodes([cvar(_,Edge)|CV],D,[Node|Nodes]) :-
	adjacent_nodes1(Edge,D,Node),
	adjacent_nodes(CV,D,Nodes).

adjacent_nodes1([],_,[]) :- !.
adjacent_nodes1([cedge(V,E)|_],D,E) :-
	V =:= D, !.
adjacent_nodes1([cedge(V,_)|Edge],D,AEdge) :-
	V =\= D,
	adjacent_nodes1(Edge,D,AEdge).

%
%  Compute the adjacent graph.
%
adjacent_graph([_],G,G).
adjacent_graph([N|Nodes],[cgraph(V,G)|Graph],[cgraph(V,AG)|AGraph]) :-
	adjacent_edges(Nodes,N,G,AG),
	adjacent_graph(Nodes,Graph,AGraph).

%
%  Compute the adjacent edges.
%
adjacent_edges([],_,_,[]).
adjacent_edges([M|Nodes],N,[cvar(V,Edge)|G],[cvar(V,AEdge)|AG]) :-
	adjacent_edges1(N,M,Edge,AEdge),
	adjacent_edges(Nodes,N,G,AG).

adjacent_edges1([],_,_,[]) :- !.
adjacent_edges1(N,_,[],[]) :- N \== [], !.
adjacent_edges1([weight(V,W)|N],M,[cedge(U,E)|Edge],AEdge) :-
	V =:= U,!,
	adjacent_edges2(M,E,W,AE),
	(AE == [] ->
		AEdge = AEdges;
		AEdge = [cedge(U,AE)|AEdges]),
	adjacent_edges1(N,M,Edge,AEdges).
adjacent_edges1([weight(V,_)|N],M,[cedge(U,E)|Edge],AEdge) :-
	V < U,!,
	adjacent_edges1(N,M,[cedge(U,E)|Edge],AEdge).
adjacent_edges1([weight(V,W)|N],M,[cedge(U,_)|Edge],AEdge) :-
	V > U,
	adjacent_edges1([weight(V,W)|N],M,Edge,AEdge).

adjacent_edges2([],_,_,[]) :- !.
adjacent_edges2(M,[],_,[]) :- M \== [],!.
adjacent_edges2([weight(M1,W1)|M],[weight(E1,W2)|E],W,[weight(E1,W3)|AE]) :-
	M1 =:= E1,!,
	min(W1,W2,MW), min(MW,W,W3),
	adjacent_edges2(M,E,W,AE).
adjacent_edges2([weight(M1,_)|M],[weight(E1,W2)|E],W,AE) :-
	M1 < E1,!,
	adjacent_edges2(M,[weight(E1,W2)|E],W,AE).
adjacent_edges2([weight(M1,W1)|M],[weight(E1,_)|E],W,AE) :-
	M1 > E1,
	adjacent_edges2([weight(M1,W1)|M],E,W,AE).

%
%  Perform graph addition.
%
graph_addition([],G,G) :- !.
graph_addition(G,[],G) :- G \== [], !.
graph_addition([cgraph(V,V1)|G1],[cgraph(V,V2)|G2],[cgraph(V,V3)|G3]) :-
	var_addition(V1,V2,V3),
	graph_addition(G1,G2,G3).

%
%  Perform variable addition.
%
var_addition([],_,[]).
var_addition([cvar(V,E1)|V1],[cvar(V,E2)|V2],[cvar(V,E3)|V3]) :-
	edges_addition(E1,E2,E3),
	var_addition(V1,V2,V3).

%
%  Perform edge addition.
%
edges_addition([],E,E) :- !.
edges_addition(E,[],E) :- E \== [],!.
edges_addition([cedge(V1,E1)|C1],[cedge(V2,E2)|C2],[cedge(V1,E3)|C3]) :-
	V1 =:= V2,!,
	edge_addition(E1,E2,E3),
	edges_addition(C1,C2,C3).
edges_addition([cedge(V1,E1)|C1],[cedge(V2,E2)|C2],[cedge(V1,E1)|C3]) :-
	V1 < V2,!,
	edges_addition(C1,[cedge(V2,E2)|C2],C3).
edges_addition([cedge(V1,E1)|C1],[cedge(V2,E2)|C2],[cedge(V2,E2)|C3]) :-
	V1 > V2,
	edges_addition([cedge(V1,E1)|C1],C2,C3).

edge_addition([],E,E) :- !.
edge_addition(E,[],E) :- E \== [], !.
edge_addition([weight(V1,W1)|E1],[weight(V2,W2)|E2],[weight(V1,W3)|E3]) :-
	V1 =:= V2,!,
	W3 is W1+W2,
	edge_addition(E1,E2,E3).
edge_addition([weight(V1,W1)|E1],[weight(V2,W2)|E2],[weight(V1,W1)|E3]) :-
	V1 < V2,!,
	edge_addition(E1,[weight(V2,W2)|E2],E3).
edge_addition([weight(V1,W1)|E1],[weight(V2,W2)|E2],[weight(V2,W2)|E3]) :-
	V1 > V2,
	edge_addition([weight(V1,W1)|E1],E2,E3).
