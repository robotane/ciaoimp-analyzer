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
    u(E, first, F),
    u(C, F, G),
    u(D, G, A),
    p(E).
p(A) :-
    u(B, goal, C),
    u(D, C, A),
    b([], '[|]', E),
    b(c, E, F),
    b(F, '[|]', G),
    b(b, G, H),
    b(H, '[|]', I),
    b(a, I, J),
    b(B, first, K),
    b(D, K, L),
    b(J, L, M),
    p(M).
