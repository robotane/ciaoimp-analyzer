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
    u(D, C, A),
    b(2, +, E),
    b(1, E, F),
    b(B, is, G),
    b(F, G, H),
    b(D, H, I),
    p(I).
p(A) :-
    u(B, goal, C),
    u(D, C, A),
    b(B, foo, E),
    b(D, E, F),
    p(F).
