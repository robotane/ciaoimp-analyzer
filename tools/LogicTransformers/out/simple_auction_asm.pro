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
    u(B, transfer, C),
    u(_, C, D),
    u(_, D, A),
    p(B).
p(A) :-
    u(null, sa_state, B),
    u(_, B, C),
    u(D, C, E),
    u(F, E, G),
    u(H, sa_state, I),
    u(J, I, K),
    u(D, K, L),
    u(F, L, M),
    u(N, sa_bid, O),
    u(M, O, P),
    u(G, P, Q),
    u(J, Q, R),
    u(H, R, A),
    b(N, >, S),
    b(0, S, T),
    b(J, T, U),
    p(U).
p(A) :-
    u(B, sa_state, C),
    u(D, C, E),
    u(F, E, G),
    u(H, G, I),
    u(J, sa_state, K),
    u(L, K, M),
    u(F, M, N),
    u(H, N, O),
    u(P, sa_bid, Q),
    u(O, Q, R),
    u(I, R, S),
    u(L, S, T),
    u(J, T, A),
    b(P, transfer, U),
    b(D, U, V),
    b(B, V, W),
    b(W, >, X),
    b(D, X, Y),
    b(L, Y, Z),
    b(Z, \=, A1),
    b(null, A1, B1),
    b(B, B1, C1),
    p(C1).
p(A) :-
    u(null, sa_state, B),
    u(C, B, D),
    u(E, D, F),
    u(G, F, H),
    u(null, sa_state, I),
    u(C, I, J),
    u(E, J, K),
    u(G, K, L),
    u(M, sa_end, N),
    u(null, N, O),
    u(L, O, P),
    u(H, P, A),
    p(M).
p(A) :-
    u(B, sa_state, C),
    u(D, C, E),
    u(F, E, G),
    u(H, G, I),
    u(null, sa_state, J),
    u(D, J, K),
    u(F, K, L),
    u(H, L, M),
    u(N, sa_end, O),
    u(B, O, P),
    u(M, P, Q),
    u(I, Q, A),
    b(N, transfer, R),
    b(D, R, S),
    b(H, S, T),
    b(T, \=, U),
    b(null, U, V),
    b(B, V, W),
    p(W).
p(A) :-
    u(B, goal, C),
    u(D, C, A),
    b(null, sa_state, E),
    b(0, E, F),
    b(100, F, G),
    b(charlie, G, H),
    b([], '[|]', I),
    b(J, I, K),
    b(B, =, L),
    b(K, L, M),
    b(D, M, N),
    b(N, sa_end, O),
    b(J, O, P),
    b(_, P, Q),
    b(R, Q, S),
    b(S, sa_bid, T),
    b(R, T, U),
    b(V, U, W),
    b(250, W, X),
    b(bob, X, Y),
    b(Y, sa_bid, Z),
    b(V, Z, A1),
    b(B1, A1, C1),
    b(150, C1, D1),
    b(alice, D1, E1),
    b(E1, =, F1),
    b(H, F1, G1),
    b(B1, G1, H1),
    p(H1).
