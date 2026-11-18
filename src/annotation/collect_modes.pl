% Observed modes of every predicate of a contract, on its scenario goal/1.
%
% Usage: swipl -q collect_modes.pl -- Contract.pl Out.json
%
% Each predicate p/n of the contract (plain Prolog, e.g. build/normalized/C.pl)
% is loaded under the name '$o:p' and p/n becomes a wrapper that records, for
% each argument, whether it is ground, a variable or partially bound when p is
% called, then calls '$o:p', and records which arguments are still unbound on
% exit (an argument unbound at the call and on every exit is ignored by p).
% The clauses are unchanged (a cut stays local to its clause set), so goal/1
% runs as before. Out.json maps "p/n" to one entry
% per argument: {"ground": count, "var": count, "partial": count,
% "var_exit": count, "exits": count}.

:- use_module(library(http/json)).
:- initialization(main, main).
:- dynamic seen/4.     % seen(Name, Arity, ArgIndex, Kind)
:- dynamic exit_seen/4. % exit_seen(Name, Arity, ArgIndex, var|bound)

main :-
    current_prolog_flag(argv, [Contract, Out]),
    read_clauses(Contract, Clauses),
    findall(N/A, (member(C, Clauses), head_of(C, H), functor(H, N, A)), Keys0),
    sort(Keys0, Keys),
    forall(member(C, Clauses), assert_renamed(C)),
    forall(member(N/A, Keys), assert_wrapper(N, A)),
    (   catch(once(goal(_)), E, (print_message(error, E), fail)) -> true
    ;   format(user_error, "goal/1 failed~n", [])
    ),
    findall(K-V, (member(N/A, Keys), N/A \== goal/1, entry(N, A, K, V)), Pairs),
    dict_pairs(Dict, modes, Pairs),
    setup_call_cleanup(open(Out, write, S), json_write_dict(S, Dict, [width(0)]), close(S)).

read_clauses(File, Clauses) :-
    setup_call_cleanup(open(File, read, S), read_all(S, Clauses), close(S)).

read_all(S, Cs) :-
    read_term(S, T, []),
    (   T == end_of_file -> Cs = []
    ;   T = (:- _) -> read_all(S, Cs)
    ;   Cs = [T|Rest], read_all(S, Rest)
    ).

head_of((H :- _), H) :- !.
head_of(H, H).

orig(H, O) :- H =.. [N|Args], atom_concat('$o:', N, ON), O =.. [ON|Args].

assert_renamed((H :- B)) :- !, orig(H, O), assertz((O :- B)).
assert_renamed(H) :- orig(H, O), assertz(O).

assert_wrapper(N, A) :-
    functor(H, N, A),
    orig(H, O),
    H =.. [_|Args],
    assertz((H :- record(N, Args), O, record_exit(N, Args))).

record_exit(N, Args) :-
    length(Args, A),
    forall(nth1(I, Args, X),
           ( var(X) -> assertz(exit_seen(N, A, I, var)) ; assertz(exit_seen(N, A, I, bound)) )).

record(N, Args) :-
    length(Args, A),
    forall(nth1(I, Args, X), (kind(X, K), assertz(seen(N, A, I, K)))).

kind(X, var) :- var(X), !.
kind(X, ground) :- ground(X), !.
kind(_, partial).

entry(N, A, K, V) :-
    format(atom(K), "~w/~w", [N, A]),
    findall(_{ground: G, var: Va, partial: P, var_exit: VE, exits: E},
            ( between(1, A, I),
              aggregate_all(count, seen(N, A, I, ground), G),
              aggregate_all(count, seen(N, A, I, var), Va),
              aggregate_all(count, seen(N, A, I, partial), P),
              aggregate_all(count, exit_seen(N, A, I, var), VE),
              aggregate_all(count, exit_seen(N, A, I, _), E) ),
            V).
