%% transform.pl — Étage B du pipeline CasLog v2.
%%
%% Lit un fichier déjà précleané (aucun :- ..., aucun main/0, aucun atome
%% quoté avec /$disj/) et applique les transformations sémantiques :
%%
%%  1. length/2 → len_list/2 (+ injection si utilisé)
%%  2. (A -> B ; C) → aux_cond_N(...) avec deux clauses (la 1ère avec !)
%%  3. (A ; B) pur → aux_cond_N(...) avec deux clauses (sans !)
%%  4. (A -> B) (sans else) → A, B (séquence)
%%  5. X == Y → unification forcée à l'écriture
%%  6. X = Y → idem
%%  7. X \== Y → neq(X, Y) (+ injection neq/2)
%%
%% Les variables des aux_cond_N sont l'intersection des vars utilisées dans
%% le sous-but (A,B,C) avec celles vivantes dans le contexte (head + reste
%% du clause). copy_term garantit la fraîcheur des vars dans chaque clause
%% lifted, ce qui permet aux unifications post-traitement de ne pas
%% propager hors de la clause.
%%
%% Injections finales (uniquement si appelés-mais-non-définis) :
%%   neq/2, len_list/2, member/2, loop_aux_1/4, loop_aux_2/7

:- use_module(library(lists)).

:- dynamic aux_count/1.
:- dynamic def_pred/2.
:- dynamic call_pred/2.
:- dynamic length_used/0.
:- dynamic neq_used/0.

reset_state :-
    retractall(aux_count(_)),
    retractall(def_pred(_,_)),
    retractall(call_pred(_,_)),
    retractall(length_used),
    retractall(neq_used),
    assertz(aux_count(1)).

gen_aux_name(Name) :-
    aux_count(C),
    atomic_list_concat([aux_cond_, C], Name),
    C1 is C + 1,
    retractall(aux_count(_)),
    asserta(aux_count(C1)).

main :-
    current_prolog_flag(argv, Argv),
    ( Argv = [InFile, OutFile | _] -> true
    ; format(user_error, "usage: transform.pl <in> <out>~n", []), halt(2)
    ),
    reset_state,
    setup_call_cleanup(
        open(InFile, read, In),
        read_terms(In, Terms),
        close(In)),
    setup_call_cleanup(
        open(OutFile, write, Out),
        process_terms(Terms, Out),
        close(Out)),
    halt.

read_terms(In, Terms) :-
    read_term(In, T, []),
    ( T == end_of_file
    -> Terms = []
    ;  Terms = [T|Rest],
       read_terms(In, Rest)
    ).

process_terms(Terms, Out) :-
    maplist(rewrite_length, Terms, Rewritten),
    maplist(emit_term(Out), Rewritten),
    inject_missing(Out).

%% rewrite_length : remplace length(X,N) par len_list(X,N) partout dans l'arbre

rewrite_length(T, T) :- var(T), !.
rewrite_length(T, T) :- atomic(T), !.
rewrite_length(length(X, N), len_list(XR, NR)) :-
    !,
    ( length_used -> true ; assertz(length_used) ),
    rewrite_length(X, XR),
    rewrite_length(N, NR).
rewrite_length(T, NT) :-
    T =.. [F|Args],
    maplist(rewrite_length, Args, NArgs),
    NT =.. [F|NArgs].

%% emit_term : transforme une clause et l'écrit (+ ses auxiliaires)

emit_term(Out, (Head :- Body)) :-
    !,
    note_defined(Head),
    note_called_body(Body),
    transform_body(Body, Head, NewBody, AuxClauses),
    Clauses = [(Head :- NewBody) | AuxClauses],
    maplist(note_defined_clause, AuxClauses),
    process_clauses(Clauses, Out).
emit_term(Out, Head) :-
    note_defined(Head),
    process_clauses([Head], Out).

