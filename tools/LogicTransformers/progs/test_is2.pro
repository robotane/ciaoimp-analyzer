foo(X, Y, Z) :- Z is X - Y.
goal(Z) :- foo(10, 3, Z).
