find(X, [X|_]).
find(X, [_|T]) :- find(X, T).
goal(X) :- find(X, [bal(alice,100), bal(bob,200)]).
