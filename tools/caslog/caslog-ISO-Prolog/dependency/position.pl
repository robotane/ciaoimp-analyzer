%
%  position.pl			Nai-Wei Lin			December, 1991
%
%  This file contains the procedures for handling the positions.
%

%
:- op(200, fx, [$]).

%
%  Construct a new position structure.
%
new_pos(LitNum,ArgNum,'$'(LitNum,ArgNum)).

%
%  Get the literal number of a position.
%
pos_litnum('$'(LitNum,_),LitNum).

%
%  Get the argument number of a position.
%
pos_argnum('$'(_,ArgNum),ArgNum).

%
%  Generate the set of argument positions in a clause.
%
gen_clause_pos(Adg,[]) :-
	var(Adg).
gen_clause_pos(Adg,[Pos|PList]) :-
	nonvar(Adg),
	Adg = [adg(Pos,_,_,_)|AList],
	gen_clause_pos(AList,PList).

%
%  Generate the set of argument positions in a literal.
%
gen_literal_pos(_/N,LitNum,Pos) :-
	gen_lit_pos(0,N,LitNum,Pos).

gen_lit_pos(N,N,_,[]).
gen_lit_pos(M,N,LitNum,[Pos|PList]) :-
	M < N,
	M1 is M+1,
	new_pos(LitNum,M1,Pos),
	gen_lit_pos(M1,N,LitNum,PList).

%
%  Generate the set of input (or output) argument positions in a literal.
%
gen_literal_iopos(Adg,Lit,LitNum,Mode,Pos) :-
	gen_literal_pos(Lit,LitNum,Pos1),
	gen_lit_iopos(Pos1,Adg,Mode,Pos).

gen_lit_iopos([],_,_,[]).
gen_lit_iopos([P|PList1],Adg,Mode,Pos) :-
	find_adg_field(Adg,P,(mode),Mode1),
	(Mode1 == Mode ->
		Pos = [P|PList];
		PList = Pos),
	gen_lit_iopos(PList1,Adg,Mode,PList).
	
