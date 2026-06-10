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
    A=B=>C=>'$mark_cut',
    !,
    prolog_current_choice(B),
    p(C).
p(A) :-
    nonvar(A),
    A=B=>C=>'$cut',
    !,
    prolog_cut_to(B),
    p(C).
p(A) :-
    nonvar(A),
    A=B=>C=>D=>(=),
    B=C,
    p(D).
p(A) :-
    u(B, get_b, C),
    u(0, C, D),
    u([], D, E),
    u(_, E, A),
    p(B).
p(A) :-
    u(B, bal, C),
    u(D, C, E),
    u(_, '[|]', F),
    u(E, F, G),
    u(H, get_b, I),
    u(B, I, J),
    u(G, J, K),
    u(D, K, A),
    b(H, '$cut', L),
    b(M, L, N),
    b(N, '$mark_cut', O),
    b(M, O, P),
    p(P).
p(A) :-
    u(B, '[|]', C),
    u(_, C, D),
    u(E, get_b, F),
    u(G, F, H),
    u(D, H, I),
    u(J, I, A),
    b(E, get_b, K),
    b(G, K, L),
    b(B, L, M),
    b(J, M, N),
    p(N).
p(A) :-
    u(B, goal, C),
    u(D, C, A),
    b(100, bal, E),
    b(alice, E, F),
    b([], '[|]', G),
    b(F, G, H),
    b(B, get_b, I),
    b(D, I, J),
    b(H, J, K),
    b(alice, K, L),
    p(L).