note_defined(Head) :-
    functor(Head, Name, Arity),
    ( def_pred(Name, Arity) -> true ; assertz(def_pred(Name, Arity)) ).

note_defined_clause((H :- _)) :- !, note_defined(H).
note_defined_clause(H) :- note_defined(H).

note_called_body(B) :-
    ( var(B) -> true
    ; B == ! -> true
    ; B == true -> true
    ; B = (X, Y)        -> note_called_body(X), note_called_body(Y)
    ; B = (X ; Y)       -> note_called_body(X), note_called_body(Y)
    ; B = (X -> Y)      -> note_called_body(X), note_called_body(Y)
    ; B = (X -> Y ; Z)  -> note_called_body(X), note_called_body(Y), note_called_body(Z)
    ; B = (_ = _)   -> true
    ; B = (_ == _)  -> true
    ; B = (_ \== _) -> true
    ; B = (_ is _)  -> true
    ; B = (_ < _)   -> true
    ; B = (_ > _)   -> true
    ; B = (_ =< _)  -> true
    ; B = (_ >= _)  -> true
    ; B = (_ =:= _) -> true
    ; B = (_ =\= _) -> true
    ; functor(B, N, A),
      ( call_pred(N, A) -> true ; assertz(call_pred(N, A)) )
    ).

%% transform_body : lift (->;), (;), (->)

transform_body(B, _Ctx, B, []) :- var(B), !.
transform_body((A, B), Ctx, (NA, NB), Aux) :-
    !,
    transform_body(A, ctx(Ctx, B), NA, AuxA),
    transform_body(B, ctx(Ctx, A), NB, AuxB),
    append(AuxA, AuxB, Aux).
transform_body((A -> B ; C), Ctx, AuxCall, AuxClauses) :-
    !,
    gen_aux_name(Name),
    term_variables((A,B,C), InsideVars),
    term_variables(Ctx, OutsideVars),
    intersect_vars(InsideVars, OutsideVars, Vars),
    AuxCall =.. [Name | Vars],
    transform_body(A, Ctx, NA, AuxA),
    transform_body(B, Ctx, NB, AuxB),
    transform_body(C, Ctx, NC, AuxC),
    append(AuxA, AuxB, AuxAB),
    append(AuxAB, AuxC, AuxRest),
    copy_term((AuxCall :- (NA, !, NB)), Clause1),
    copy_term((AuxCall :- NC), Clause2),
    AuxClauses = [Clause1, Clause2 | AuxRest].
transform_body((A ; B), Ctx, AuxCall, AuxClauses) :-
    !,
    gen_aux_name(Name),
    term_variables((A,B), InsideVars),
    term_variables(Ctx, OutsideVars),
    intersect_vars(InsideVars, OutsideVars, Vars),
    AuxCall =.. [Name | Vars],
    transform_body(A, Ctx, NA, AuxA),
    transform_body(B, Ctx, NB, AuxB),
    append(AuxA, AuxB, AuxRest),
    copy_term((AuxCall :- NA), Clause1),
    copy_term((AuxCall :- NB), Clause2),
    AuxClauses = [Clause1, Clause2 | AuxRest].
transform_body((A -> B), Ctx, (NA, NB), Aux) :-
    !,
    transform_body(A, Ctx, NA, AuxA),
    transform_body(B, Ctx, NB, AuxB),
    append(AuxA, AuxB, Aux).
transform_body(Goal, _Ctx, Goal, []).

intersect_vars([], _, []).
intersect_vars([V|Vs], Out, [V|Rs]) :-
    var_member(V, Out), !,
    intersect_vars(Vs, Out, Rs).
intersect_vars([_|Vs], Out, Rs) :-
    intersect_vars(Vs, Out, Rs).

var_member(V, [O|_]) :- V == O, !.
var_member(V, [_|Os]) :- var_member(V, Os).

%% process_clauses : applique les unifications post-lift et écrit

