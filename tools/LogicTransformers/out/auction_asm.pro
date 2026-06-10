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
    u(B, au_state, C),
    u(_, C, D),
    u(null, D, E),
    u(F, E, G),
    u(H, G, I),
    u(B, au_state, J),
    u(K, J, L),
    u(M, L, N),
    u(F, N, O),
    u(H, O, P),
    u(Q, au_bid, R),
    u(P, R, S),
    u(I, S, T),
    u(K, T, U),
    u(M, U, A),
    b(Q, >, V),
    b(0, V, W),
    b(K, W, X),
    p(X).
p(A) :-
    u(B, au_state, C),
    u(D, C, E),
    u(F, E, G),
    u(H, G, I),
    u(J, I, K),
    u(B, au_state, L),
    u(M, L, N),
    u(O, N, P),
    u(H, P, Q),
    u(J, Q, R),
    u(S, au_bid, T),
    u(R, T, U),
    u(K, U, V),
    u(M, V, W),
    u(O, W, A),
    b(S, transfer, X),
    b(D, X, Y),
    b(F, Y, Z),
    b(Z, >, A1),
    b(D, A1, B1),
    b(M, B1, C1),
    b(C1, \=, D1),
    b(null, D1, E1),
    b(F, E1, F1),
    p(F1).
p(A) :-
    u(0, au_state, B),
    u(C, B, D),
    u(E, D, F),
    u(G, F, H),
    u(I, H, J),
    u(1, au_state, K),
    u(C, K, L),
    u(E, L, M),
    u(G, M, N),
    u(I, N, O),
    u(P, au_end, Q),
    u(O, Q, R),
    u(J, R, A),
    b(P, transfer, S),
    b(C, S, T),
    b(I, T, U),
    p(U).
p(A) :-
    u(B, goal, C),
    u(D, C, A),
    b(0, au_state, E),
    b(0, E, F),
    b(null, F, G),
    b(100, G, H),
    b(charlie, H, I),
    b(_, au_state, J),
    b(K, J, L),
    b(_, L, M),
    b(_, M, N),
    b(O, N, P),
    b([], '[|]', Q),
    b(K, Q, R),
    b(R, '[|]', S),
    b(O, S, T),
    b(B, =, U),
    b(T, U, V),
    b(D, V, W),
    b(W, =, X),
    b(P, X, Y),
    b(Z, Y, A1),
    b(A1, au_end, B1),
    b(Z, B1, C1),
    b(D1, C1, E1),
    b(E1, au_bid, F1),
    b(D1, F1, G1),
    b(H1, G1, I1),
    b(300, I1, J1),
    b(bob, J1, K1),
    b(K1, au_bid, L1),
    b(H1, L1, M1),
    b(N1, M1, O1),
    b(200, O1, P1),
    b(alice, P1, Q1),
    b(Q1, =, R1),
    b(I, R1, S1),
    b(N1, S1, T1),
    p(T1).
