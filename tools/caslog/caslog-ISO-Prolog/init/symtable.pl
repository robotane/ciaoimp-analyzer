%
%  symtable.pl			Nai-Wei Lin			November, 1991
%
%  This file contains the procedures for handling the symbol table.
%
%  The structure of the symbol table:
%	st(Pred/Arity,clause,mode,measure,mutex,det,size,solution,time)
%

%
%  Insert an entry for predicate Pred in the symbole table.
%  If it is already in, return the entry as Entry;
%  otherwise, an entry Entry for Pred is inserted and returned.
%
/*
insert_symbol_entry(ST,Pred,Entry) :- 
	var(ST),
	Entry = st(Pred,_,_,_,_,_,_,_,_,_),
	ST = [Entry|_].
insert_symbol_entry(ST,Pred,Entry) :- 
	nonvar(ST),
	ST = [Entry|_],
	Entry = st(Pred,_,_,_,_,_,_,_,_,_).
insert_symbol_entry(ST,Pred,Entry) :- 
	nonvar(ST),
	ST = [E|S],
	E \== st(Pred,_,_,_,_,_,_,_,_,_),
	insert_symbol_entry(S,Pred,Entry).

*/

insert_symbol_entry(ST,Pred,Entry) :- 
	(var(ST) ->
	    (Entry = st(Pred,_,_,_,_,_,_,_,_,_),
	    ST = [Entry|_]);
	    (nonvar(ST) ->
		(ST=[E|S],
		(E=st(Pred,_,_,_,_,_,_,_,_,_) ->
		    Entry=E;
		    ((E\==st(Pred,_,_,_,_,_,_,_,_,_) ->
			insert_symbol_entry(S,Pred,Entry))
		    )
		)
	    )
	)
    ).
	





%essai
%  Insert a clause for predicate Pred into the symbol table.
%
insert_symbol_field_clause(ST,Pred,clause,Clause) :-
	insert_symbol_entry(ST,Pred,st(Pred,ClauseList,_,_,_,_,_,_,_,_)),
	insert_symbol_clause(ClauseList,Clause).
%write('\nST(clause)='),write(ST),write('\n').

insert_symbol_clause(ClauseList,Clause) :-
	var(ClauseList),
	ClauseList = [Clause|_].
insert_symbol_clause(ClauseList,Clause) :-
	nonvar(ClauseList),
	ClauseList = [C|_],
	C == Clause.
insert_symbol_clause(ClauseList,Clause) :-
	nonvar(ClauseList),
	ClauseList = [C|CList],
	C \== Clause,
	insert_symbol_clause(CList,Clause).

%
%  Insert a declaration for predicate Pred into the symbol table.
%
insert_symbol_field_mode(ST,Pred,(mode),Mode) :-
	insert_symbol_entry(ST,Pred,st(Pred,_,Mode,_,_,_,_,_,_,_)).
%write('\nST(mode)='),write(ST),write('\n').
insert_symbol_field_measure(ST,Pred,measure,Measure) :-
	insert_symbol_entry(ST,Pred,st(Pred,_,_,Measure,_,_,_,_,_,_)).
%write('\nST(measure)='),write(ST),write('\n').
insert_symbol_field_mutex(ST,Pred,mutex,Mutex) :-
	insert_symbol_entry(ST,Pred,st(Pred,_,_,_,Mutex,_,_,_,_,_)).
insert_symbol_field_det(ST,Pred,det,Det) :-
       insert_symbol_entry(ST,Pred,st(Pred,_,_,_,_,Det,_,_,_,_)).
insert_symbol_field_size(ST,Pred,size,Size) :-
	insert_symbol_entry(ST,Pred,st(Pred,_,_,_,_,_,Size,_,_,_)).
insert_symbol_field_relation(ST,Pred,relation,Solution) :-
	insert_symbol_entry(ST,Pred,st(Pred,_,_,_,_,_,_,Solution,_,_)).
insert_symbol_field_time(ST,Pred,time,Time) :-
	insert_symbol_entry(ST,Pred,st(Pred,_,_,_,_,_,_,_,Time,_)).
insert_symbol_field_domain(ST,Pred,domain,Domain) :-
	insert_symbol_entry(ST,Pred,st(Pred,_,_,_,_,_,_,_,_,Domain)).

%
%  Find the entry for predicate Pred in the symbole table.
%  If it is in, return the entry as Entry;
%  otherwise, Entry is returned as a variable.
%

find_symbol_entry(ST,_,_) :- 
	var(ST),!.
find_symbol_entry(ST,Pred,Entry) :- 
	nonvar(ST),
	ST = [Entry|_],
	Entry = st(Pred,_,_,_,_,_,_,_,_,_),!.
find_symbol_entry(ST,Pred,Entry) :- 
	nonvar(ST),
	ST = [E|S],
	E = st(Pred1,_,_,_,_,_,_,_,_,_),
	Pred \== Pred1,
	find_symbol_entry(S,Pred,Entry),!.

/*
find_symbol_entry(ST,Pred,Entry) :- 
	(var(ST) -> !);
	    (nonvar(ST) ->
		(
		    ST=[E|S],
		    (E=st(Pred,_,_,_,_,_,_,_,_,_)->
			    (Entry=E,!);
				(E\==st(Pred,_,_,_,_,_,_,_,_,_)->	
				    find_symbol_entry(S,Pred,Entry)
				) 
			    )
			)
		    )
		).

*/
%
%  Find a field for predicate Pred in symbol table.
%
find_symbol_field_clause(ST,Pred,clause,ClauseList) :-
	find_symbol_entry(ST,Pred,st(Pred,ClauseList,_,_,_,_,_,_,_,_)),!.
