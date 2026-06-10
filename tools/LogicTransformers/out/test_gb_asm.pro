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
    A=B=>!,
    !,
    p(B).
p(A) :-
    nonvar(A),
    A=B=>C=>D=>(=),
    B=C,
    p(D).
p(A) :-
    u(B, get_balance, C),
    u(0, C, D),
    u([], D, E),
    u(_, E, A),
    p(B).
p(A) :-
    u(B, bal, C),
    u(D, C, E),
    u(_, '[|]', F),
    u(E, F, G),
    u(H, get_balance, I),
    u(B, I, J),
    u(G, J, K),
    u(D, K, A),
    p(H).
p(A) :-
    u(B, '[|]', C),
    u(_, C, D),
    u(E, get_balance, F),
    u(G, F, H),
    u(D, H, I),
    u(J, I, A),
    b(E, get_balance, K),
    b(G, K, L),
    b(B, L, M),
    b(J, M, N),
    p(N).
p(A) :-
    u(B, goal, C),
    u(D, C, A),
    b(1000, bal, E),
    b(alice, E, F),
    b(1000, bal, G),
    b(bob, G, H),
    b([], '[|]', I),
    b(H, I, J),
    b(J, '[|]', K),
    b(F, K, L),
    b(B, get_balance, M),
    b(D, M, N),
    b(O, N, P),
    b(alice, P, Q),
    b(Q, =, R),
    b(L, R, S),
    b(O, S, T),
    p(T).
