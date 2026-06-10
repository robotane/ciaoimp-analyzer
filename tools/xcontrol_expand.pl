%% xcontrol_expand.pl — Expansion ciaopp -T → Prolog pur (niveau terme)
%%
%% Usage (compilé avec ciaoc) :
%%   ./xcontrol_expand input.pl output.pl [module_name]
%%
%% Pipeline :
%%   1. Normalisation  – formes bare \006 → xcontrol_rt:\006, opérateurs → basiccontrol:
%%   2. tr_clause/3    – SSA threading + expansion des boucles → closures $pa_def/$pa_call
%%   3. Lambda-lift    – $pa_def/$pa_call → prédicats nommés loop_aux_N
%%   4. Demodule       – suppression des préfixes de module
%%
%% Remplace expand_native (Python) dans runner.py — même interface :
%%   expand_native(input.pl, output.pl)

:- module(xcontrol_expand, [main/0], [datafacts]).

:- use_module(library(xsyntax/xcontrol_tr), [tr_clause/3]).
:- use_module(library(streams)).
:- use_module(library(read)).
:- use_module(library(write)).
:- use_module(library(lists), [append/3, member/2]).
:- use_module(library(format), [format/2]).
:- use_module(library(terms_vars), [term_variables/2]).
:- use_module(library(datafacts/datafacts_rt)).
:- use_module(engine(runtime_control), [current_prolog_flag/2]).

% ---------------------------------------------------------------------------
% Compteur global pour générer des noms uniques de prédicats auxiliaires
% ---------------------------------------------------------------------------

:- data aux_counter/1.
aux_counter(0).

fresh_aux_name(Name) :-
    retract_fact(aux_counter(N)),
    N1 is N + 1,
    assertz_fact(aux_counter(N1)),
    number_codes(N1, Codes),
    atom_codes(NumAtom, Codes),
    atom_concat('loop_aux_', NumAtom, Name).

% ---------------------------------------------------------------------------
% 1. Normalisation
%
% Convertit la sortie de ciaopp -T en forme attendue par tr_clause/3.
% Tous les variants d'un opérateur (bare ou qualifié) sont mappés vers la
% forme canonique attendue, et les wrappers M:Body sont strippés.
% ---------------------------------------------------------------------------

%% Functor/Arité → forme canonique exigée par tr_clause.
canonical_op(',',                       2, 'basiccontrol:,').
canonical_op('basiccontrol:,',          2, 'basiccontrol:,').
canonical_op(';',                       2, 'basiccontrol:;').
canonical_op('basiccontrol:;',          2, 'basiccontrol:;').
canonical_op('->',                      2, 'basiccontrol:->').
canonical_op('basiccontrol:->',         2, 'basiccontrol:->').
canonical_op('\\+',                     1, 'basiccontrol:\\+').
canonical_op('basiccontrol:\\+',        1, 'basiccontrol:\\+').
canonical_op('\006\assign',             2, 'xcontrol_rt:\006\assign').
canonical_op('xcontrol_rt:\006\assign', 2, 'xcontrol_rt:\006\assign').
canonical_op('\006\loop',               5, 'xcontrol_rt:\006\loop').
canonical_op('xcontrol_rt:\006\loop',   5, 'xcontrol_rt:\006\loop').

norm(X, X) :- var(X), !.

%% Wrapper M:Body : strip et normaliser le corps.
norm(T, R) :- functor(T, ':', 2), !, arg(2, T, Body), norm(Body, R).

%% Opérateur / primitive reconnu : remplacer le functor par sa forme canonique.
norm(T, R) :-
    functor(T, F, N),
    canonical_op(F, N, Canonical), !,
    norm_args(T, 1, N, NArgs),
    R =.. [Canonical | NArgs].

%% Terme quelconque : récurser sur les arguments, garder le functor.
norm(T, R) :-
    functor(T, F, N),
    norm_args(T, 1, N, NArgs),
    R =.. [F | NArgs].

norm_args(_, I, N, []) :- I > N, !.
norm_args(T, I, N, [NA | Rest]) :-
    arg(I, T, A),
    norm(A, NA),
    I1 is I + 1,
    norm_args(T, I1, N, Rest).

% ---------------------------------------------------------------------------
% 2. Application de tr_clause/3 (SSA threading + expansion des boucles)
% ---------------------------------------------------------------------------

