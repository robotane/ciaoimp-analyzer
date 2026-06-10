%
%  gvars.pl			Nai-Wei Lin			November, 1991
%
%  This file contains the procedures for manipulating the ground
%  variables list_cas.
%
%  The structure of the ground variables list_cas:
%	gv(Var,pos)
%

%
%  Insert an entry for variable Var in the ground variables list_cas.
%  If it is already in, return the entry as Entry;
%  otherwise, an entry Entry for Var is inserted and returned.
%
/*
insert_gvars_entry(Gvars,Var,Entry) :- 
	var(Gvars),
	Entry = gv(Var,_,_,_,_,_,_),
	Gvars = [Entry|_].
insert_gvars_entry(Gvars,Var,Entry) :- 
	nonvar(Gvars),
	Gvars = [E|_],
	E = gv(VAR,_,_,_,_,_,_),
	Var == VAR,
	Entry = E.
insert_gvars_entry(Gvars,Var,Entry) :- 
	nonvar(Gvars),
	Gvars = [E|G],
	E = gv(VAR,_,_,_,_,_,_),
	Var \== VAR,
	insert_gvars_entry(G,Var,Entry).
*/
insert_gvars_entry(Gvars,Var,Entry) :- 
(var(Gvars) -> 
    (Entry = gv(Var,_,_,_,_,_,_),
	Gvars = [Entry|_]
    );
	(nonvar(Gvars) ->
	    (Gvars = [E|G],E = gv(VAR,_,_,_,_,_,_),
	    (Var == VAR -> 
		(Entry = E);
		    insert_gvars_entry(G,Var,Entry)
		)
	    )
	)
    ).

%
%  Insert a bound position for variable Var into the ground variables list_cas.
%

insert_gvars_field(Gvars,Var,def,Pos) :-
	insert_gvars_entry(Gvars,Var,gv(Var,PosList,_,_,_,_,_)),
	insert_gvars_pos(PosList,Pos).
insert_gvars_field(Gvars,Var,use,Pos) :-
	insert_gvars_entry(Gvars,Var,gv(Var,_,PosList,_,_,_,_)),
	insert_gvars_pos(PosList,Pos).
insert_gvars_field(Gvars,Var,relation,Sol) :-
	insert_gvars_entry(Gvars,Var,gv(Var,_,_,Sol,_,_,_)).
insert_gvars_field(Gvars,Var,det,Sol) :-
	insert_gvars_entry(Gvars,Var,gv(Var,_,_,_,Sol,_,_)).
insert_gvars_field(Gvars,Var,redge,Edge) :-
	insert_gvars_entry(Gvars,Var,gv(Var,_,_,_,_,Edge,_)).
insert_gvars_field(Gvars,Var,sedge,Edge) :-
	insert_gvars_entry(Gvars,Var,gv(Var,_,_,_,_,_,Edge)).

/*

insert_gvars_field(Gvars,Var,Type,Result):-
	(Type==def ->
	    (insert_gvars_entry(Gvars,Var,gv(Var,PosList,_,_,_,_,_)),
	    insert_gvars_pos(PosList,Result));
	    (Type==use ->
		(insert_gvars_entry(Gvars,Var,gv(Var,_,PosList,_,_,_,_)),
		insert_gvars_pos(PosList,Result));
		(Type==relation ->
		    (insert_gvars_entry(Gvars,Var,gv(Var,_,_,Result,_,_,_)));
			(Type==det ->
			    (insert_gvars_entry(Gvars,Var,gv(Var,_,_,_,Result,_,_)));
				(Type==redge ->
				    (insert_gvars_entry(Gvars,Var,gv(Var,_,_,_,_,Result,_)));
				    (Type==sedge ->
					(insert_gvars_entry(Gvars,Var,gv(Var,_,_,_,_,_,Result)))
				    )
				)
			    )
			)
		    )
		).
	*/				


insert_gvars_pos(PosList,Pos) :-
	var(PosList),
	PosList = [Pos|_].
insert_gvars_pos(PosList,Pos) :-
	nonvar(PosList),
	PosList = [Pos|_].
