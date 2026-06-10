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
    u(_, '[|]', B),
    u(C, B, D),
    u(E, find, F),
    u(D, F, G),
    u(C, G, A),
    p(E).
p(A) :-
    u(B, '[|]', C),
    u(_, C, D),
    u(E, find, F),
    u(D, F, G),
    u(H, G, A),
    b(E, find, I),
    b(B, I, J),
    b(H, J, K),
    p(K).
p(A) :-
    u(B, goal, C),
    u(D, C, A),
    b(100, bal, E),
    b(alice, E, F),
    b(200, bal, G),
    b(bob, G, H),
    b([], '[|]', I),
    b(H, I, J),
    b(J, '[|]', K),
    b(F, K, L),
    b(B, find, M),
    b(L, M, N),
    b(D, N, O),
    p(O).