apply_tr(clause(H, B), M, Out) :-
    norm(B, NB),
    preprocess_state_copy(H, NB, H2, NB2),
    ( tr_clause(clause(H2, NB2), Out, M) ->
        true
    ;
        format("WARN: tr_clause a échoué pour ~q\n", [H]),
        Out = clause(H2, NB2)
    ).

% ---------------------------------------------------------------------------
% Pre-processing: detect 'term_basic:='(OutVar, InVar) at start of body
% where both vars appear in head → convert to \006\before/\006\after pattern
% so that tr_clause correctly threads state via p_env__finish.
%
% Pattern: head(A, B, In, Out) :- 'term_basic:='(Out, In), ..., \006\assign(In, FinalVal)
% becomes: head(A, B, '\006\before'(In), '\006\after'(In)) :- ..., \006\assign(In, FinalVal)
% ---------------------------------------------------------------------------

preprocess_state_copy(Head, Body, NewHead, NewBody) :-
    extract_initial_copy(Body, OutVar, InVar, RestBody),
    var(OutVar), var(InVar),
    term_variables(Head, HVars),
    var_member(OutVar, HVars),
    var_member(InVar, HVars), !,
    replace_var_in_head(Head, InVar,  '\006\before'(InVar), Head1),
    replace_var_in_head(Head1, OutVar, '\006\after'(InVar),  NewHead),
    NewBody = RestBody.
preprocess_state_copy(Head, Body, Head, Body).

var_member(V, [H|_]) :- V == H, !.
var_member(V, [_|T]) :- var_member(V, T).

%% extract_initial_copy/4: pull 'term_basic:='(Out,In) from beginning of conjunction
extract_initial_copy('term_basic:='(Out, In), Out, In, true) :- !.
extract_initial_copy(Body, Out, In, Rest) :-
    functor(Body, ',', 2), !,
    arg(1, Body, First),
    First = 'term_basic:='(Out, In),
    arg(2, Body, Rest).
extract_initial_copy(Body, Out, In, Rest) :-
    functor(Body, 'basiccontrol:,', 2), !,
    arg(1, Body, First),
    First = 'term_basic:='(Out, In),
    arg(2, Body, Rest).

%% replace_var_in_head/4: replace a specific variable occurrence in head args
replace_var_in_head(Head, Var, Replacement, NewHead) :-
    Head =.. [F | Args],
    replace_var_in_args(Args, Var, Replacement, NewArgs),
    NewHead =.. [F | NewArgs].

replace_var_in_args([], _, _, []).
replace_var_in_args([A | Rest], Var, Repl, [NA | NRest]) :-
    replace_var_in_args(Rest, Var, Repl, NRest),
    ( A == Var ->
        NA = Repl
    ;
        NA = A
    ).


% ---------------------------------------------------------------------------
% 3. Lambda-lifting
%
% Traverse le corps résultant de tr_clause/3, qui contient :
%   'hiord_rt:$pa_def'(Mode, -NegShVs, clause(Head, Body), PA)
%   'hiord_rt:$pa_call'(PA, ''(Arg1,...))
%
% Algorithme :
%   1. À chaque $pa_def : lier PA à un nom frais (propage aux $pa_call qui partagent la variable)
%                         Générer un prédicat toplevel Name(Args) :- Body_lifté
%                         Remplacer $pa_def par true dans la position courante
%   2. À chaque $pa_call(PA, ''(Args)) : PA est déjà lié → Call =.. [PA|Args]
% ---------------------------------------------------------------------------

lambdalift(Body, Helpers, Clean) :-
    lambdalift_(Body, Helpers, Clean).

lambdalift_(X, [], X) :- var(X), !.