insert_gvars_pos(PosList,Pos) :-
	nonvar(PosList),
	PosList = [P|PList],
	P \== Pos,
	insert_gvars_pos(PList,Pos).

%
%  Find the entry for variable Var in the ground variables list_cas.
%  If it is in, return the entry as Entry;
%  otherwise, Entry is returned as a variable.
%
/*
find_gvars_entry(Gvars,_,_) :- 
	var(Gvars).
find_gvars_entry(Gvars,Var,Entry) :- 
	nonvar(Gvars),
	Gvars = [E|_],
	E = gv(VAR,_,_,_,_,_,_),
	Var == VAR,
	Entry = E.
find_gvars_entry(Gvars,Var,Entry) :- 
	nonvar(Gvars),
	Gvars = [E|G],
	E = gv(VAR,_,_,_,_,_,_),
	Var \== VAR,
	find_gvars_entry(G,Var,Entry).
*/

find_gvars_entry(Gvars,Var,Entry):-
	(var(Gvars) -> !;
	    (nonvar(Gvars) ->
		(Gvars=[E|G],E=gv(VAR,_,_,_,_,_,_),
		(Var==VAR -> Entry = E;
		    (Var\==VAR -> find_gvars_entry(G,Var,Entry))
		)
	    )
	)
    ).

%
%  Find a field for variable Var into the ground variables list_cas.
%
/*
find_gvars_field(Gvars,Var,def,PosList) :-
	find_gvars_entry(Gvars,Var,gv(Var,PosList,_,_,_,_,_)).
find_gvars_field(Gvars,Var,use,PosList) :-
	find_gvars_entry(Gvars,Var,gv(Var,_,PosList,_,_,_,_)).
find_gvars_field(Gvars,Var,relation,Sol) :-
	find_gvars_entry(Gvars,Var,gv(Var,_,_,Sol,_,_,_)).
find_gvars_field(Gvars,Var,det,Sol) :-
	find_gvars_entry(Gvars,Var,gv(Var,_,_,_,Sol,_,_)).
find_gvars_field(Gvars,Var,redge,Edge) :-
	find_gvars_entry(Gvars,Var,gv(Var,_,_,_,_,Edge,_)).
find_gvars_field(Gvars,Var,sedge,Edge) :-
	find_gvars_entry(Gvars,Var,gv(Var,_,_,_,_,_,Edge)).

*/


find_gvars_field(Gvars,Var,Type,Result) :-
	(Type==def ->
	    (find_gvars_entry(Gvars,Var,gv(Var,Result,_,_,_,_,_)));
		(Type==use ->
		    (find_gvars_entry(Gvars,Var,gv(Var,_,Result,_,_,_,_)));
			(Type==relation ->
			    (find_gvars_entry(Gvars,Var,gv(Var,_,_,Result,_,_,_)));
				(Type==det ->
				    (find_gvars_entry(Gvars,Var,gv(Var,_,_,_,Result,_,_)));
					(Type==redge ->
					    (find_gvars_entry(Gvars,Var,gv(Var,_,_,_,_,Result,_)));
						(Type==sedge ->
						    (find_gvars_entry(Gvars,Var,gv(Var,_,_,_,_,_,Result))))
						)
					    )
					)
				    )
				).












%
%  Close the postion list_cass of the ground variable list_cas.
%
close_gvars_list_cas(Gvars) :-
	var(Gvars).
close_gvars_list_cas(Gvars) :-
	nonvar(Gvars),
	Gvars = [gv(_,Def,Use,_,_,_,_)|G],
	close_list_cas(Def),
	close_list_cas(Use),
	close_gvars_list_cas(G).

%
%  Print out the ground variables list_cas.
%
print_gvars_list_cas(Gvars) :-
	tell(gvars_list_cas),
	p_gvars_list_cas(Gvars),
	told.

p_gvars_list_cas([]).
p_gvars_list_cas([E|Gvars]) :-
	write(E),
	nl,
	p_gvars_list_cas(Gvars).
