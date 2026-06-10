:- op(100, xfy, =>).
% QUERY THIS WITH: ?- p(Answer => _ => goal).

u(A, B, A=>B).
b(A, B, A=>B).
p(A) :-
    var(A),
    !,
    A=true.
p(A) :-
    nonvar(A),
    A=B=>C=>D=>(is),
    toTerm(C, E),
    B is E,
    p(D).
p(A) :-
    nonvar(A),
    A=B=>C=>D=>(>),
    B>C,
    p(D).
p(A) :-
    nonvar(A),
    A=B=>C=>D=>(>=),
    B>=C,
    p(D).
p(A) :-
    nonvar(A),
    A=B=>C=>D=>(\=),
    B\=C,
    p(D).
p(A) :-
    nonvar(A),
    A=B=>C=>D=>(<),
    B<C,
    p(D).
p(A) :-
    nonvar(A),
    A=B=>C=>D=>(=<),
    B=<C,
    p(D).
p(A) :-
    nonvar(A),
    A=B=>C=>D=>(\==),
    B\==C,
    p(D).
p(A) :-
    nonvar(A),
    A=B=>!,
    !,
    p(B).
p(A) :-
    nonvar(A),
    A=B=>C=>D=>(=),
    B=C,
    p(D).
p(A) :-
    u(B, eq, C),
    u(D, C, E),
    u(D, E, A),
    p(B).
p(A) :-
    u(B, add, C),
    u(D, C, E),
    u(D, E, F),
    u(0, F, A),
    p(B).
p(A) :-
    u(B, s, C),
    u(D, s, E),
    u(F, add, G),
    u(E, G, H),
    u(I, H, J),
    u(C, J, A),
    b(F, add, K),
    b(D, K, L),
    b(I, L, M),
    b(B, M, N),
    p(N).
p(A) :-
    u(B, mul, C),
    u(0, C, D),
    u(_, D, E),
    u(0, E, A),
    p(B).
p(A) :-
    u(B, s, C),
    u(D, mul, E),
    u(F, E, G),
    u(H, G, I),
    u(C, I, A),
    b(D, add, J),
    b(F, J, K),
    b(L, K, M),
    b(H, M, N),
    b(N, mul, O),
    b(L, O, P),
    b(H, P, Q),
    b(B, Q, R),
    p(R).
p(A) :-
    u(B, goal, C),
    u(D, C, A),
    b(0, s, E),
    b(E, s, F),
    b(F, s, G),
    b(H, sum, I),
    b(J, I, K),
    b(B, eq, L),
    b(K, L, M),
    b(D, M, N),
    b(N, add, O),
    b(P, O, Q),
    b(H, Q, R),
    b(J, R, S),
    b(S, mul, T),
    b(P, T, U),
    b(V, U, W),
    b(V, W, X),
    b(X, eq, Y),
    b(G, Y, Z),
    b(V, Z, A1),
    p(A1).