%% $pa_def : créer prédicat nommé, lier PA à un token (Nom + variables capturées).
%%
%% Les variables partagées (arg 2 du $pa_def) sont les variables de la portée
%% englobante référencées dans le corps de la closure. Elles doivent devenir
%% des arguments supplémentaires du prédicat extrait, et être propagées à
%% chaque site d'appel correspondant.
%%
%% Cas spéciaux à filtrer :
%%   - PA lui-même dans les shared vars : auto-référence (récursion). On l'exclut
%%     puisque le nom du prédicat suffit.
%%   - Variable déjà présente dans ClosureArgs : tr_clause a déjà plumbé cette
%%     variable via les arguments de la closure. La ré-ajouter créerait des
%%     duplications dans la tête (ex. loop_aux(B,A,A,B,...) qui force une
%%     unification erronée au site d'appel).
lambdalift_(T, Helpers, true) :-
    functor(T, 'hiord_rt:$pa_def', 4), !,
    arg(2, T, SharedVars0),
    arg(3, T, PACode),
    arg(4, T, PA),
    PACode = clause(H, B),
    fresh_aux_name(Name),
    H =.. [_ | ClosureArgs],
    filter_shared(SharedVars0, PA, ClosureArgs, SharedVars),
    PA = '$pa_token'(Name, SharedVars),
    append(SharedVars, ClosureArgs, AllArgs),
    NewHead =.. [Name | AllArgs],
    lambdalift_(B, NestedH, B2),
    demod(B2, DB2),
    Helpers = [(NewHead :- DB2) | NestedH].

%% $pa_call : PA lié à un token → on extrait nom + shared vars et on les
%% préfixe aux arguments effectifs de l'appel.
lambdalift_(T, [], Call) :-
    functor(T, 'hiord_rt:$pa_call', 2), !,
    arg(1, T, PA),
    arg(2, T, ArgsT),
    ArgsT =.. [_ | Args],
    ( nonvar(PA), PA = '$pa_token'(Name, SharedVars) ->
        append(SharedVars, Args, AllArgs),
        Call =.. [Name | AllArgs]
    ; nonvar(PA), atom(PA) ->
        Call =.. [PA | Args]
    ;
        Call = T   % ne devrait pas arriver si $pa_def précède
    ).

%% Conjonction basiccontrol:,
lambdalift_(T, Helpers, Clean) :-
    functor(T, 'basiccontrol:,', 2), !,
    arg(1,T,A), arg(2,T,B),
    lambdalift_(A, HA, CA),
    lambdalift_(B, HB, CB),
    append(HA, HB, Helpers),
    ( CA == true -> Clean = CB
    ; CB == true -> Clean = CA
    ; Clean =.. [',', CA, CB]
    ).

%% Tout autre but composé (disjonction, if-then, négation, appels) : récurser
%% sur les arguments en conservant le functor. demod nettoie les préfixes ensuite.
lambdalift_(T, Helpers, Clean) :-
    functor(T, F, N),
    N > 0, !,
    lambdalift_args(T, 1, N, Helpers, NArgs),
    Clean =.. [F | NArgs].

lambdalift_(T, [], T).

lambdalift_args(_, I, N, [], []) :- I > N, !.
lambdalift_args(T, I, N, Helpers, [NA | NRest]) :-
    arg(I, T, A),
    lambdalift_(A, HA, NA),
    I1 is I + 1,
    lambdalift_args(T, I1, N, HRest, NRest),
    append(HA, HRest, Helpers).

%% Filtre les shared vars : exclure PA (auto-ref) et celles déjà dans ClosureArgs.
filter_shared([], _, _, []).
filter_shared([V | Rest], PA, ClosureArgs, R) :-
    ( V == PA ->
        filter_shared(Rest, PA, ClosureArgs, R)
    ; member_eq(V, ClosureArgs) ->
        filter_shared(Rest, PA, ClosureArgs, R)
    ;
        R = [V | RT],
        filter_shared(Rest, PA, ClosureArgs, RT)
    ).

member_eq(V, [H | _]) :- V == H, !.
member_eq(V, [_ | T]) :- member_eq(V, T).

% ---------------------------------------------------------------------------
% 4. Demodule
%
% Supprime les préfixes de module des buts après transformation.
% Convertit 'basiccontrol:,' → ',', 'term_basic:=' → '=', etc.
% ---------------------------------------------------------------------------

demod(X, X) :- var(X), !.
demod(T, R) :-
    functor(T, F, N), N > 0,
    module_local_name(F, Local), !,
    demod_args(T, 1, N, NArgs),
    R =.. [Local | NArgs].
demod(T, R) :-
    functor(T, F, N), N > 0, !,
    demod_args(T, 1, N, NArgs),
    R =.. [F | NArgs].
demod(T, T).

demod_args(_, I, N, []) :- I > N, !.
demod_args(T, I, N, [NA | Rest]) :-
    arg(I, T, A),
    demod(A, NA),
    I1 is I + 1,
    demod_args(T, I1, N, Rest).

%% Trouver le dernier ':' dans le nom et extraire la partie locale.
%% Couvre uniformément 'basiccontrol:,' → ',', 'term_basic:=' → '=',
%% 'arithmetic:is' → 'is', etc. Les noms commençant par \006 sont préservés.
module_local_name(F, Local) :-
    atom(F),
    atom_codes(F, Codes),
    last_colon_split(Codes, PrefixCodes, LocalCodes),
    PrefixCodes \= [],           % empty prefix means bare operator like :- or :=
    LocalCodes \= [],
    % Ne pas dépouiller les noms internes Ciao (\006...)
    \+ LocalCodes = [6 | _],
    atom_codes(Prefix, PrefixCodes),
    strippable_module(Prefix),
    atom_codes(Local, LocalCodes).

%% Modules dont on supprime le préfixe — catch-all strips any module qualifier
strippable_module(_).

%% Trouver le dernier ':' dans une liste de codes
last_colon_split(Codes, Prefix, Suffix) :-
    append(Prefix, [0': | Suffix], Codes),
    \+ member(0':, Suffix).

% ---------------------------------------------------------------------------
% 5. Traitement d'une clause
% ---------------------------------------------------------------------------

process_clause(Term, M, OutClauses) :-
    ( Term = (H :- B) ->
        apply_tr(clause(H, B), M, clause(H2, B2)),
        lambdalift(B2, Helpers, CB),
        demod((H2 :- CB), MainClause),
        demod_helpers(Helpers, DHelpers),
        OutClauses = [MainClause | DHelpers]
    ; functor(Term, ':-', 1) ->
        % Directive : ignorer (module déclarations, etc.)
        OutClauses = []
    ;
        % Fait simple
        demod(Term, DTerm),
        OutClauses = [DTerm]
    ).

demod_helpers([], []).
demod_helpers([(H :- B) | Rest], [DClause | DRest]) :-
    demod((H :- B), DClause),
    demod_helpers(Rest, DRest).
demod_helpers([H | Rest], [DH | DRest]) :-
    demod(H, DH),
    demod_helpers(Rest, DRest).

% ---------------------------------------------------------------------------
% 6. Lecture / écriture de fichiers
% ---------------------------------------------------------------------------

read_clauses(File, Clauses) :-
    open(File, read, S),
    read_all(S, Clauses),
    close(S).

read_all(S, Clauses) :-
    read_term(S, T, []),
    ( T == end_of_file ->
        Clauses = []
    ;
        Clauses = [T | Rest],
        read_all(S, Rest)
    ).

write_clauses(File, Clauses) :-
    open(File, write, S),
    write_all(S, Clauses),
    close(S).

write_all(_, []).
write_all(S, [C | Rest]) :-
    % Copie locale : lambda-lifting peut partager des variables entre la
    % clause principale et ses helpers ; sans copie, numbervars assignerait
    % les mêmes $VAR(N) à des variables distinctes dans des clauses
    % différentes, créant de fausses duplications à l'affichage.
    copy_term(C, CCopy),
    numbervars(CCopy, 0, _),
    portray_clause(S, CCopy),
    nl(S),
    write_all(S, Rest).

% ---------------------------------------------------------------------------
% Main
% ---------------------------------------------------------------------------

main :-
    current_prolog_flag(argv, Args),
    ( Args = [InFile, OutFile | Rest] ->
        ( Rest = [Module] -> true ; Module = user ),
        format("xcontrol_expand: ~w -> ~w (module ~w)\n", [InFile, OutFile, Module]),
        read_clauses(InFile, Clauses),
        process_all(Clauses, Module, OutClauses),
        write_clauses(OutFile, OutClauses),
        format("xcontrol_expand: ok (~w clauses)\n", [OutClauses]),
        halt
    ;
        format("Usage: xcontrol_expand input.pl output.pl [module]\n", []),
        halt(1)
    ).

process_all([], _, []).
process_all([T | Ts], M, Out) :-
    ( process_clause(T, M, Cs) ->
        true
    ;
        format("WARN: clause ignoree: ~q\n", [T]),
        Cs = []
    ),
    process_all(Ts, M, RestOut),
    append(Cs, RestOut, Out).
