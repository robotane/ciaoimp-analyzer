%
%
insert_size_function([],_,_).
insert_size_function([Pred|Component],[Size|SList],ST) :-
	insert_symbol_field_size(ST,Pred,size,Size),
	insert_size_function(Component,SList,ST).