find_symbol_field(ST,Pred,(mode),Mode) :-
	find_symbol_entry(ST,Pred,st(Pred,_,Mode,_,_,_,_,_,_,_)).
find_symbol_field_measure(ST,Pred,measure,Measure) :-
	find_symbol_entry(ST,Pred,st(Pred,_,_,Measure,_,_,_,_,_,_)).
find_symbol_field_mutex(ST,Pred,mutex,Mutex) :-
	find_symbol_entry(ST,Pred,st(Pred,_,_,_,Mutex,_,_,_,_,_)).
find_symbol_field_det(ST,Pred,det,Det) :-
	find_symbol_entry(ST,Pred,st(Pred,_,_,_,_,Det,_,_,_,_)).
find_symbol_field_size(ST,Pred,size,Size) :-
	find_symbol_entry(ST,Pred,st(Pred,_,_,_,_,_,Size,_,_,_)).
find_symbol_field_relation(ST,Pred,relation,Solution) :-
	find_symbol_entry(ST,Pred,st(Pred,_,_,_,_,_,_,Solution,_,_)).
find_symbol_field_time(ST,Pred,time,Time) :-
	find_symbol_entry(ST,Pred,st(Pred,_,_,_,_,_,_,_,Time,_)).
find_symbol_field_domain(ST,Pred,domain,Domain) :-
	find_symbol_entry(ST,Pred,st(Pred,_,_,_,_,_,_,_,_,Domain)).





%
%  Get a property of a literal from symbol table.
%
/*
literal_property(BT,ST,Pred,PropName,Property) :-
	find_symbol_field(BT,Pred,PropName,Prop1),
	(var(Prop1) ->
		find_symbol_field(ST,Pred,PropName,Property);
		Property = Prop1).
*/

literal_property(BT,ST,Pred,PropName,Property) :-
	((PropName == clause) -> 
	    (find_symbol_field_clause(BT,Pred,PropName,Prop1),
	    (var(Prop1) ->
		find_symbol_field_clause(ST,Pred,PropName,Property);
		Property = Prop1)
	    );
	    ((PropName == (mode)) -> 
		(find_symbol_field(BT,Pred,PropName,Prop1),
		(var(Prop1) ->
		    find_symbol_field(ST,Pred,PropName,Property);
		    Property = Prop1)
		);
		((PropName == measure) -> 
		    (find_symbol_field_measure(BT,Pred,PropName,Prop1),
		    (var(Prop1) ->
			find_symbol_field_measure(ST,Pred,PropName,Property);
			Property = Prop1)
		    );
		    ((PropName == mutex) -> 
			(find_symbol_field_mutex(BT,Pred,PropName,Prop1),
			(var(Prop1) ->
			    find_symbol_field_mutex(ST,Pred,PropName,Property);
			    Property = Prop1)
			);
			
			((PropName == det) -> 
			    (find_symbol_field_det(BT,Pred,PropName,Prop1),
			    (var(Prop1) ->
				find_symbol_field_det(ST,Pred,PropName,Property);
				Property = Prop1)
			    );
			    ((PropName == size) -> 
				(find_symbol_field_size(BT,Pred,PropName,Prop1),
				(var(Prop1) ->
				    find_symbol_field_size(ST,Pred,PropName,Property);
				    Property = Prop1)
				);
				((PropName == relation) -> 
				    (find_symbol_field_relation(BT,Pred,PropName,Prop1),
				    (var(Prop1) ->
					find_symbol_field_relation(ST,Pred,PropName,Property);
					Property = Prop1)
				    );
				    ((PropName == time) -> 
					(find_symbol_field_time(BT,Pred,PropName,Prop1),
					(var(Prop1) ->
					    find_symbol_field_time(ST,Pred,PropName,Property);
					    Property = Prop1)
					);
					((PropName == domain) -> 
					    (find_symbol_field_domain(BT,Pred,PropName,Prop1),
					    (var(Prop1) ->
						find_symbol_field_domain(ST,Pred,PropName,Property);
						Property = Prop1)
					    )
					)
				    )
				)
			    )
			)
		    )
		)
	    )
	).


find_symbol_field_property(BT,Pred,PropName,Prop1) :-
	((PropName == clause) -> 
	    (find_symbol_field_clause(BT,Pred,PropName,Prop1)
	    );
	    ((PropName == (mode)) -> 
		(find_symbol_field(BT,Pred,PropName,Prop1)
		);
		((PropName == measure) -> 
		    (find_symbol_field_measure(BT,Pred,PropName,Prop1)
		    );
		    ((PropName == mutex) -> 
			(find_symbol_field_mutex(BT,Pred,PropName,Prop1)
			);
			
			((PropName == det) -> 
			    (find_symbol_field_det(BT,Pred,PropName,Prop1)
			    );
			    ((PropName == size) -> 
				(find_symbol_field_size(BT,Pred,PropName,Prop1)
				);
				((PropName == relation) -> 
				    (find_symbol_field_relation(BT,Pred,PropName,Prop1)
				    );
				    ((PropName == time) -> 
					(find_symbol_field_time(BT,Pred,PropName,Prop1)
					);
					((PropName == domain) -> 
					    (find_symbol_field_domain(BT,Pred,PropName,Prop1)
					    )
					)
				    )
				)
			    )
			)
		    )
		)
	    )
	).
%
%  Print out the symbol table.
%
print_symbol_table(ST) :-
	tell(symbol_table),
	p_symbol_table(ST),
	told.

p_symbol_table(ST) :-
	var(ST).
p_symbol_table(ST) :-
	nonvar(ST),
	ST = [E|S],
	write(E),
	nl,
	p_symbol_table(S).

