% Records the argument shapes of the operations called by goal/1.
%
% Usage: swipl -q collect_calls.pl -- Contract.pl Out.json
%
% The contract (plain Prolog, e.g. build/normalized/C.pl) is consulted, then
% the body of goal/1 is run one goal at a time. Before each goal, the shape of
% every argument is recorded (var, int, flt, atm, list of shapes, struct of
% shapes); the goal is then called, so that the next one sees the state it
% produced, and the shapes after the call are recorded too. Out.json is a
% list of {"pred", "arity", "args", "post", "vars"}, one per call; "vars"[i]
% is the number of the variable of goal/1 written as argument i (-1 if the
% argument is not a variable), so that the output of a call can be linked to
% the input of a later call.
% No knowledge of the contract is used: only goal/1 and the clauses.

:- use_module(library(http/json)).
:- initialization(main, main).

main :-
    current_prolog_flag(argv, [Contract, Out]),
    load_files(Contract, [silent(true)]),
    clause(goal(_), Body),
    conj_list(Body, Goals),
    term_variables(Body, Vars),
    % variable numbers first: running a goal binds the variables of the next
    maplist(goal_ids(Vars), Goals, Ids),
    foldl(run_goal, Goals, Ids, Calls0, []),
    exclude(==(none), Calls0, Calls),
    setup_call_cleanup(open(Out, write, S),
                       json_write_dict(S, Calls, [width(0)]),
                       close(S)).

conj_list((A, B), L) :- !, conj_list(A, LA), conj_list(B, LB), append(LA, LB, L).
conj_list(G, [G]).

goal_ids(Vars, G, Ids) :- G =.. [_|Args], maplist(var_id(Vars), Args, Ids).

run_goal(G, Ids, [Call|T], T) :-
    G =.. [Name|Args],
    length(Args, N),
    (   predicate_property(G, built_in) -> once(G), Call = none
    ;   maplist(shape, Args, Shapes),
        once(G),
        maplist(shape, Args, Post),
        Call = _{pred: Name, arity: N, args: Shapes, post: Post, vars: Ids}
    ).

var_id(Vars, A, Id) :-
    (   var(A), nth0(I, Vars, V), V == A -> Id = I ; Id = -1 ).

shape(V, "var") :- var(V), !.
shape(X, "int") :- integer(X), !.
shape(X, "flt") :- float(X), !.
shape([], _{list: []}) :- !.
shape(L, _{list: Es}) :- is_list(L), !, maplist(shape, L, Es).
shape(X, "atm") :- atom(X), !.
shape(X, _{struct: Name, args: Shapes}) :-
    compound(X), !,
    X =.. [Name|Args],
    maplist(shape, Args, Shapes).
shape(_, "term").
