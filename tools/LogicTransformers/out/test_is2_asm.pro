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
    u(B, foo, C),
    u(D, C, E),
    u(F, E, G),
    u(H, G, A),
    b(F, -, I),
    b(H, I, J),
    b(B, is, K),
    b(J, K, L),
    b(D, L, M),
    p(M).
p(A) :-
    u(B, goal, C),
    u(D, C, A),
    b(B, foo, E),
    b(D, E, F),
    b(3, F, G),
    b(10, G, H),
    p(H).
