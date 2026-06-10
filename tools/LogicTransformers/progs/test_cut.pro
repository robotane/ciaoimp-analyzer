get_b(_, [], 0).
get_b(U, [bal(U,B)|_], B) :- !.
get_b(U, [_|T], B) :- get_b(U, T, B).
goal(X) :- get_b(alice, [bal(alice,100)], X).