process_clauses([], _).
process_clauses([C|Cs], Out) :-
    clean_clause(C, Cleaned),
    portray_clause(Out, Cleaned),
    process_clauses(Cs, Out).

clean_clause((H :- B), Result) :-
    !,
    apply_unify(B, B1),
    flatten_clean(B1, B2),
    ( B2 == true -> Result = H
    ; Result = (H :- B2)
    ).
clean_clause(H, H).

apply_unify(B, B) :- var(B), !.
apply_unify((A, B), (NA, NB)) :- !,
    apply_unify(A, NA),
    apply_unify(B, NB).
apply_unify((X = Y), R) :-
    !,
    ( unify_with_occurs_check(X, Y) -> R = true ; R = true ).
apply_unify((X == Y), R) :-
    !,
    ( unify_with_occurs_check(X, Y) -> R = true ; R = true ).
apply_unify((X \== Y), neq(X, Y)) :-
    !,
    ( neq_used -> true ; assertz(neq_used) ).
apply_unify(G, G).

flatten_clean(B, R) :-
    flatten_conj(B, Flat),
    list_from_conj(Flat, L),
    exclude(==(true), L, L1),
    ( L1 == [] -> R = true
    ; conj_from_list(L1, R)
    ).

flatten_conj((A, B), Flat) :-
    !,
    flatten_conj(A, FA),
    flatten_conj(B, FB),
    append_conj(FA, FB, Flat).
flatten_conj(A, A).

append_conj((A, B), C, (A, BC)) :- !, append_conj(B, C, BC).
append_conj(A, B, (A, B)).

list_from_conj((A, B), [A | Rest]) :- !, list_from_conj(B, Rest).
list_from_conj(A, [A]).

conj_from_list([A], A) :- !.
conj_from_list([A | T], (A, R)) :- conj_from_list(T, R).

%% Injection des helpers manquants

inject_missing(Out) :-
    ( neq_used      -> emit_neq(Out)        ; true ),
    ( length_used   -> emit_len_list(Out)   ; true ),
    %% member/2 est built-in dans gprolog → ne pas le réinjecter
    ( call_pred(loop_aux_1, 4), \+ def_pred(loop_aux_1, 4) -> emit_loop_aux_1(Out) ; true ),
    ( call_pred(loop_aux_2, 7), \+ def_pred(loop_aux_2, 7) -> emit_loop_aux_2(Out) ; true ).

emit_neq(Out) :-
    portray_clause(Out, (neq(A, B) :- A \== B)).

emit_len_list(Out) :-
    portray_clause(Out, len_list([], 0)),
    portray_clause(Out, (len_list([_|T], N) :- (len_list(T, N0), N is N0 + 1))).

emit_member(Out) :-
    portray_clause(Out, member(X, [X|_])),
    portray_clause(Out, (member(X, [_|T]) :- member(X, T))).

emit_loop_aux_1(Out) :-
    %% loop_aux_1(List, Key, Default, Result) : balayage de bal/2
    portray_clause(Out, loop_aux_1([], _, A, A)),
    portray_clause(Out, (loop_aux_1([bal(K, V)|_], K, _, V) :- !)),
    portray_clause(Out, (loop_aux_1([_|T], K, D, R) :- loop_aux_1(T, K, D, R))).

emit_loop_aux_2(Out) :-
    %% loop_aux_2(List, Key, NewVal, FoundIn, AccIn, FoundOut, AccOut)
    portray_clause(Out, loop_aux_2([], _, _, F, A, F, A)),
    portray_clause(Out, (loop_aux_2([bal(K, _)|T], K, V, _, A, FO, AO)
                        :- (!, loop_aux_2(T, K, V, 1, [bal(K, V)|A], FO, AO)))),
    portray_clause(Out, (loop_aux_2([bal(K, V)|T], K2, V2, F, A, FO, AO)
                        :- loop_aux_2(T, K2, V2, F, [bal(K, V)|A], FO, AO))).
