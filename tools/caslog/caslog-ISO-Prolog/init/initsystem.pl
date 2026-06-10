%
%  initsystem.pl		Nai-Wei Lin			November, 1991
%
%  This file contains the procedures for initializing the system.
%

%
%  Initialize the system by initializing the buildin table and
%  read in the source program, and building the program table,
%  symbol table, call graph and the strongly connected components
%  of the call graph.
%
init_system(Files,BT,ST,SCCG,Error) :-

	init_buildin_table(BT),
	read_program(Files,BT,PT,ST,Error1),
%write('\n PT = '),write(PT),write('\n ST = '),write(ST),
	call_graph(PT,BT,ST,CG,Error2),
%write(CG),

	Error is Error1*Error2,
	(Error =:= 1 -> (
		strongly_connected_component(CG,SCCG));
		true).


%
%  Read in the source program and store the clauses in the program table,
%  symbol table and call graph.
%
read_program(Files,BT,PT,ST,Error) :-
	read_program(Files,BT,PT,[],ST,Error).

read_program([],_,PT,PT,_,1).
read_program([File|Fs],BT,PT,NPT,ST,Error) :-
	see(File),
	r_program(BT,PT,PT1,ST,Error1),
	seen,
	read_program(Fs,BT,PT1,NPT,ST,Error2),
	Error is Error1*Error2.

r_program(BT,PT,NPT,ST,Error) :-
	read(Clause),
	(Clause \== end_of_file -> 
		(PT=[Clause|PT1],
		 clause_type(Clause,Type),
		 insert_symbol_table(Type,ST,Clause,Error1),
		 r_program(BT,PT1,NPT,ST,Error2),
		 Error is  Error1*Error2);
		(NPT = PT,
		 Error = 1)).
%
%  Classify the type of a clause.
%    Declaration -- 1	
%    Rule        -- 2
%    Fact        -- 3
%
clause_type(Clause,Type) :-
	functor(Clause,F,N),
	clause_type(F,N,Type).

clause_type((:-),1,1).
clause_type((:-),2,2).
clause_type(F,_,3) :-
	F \== (:-).

% 
%  The following procedures insert the clauses into the symbol table.
% 

%
%  Insert a clause into the symbol table.
%
/*insert_symbol_table(1,ST,Clause,Error) :-
	insert_symbol_dec(ST,Clause,Error).
insert_symbol_table(2,ST,Clause,1) :-
	insert_symbol_rule(ST,Clause).
insert_symbol_table(3,ST,Clause,1) :-
	insert_symbol_fact(ST,Clause).
*/


insert_symbol_table(Type,ST,Clause,Error) :-
	(Type==1 -> 
	    (insert_symbol_dec(ST,Clause,Error));
		(Type==2 ->
		    (insert_symbol_rule(ST,Clause),Error=1);
			(Type==3 ->
			    	(insert_symbol_fact(ST,Clause),Error=1)
			    )
			)
		    ).

%
%  Insert a rule into the symbol table.
%
insert_symbol_rule(ST,Rule) :-
	arg(1,Rule,Head),
	functor(Head,F,N),
	insert_symbol_field_clause(ST,F/N,clause,Rule).

%
%  Insert a fact into the symbol table.
%
insert_symbol_fact(ST,Fact) :-
	functor(Fact,F,N),
	insert_symbol_field_clause(ST,F/N,clause,Fact).

%  
%  The following procedures insert the clauses into the call graph.
% 

%
%  Build the call graph of the program.
%
call_graph([],_,_,_,1).
call_graph([Clause|PT],BT,ST,CG,Error) :-
	clause_type(Clause,Type),
	insert_call_graph(Type,BT,ST,CG,Clause,Error1),
	call_graph(PT,BT,ST,CG,Error2),
	Error is Error1*Error2.

%
%
%  Insert a clause into the call graph.
%
/*
insert_call_graph(1,_,_,_,_,1).
insert_call_graph(2,BT,ST,CG,Clause,Error) :-
	arg(1,Clause,Head),
	arg(2,Clause,Body),
	functor(Head,F,N),
	insert_call_entry(CG,F/N,_),
	insert_call_body(BT,ST,CG,F/N,Body,Clause,Error).
insert_call_graph(3,_,_,CG,Clause,1) :-
	functor(Clause,F,N),
	insert_call_entry(CG,F/N,_).
*/

insert_call_graph(Type,BT,ST,CG,Clause,Error):-
	(Type==1 -> Error=1;
	    (Type==2 -> 
		(arg(1,Clause,Head),
		arg(2,Clause,Body),
		functor(Head,F,N),
		insert_call_entry(CG,F/N,_),
		insert_call_body(BT,ST,CG,F/N,Body,Clause,Error));
		(Type==3 ->
		    (functor(Clause,F,N),
		    insert_call_entry(CG,F/N,_),Error=1)
		)
	    )
	).


%
%  Insert the literals in the body of a rule into the call graph.
%
/*
insert_call_body(BT,ST,CG,Pred,(Lit,Body),Clause,Error) :-
	insert_call_lit(BT,ST,CG,Pred,Lit,Clause,Error1),
	insert_call_body(BT,ST,CG,Pred,Body,Clause,Error2),
	Error is Error1*Error2.
insert_call_body(BT,ST,CG,Pred,Lit,Clause,Error) :-
	nonsequence(Lit),
	insert_call_lit(BT,ST,CG,Pred,Lit,Clause,Error).
*/

insert_call_body(BT,ST,CG,Pred,L,Clause,Error) :-
	(L=(Lit,Body) ->
	    (insert_call_lit(BT,ST,CG,Pred,Lit,Clause,Error1),
	    insert_call_body(BT,ST,CG,Pred,Body,Clause,Error2),
	    Error is Error1*Error2);
	    (L=Lit ->
		(nonsequence(Lit),
		insert_call_lit(BT,ST,CG,Pred,Lit,Clause,Error))
	    )
	).


%
%  Insert a non-builtin non-recursive literal into the call graph.
%
insert_call_lit(_,_,_,Pred,Lit,_,1) :-
	functor(Lit,F,A), F/A == Pred, !.
insert_call_lit(BT,ST,CG,Pred,Lit,Clause,Error) :-
	functor(Lit,F,A), F/A \== Pred,
	(second_order_predicate(F/A) ->
		insert_call_lit_1(BT,ST,CG,Pred,Lit,Clause,Error);
		insert_call_lit_2(BT,ST,CG,Pred,Lit,Clause,Error)).

insert_call_lit_1(BT,ST,CG,Pred,Lit,Clause,Error) :-
	second_order_predicate_pred_arg(Lit,L),
	insert_call_body(BT,ST,CG,Pred,L,Clause,Error).

insert_call_lit_2(BT,ST,CG,Pred,Lit,Clause,Error) :-
	functor(Lit,F,A),
	find_symbol_entry(BT,F/A,BTEntry),
	(var(BTEntry) ->
		(find_symbol_entry(ST,F/A,STEntry),
		 (var(STEntry) ->
			(error_message(lit1,F/A,Clause),
			 Error = 0);
			(insert_call_field(CG,Pred,edge,F/A),
			 Error = 1)));
		Error = 1).
