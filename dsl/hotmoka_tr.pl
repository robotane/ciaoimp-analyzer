% Implicit costs of a Hotmoka contract, added at compile time.
%
% The Java programmer does not write these operations: Hotmoka performs them.
% The contract does not write them either; this translation adds them, before
% the statevars/fsyntax expansion (priority 600 < 610).
%
%  - Field of the contract. Hotmoka stores, at the end of the transaction, every
%    field the transaction modified. The fields of the contract are the state
%    variables (!X in the head of a clause), and a write is an assignment X := V.
%    Each such assignment becomes  store(field), X := V.
%
%  - Field of a storage object (an element of a collection: a paper, a
%    campaign...). The contract declares the class, as the Java does,
%        :- class(campaign(id, beneficiary, goal, amount, funders)).
%    (the arguments of the term, in order) and writes the field as the Java does
%    (campaign.amount = A):
%        set_field(Campaign0, amount, A, Campaign)
%    which becomes  store(field), Campaign0 = campaign(X1, X2, X3, _, X5),
%                   Campaign = campaign(X1, X2, X3, A, X5).
%    The same write is better written in one line, as in Java:
%        Campaign[amount] := A
%    which becomes  store(field), Campaign = campaign(X1, X2, X3, _, X5),
%                   Campaign := campaign(X1, X2, X3, A, X5).
%    A field name must belong to a single declared class of the module.
%
%    The same field is read as in Java (A = campaign.amount):
%        A = Campaign[amount]
%    which becomes  load(Campaign), Campaign = campaign(_, _, _, A, _).
%    Hotmoka loads a storage object once in a transaction, at its first use: only
%    the first read of an object on each execution path of a clause adds
%    load(Obj); the other reads of the same object on that path are the
%    unification alone. Each branch of an if/else or of a disjunction is a path
%    of its own: a branch that reads Obj has its load(Obj), even when another
%    branch read it already (see first_reads below).
%
%  - Payable method. Before a @Payable method runs, Hotmoka moves the amount
%    sent from the caller to the contract. The contract declares
%        :- payable(Name).
%    and every clause of Name, whose first two arguments are the caller and the
%    amount and whose last state variable is the coin balances, starts with
%        transfer(Caller, this, Amount, !Balances).
%
%    With the directive  :- bigint_cost.  the payable method also starts with
%        big_pay(Amount, 0)
%    (gas of the BigInteger operations of the payment, by size of Amount: see
%    hotmoka_gas.pl.in); without it, the cost of the payment is the constant of transfer/5.
%
%  - Guards. The contract writes the require of the Java as the Java does,
%        require(Cond)  or  require(Cond, Message)
%    and the translation replaces it by Cond itself, at compile time: no
%    predicate is called, so neither the gas bound nor the number of resolution
%    steps counted by CasLog changes (a failed require is a failed transaction,
%    as the Java exception). The message is dropped. A disjunction in Cond is
%    the short-circuit || of the Java: (A ; B) becomes (A -> true ; B), with no
%    choice point left (an unprotected ; would make CiaoPP count B even when A
%    succeeds and multiply what follows by the number of solutions). A
%    conjunction in Cond is spliced into the body, as if written without
%    require.
%
%  - Loops over a list. The contract writes the loop of the Ciao loops package,
%        for (X in list(L)) { Body }
%    Ciao expands it into a helper whose clauses take the list apart in their
%    body (Curr = [X|_], then Curr = [_|T]): CiaoPP then does not see that the
%    list gets shorter, and the bound is infinite. This translation expands the
%    loop itself, into the canonical recursion on the list:
%        p$forN([X|T], In..., !S...) :- Body, p$forN(T, In..., !S...).
%        p$forN([], In..., !S...).
%    In = the variables of Body also used elsewhere in the clause (inputs),
%    S = the state variables of Body (!S or S := V in Body).
%    The lists of a Hotmoka contract are storage collections (StorageLinkedList,
%    the entries of a StorageTreeMap/Set): the Java iteration reads one storage
%    node per element. Each iteration therefore starts with load(X):
%        p$forN([X|T], In..., !S...) :- load(X), Body, p$forN(T, In..., !S...).
%    (A Prolog list that is not a storage collection is not walked with for.)
%    The node is a distinct object from the element: a field read X[f] in Body
%    loads the element itself, once more.

:- module(hotmoka_tr, [tr/3], [datafacts]).

:- use_module(library(aggregates), [findall/3]).
:- use_module(library(lists), [length/2, append/3]).
:- use_module(library(terms_vars), [varset/2]).

:- data payable_pred/2.   % payable_pred(Module, Name)
:- data class_def/3.      % class_def(Module, Class, FieldNames)
:- data bigint_cost/1.    % bigint_cost(Module): the module asks for the cost by size
:- data loop_count/2.     % loop_count(Module, N): helpers of loops created so far

tr(end_of_file, end_of_file, Mod) :- !,
    retractall_fact(payable_pred(Mod, _)),
    retractall_fact(class_def(Mod, _, _)),
    retractall_fact(bigint_cost(Mod)),
    retractall_fact(loop_count(Mod, _)).
tr((:- bigint_cost), [], Mod) :- !,
    assertz_fact(bigint_cost(Mod)).
tr((:- payable(Names)), [], Mod) :- !,
    add_payable(Names, Mod).
tr((:- class(Spec)), [], Mod) :- !,
    Spec =.. [C|Fields],
    assertz_fact(class_def(Mod, C, Fields)).
tr((H :- B), Clauses, Mod) :- !,
    state_vars(H, SV),
    body(B, SV, Mod, B1),
    payable_prefix(H, SV, Mod, B1, B2),
    functor(H, Name, _),
    loops((H :- B2), Name, Mod, Clauses0),
    first_reads(Clauses0, Clauses).
tr(C, C, _).

add_payable((A, B), Mod) :- !, add_payable(A, Mod), add_payable(B, Mod).
add_payable(N/_, Mod) :- !, add_payable(N, Mod).
add_payable(N, Mod) :- atom(N), assertz_fact(payable_pred(Mod, N)).

% The state variables of a clause: the V of the arguments !V of its head.
state_vars(H, SV) :-
    H =.. [_|Args],
    sv_args(Args, SV).
sv_args([], []).
sv_args([A|As], [V|SV]) :- nonvar(A), A = '!'(V), var(V), !, sv_args(As, SV).
sv_args([_|As], SV) :- sv_args(As, SV).

memberv(X, [Y|_]) :- X == Y, !.
memberv(X, [_|T]) :- memberv(X, T).

% Every field write, anywhere in the body.
body(G, _, _, G) :- var(G), !.
body((R, B), SV, Mod, G) :- nonvar(R), require_cond(R, C), !,
    conj_append(C, B, G0),
    body(G0, SV, Mod, G).
body(R, SV, Mod, G) :- require_cond(R, C), !,
    body(C, SV, Mod, G).
body(':='(X, V), SV, _, (store(field), ':='(X, V))) :- var(X), memberv(X, SV), !.
body(set_field(O0, F, V, O), _, Mod, (store(field), '$hm_obj'(O0, T0), O = T)) :- !,
    field_terms(Mod, F, V, T0, T).
body(':='('\6\postfix_block'(O, [F]), V), _, Mod, (store(field), '$hm_obj'(O, T0), ':='(O, T))) :-
    var(O), atom(F), !,
    field_terms(Mod, F, V, T0, T).
body('='(V, '\6\postfix_block'(O, [F])), _, Mod, '$hm_read'(O, T, V)) :-
    var(O), atom(F), !,
    field_terms(Mod, F, V, _, T).
body(G, SV, Mod, G2) :-
    nonvar(G), functor(G, _, Ar), Ar > 0, !,
    G =.. [F|As],
    body_list(As, SV, Mod, As2),
    G2 =.. [F|As2].
body(G, _, _, G).
body_list([], _, _, []).
body_list([A|As], SV, Mod, [A2|As2]) :- body(A, SV, Mod, A2), body_list(As, SV, Mod, As2).

% require(Cond) and require(Cond, Message): the condition, unfolded.
require_cond(require(C), C1) :- req_goal(C, C1).
require_cond(require(C, _), C1) :- req_goal(C, C1).

req_goal(C, C) :- var(C), !.
req_goal((A ; B), (A -> true ; B1)) :- !, req_goal(B, B1).
req_goal(C, C).

% (A, B) with the conjunction A spliced: the body stays a flat conjunction.
conj_append(A, B, (A, B)) :- var(A), !.
conj_append((X, Y), B, (X, YB)) :- !, conj_append(Y, B, YB).
conj_append(A, B, (A, B)).

% T0 and T: the object before and after the write of field F with value V.
field_terms(Mod, F, V, T0, T) :-
    findall(C-Fs, (current_fact(class_def(Mod, C, Fs)), memberv(F, Fs)), [C-Fs]), !,
    length(Fs, N),
    length(Xs, N),
    replace(Fs, F, Xs, V, Ys),
    T0 =.. [C|Xs],
    T =.. [C|Ys].
field_terms(Mod, F, _, _, _) :-
    throw(error(hotmoka_tr(field_not_in_one_class(F)), Mod)).

replace([F1|Fs], F, [_|Xs], V, [V|Xs]) :- F1 == F, !, Fs = Fs.
replace([_|Fs], F, [X|Xs], V, [X|Ys]) :- replace(Fs, F, Xs, V, Ys).

% First read of an object in a clause: '$hm_read'(O, T, V) (V = O[f], T the
% term of the class with V at the place of f) becomes load(O) the first time O
% is read on an execution path, and no load after.
% The shape of O is unified once per version of O on a path: the first read or
% write of O gives O = c(X1,...,Xn); a later read of field f on the same path
% is V = Xf, a later write reuses X1..Xn (no new O = c(...)); O := T (a write)
% makes T the known shape of the new version. This is the same Prolog, with
% one unification of O with a structure instead of one per access: the
% non-failure analysis of CiaoPP takes minutes on a clause that unifies the
% same object with a structure several times (ballot.vote).
% reads(G, L0, L, G1): L0 = what is surely known before G, L = after G, as a
% list of r(O) (O loaded) and k(O, T) (O = T).
% A conjunction threads the set left to right. Every branch of a choice
% (if/else, A ; B, C -> T ; E) starts from the set before the choice, so each
% branch that reads O has its own load(O); after the choice, an object counts
% as read only if every branch read it, a shape is known only if every branch
% left the same term (intersection). The condition of an if counts for its
% then branch only. What runs zero or several times, or may stop part way
% (\+ G, while, findall, catch, any other goal with goal arguments), starts
% from the set before it and adds nothing after it.
first_reads([], []).
first_reads([(H :- B)|Cs], [(H :- B1)|Cs1]) :- !,
    reads(B, [], _, B0),
    none_true(B0, B1),
    first_reads(Cs, Cs1).
first_reads([C|Cs], [C|Cs1]) :- first_reads(Cs, Cs1).

reads(G, L, L, G) :- var(G), !.
reads('$hm_read'(O, T, V), L0, L, G) :- !,
    (   known(O, L0, T0), same_class(T, T0)
    ->  field_of(T, T0, V, X), G1 = (V = X), L1 = L0
    ;   G1 = (O = T), L1 = [k(O, T)|L0]
    ),
    (   loaded(O, L1)
    ->  G = G1, L = L1
    ;   G = (load(O), G1), L = [r(O)|L1]
    ).
reads('$hm_obj'(O, T0), L0, L, G) :- !,
    (   known(O, L0, T1), same_class(T0, T1)
    ->  T0 = T1, G = '$hm_none', L = L0
    ;   G = (O = T0), L = [k(O, T0)|L0]
    ).
reads(':='(O, T), L0, [k(O, T)|L1], ':='(O, T)) :- var(O), !,
    forget(O, L0, L1).
reads((A, B), L0, L, G) :- !,
    reads(A, L0, L1, A1),
    reads(B, L1, L, B1),
    ( A1 == '$hm_none' -> G = B1 ; B1 == '$hm_none' -> G = A1 ; G = (A1, B1) ).
% Imperative syntax of the loops package (still unexpanded at priority 600):
%   if (C) { T }              = if('\6\postfix_block'(C, {T}))
%   if (C) { T } else Else    = else(if(...), Else), Else = {E}, if(...) or else(...)
reads(else(if(PB), E), L0, L, else(if(PB1), E1)) :- !,
    reads_then(PB, L0, Lt, PB1),
    reads_branch(E, L0, Le, E1),
    meet(Lt, Le, L).
reads(if(PB), L0, L0, if(PB1)) :- !,
    reads_then(PB, L0, _, PB1).
reads('{}'(A), L0, L, '{}'(A1)) :- !,
    reads_branch(A, L0, L, A1).
% Prolog control: C -> T ; E, C *-> T ; E, A ; B, C -> T, \+ G.
reads((C -> T ; E), L0, L, (C1 -> T1 ; E1)) :- !,
    reads_branch(C, L0, Lc, C1), reads_branch(T, Lc, Lt, T1),
    reads_branch(E, L0, Le, E1),
    meet(Lt, Le, L).
reads(';'('*->'(C, T), E), L0, L, ';'('*->'(C1, T1), E1)) :- !,
    reads_branch(C, L0, Lc, C1), reads_branch(T, Lc, Lt, T1),
    reads_branch(E, L0, Le, E1),
    meet(Lt, Le, L).
reads((A ; B), L0, L, (A1 ; B1)) :- !,
    reads_branch(A, L0, La, A1),
    reads_branch(B, L0, Lb, B1),
    meet(La, Lb, L).
reads((C -> T), L0, L0, (C1 -> T1)) :- !,
    reads_branch(C, L0, Lc, C1), reads_branch(T, Lc, _, T1).
% Any other goal (\+, while, findall, ...): each argument starts from L0,
% nothing is added after it.
reads(G, L0, L0, G1) :-
    functor(G, F, Ar), Ar > 0, !,
    G =.. [F|As],
    reads_list(As, L0, As1),
    G1 =.. [F|As1].
reads(G, L, L, G).
reads_list([], _, []).
reads_list([A|As], L0, [A1|As1]) :-
    reads_branch(A, L0, _, A1), reads_list(As, L0, As1).

% A branch, '$hm_none' replaced by true.
reads_branch(A, L0, L, A2) :- reads(A, L0, L, A1), none_true(A1, A2).

% The condition and the then branch of an if: C, then T.
reads_then(PB, L0, Lt, '\6\postfix_block'(C1, '{}'(T1))) :-
    nonvar(PB), PB = '\6\postfix_block'(C, B), nonvar(B), B = '{}'(T), !,
    reads_branch(C, L0, Lc, C1),
    reads_branch(T, Lc, Lt, T1).
reads_then(PB, L0, L0, PB1) :-              % unknown form: conservative
    reads_branch(PB, L0, _, PB1).

none_true(G, true) :- G == '$hm_none', !.
none_true(G, G).

loaded(O, [E|Es]) :- ( nonvar(E), E = r(X), X == O -> true ; loaded(O, Es) ).
known(O, [E|Es], T) :- ( nonvar(E), E = k(X, T0), X == O -> T = T0 ; known(O, Es, T) ).
forget(_, [], []).
forget(O, [E|Es], R) :- E = k(X, _), X == O, !, forget(O, Es, R).
forget(O, [E|Es], [E|R]) :- forget(O, Es, R).

same_class(T, T0) :- nonvar(T), nonvar(T0), functor(T, C, N), functor(T0, C, N).

% V = O[f] with O = T0 known: the other places of T (fresh variables) are bound to
% those of T0; X is the place of f in T0.
field_of(T, T0, V, X) :-
    T =.. [_|Ys], T0 =.. [_|Xs],
    field_of_(Ys, Xs, V, X).
field_of_([Y|Ys], [X0|Xs], V, X) :-
    ( Y == V -> X = X0 ; Y = X0 ),
    field_of_(Ys, Xs, V, X).
field_of_([], [], _, _).

% What is known after a choice: what every branch knows.
meet([], _, []).
meet([E|Es], S, [E|R]) :- in_both(E, S), !, meet(Es, S, R).
meet([_|Es], S, R) :- meet(Es, S, R).
in_both(r(O), S) :- loaded(O, S).
in_both(k(O, T), S) :- known(O, S, T1), T1 == T.

payable_prefix(H, SV, Mod, B, (transfer(Caller, this, Amount, '!'(Bal)), P, B)) :-
    functor(H, N, _),
    current_fact(payable_pred(Mod, N)),
    current_fact(bigint_cost(Mod)), !,
    arg(1, H, Caller), arg(2, H, Amount),
    last(SV, Bal),
    P = big_pay(Amount, 0).
payable_prefix(H, SV, Mod, B, (transfer(Caller, this, Amount, '!'(Bal)), B)) :-
    functor(H, N, _),
    current_fact(payable_pred(Mod, N)), !,
    arg(1, H, Caller), arg(2, H, Amount),
    last(SV, Bal).
payable_prefix(_, _, _, B, B).

last([X], X) :- !.
last([_|T], X) :- last(T, X).

% --- Loops ---------------------------------------------------------------

loop_term(for('\6\postfix_block'(in(X, list(L)), '{}'(Body))), X, L, Body).

% loops(Clause, Name, Mod, Clauses): Clause with its loops replaced by calls to
% helpers, followed by the clauses of the helpers (themselves expanded).
loops((H :- B), Name, Mod, Clauses) :-
    first_loop(B, Loop, Marker, B1), !,
    loop_term(Loop, X, L, Body),
    varset((H :- B1), Rest),
    varset(Body, BV),
    loop_state(Body, BV, LS),
    del_vars(BV, [X, Marker|LS], BV1),
    inter_vars(BV1, Rest, In),
    new_helper(Name, Mod, P),
    sv_terms(LS, SVs),
    append(In, SVs, Extra),
    Call =.. [P, L|Extra],
    Marker = Call,
    copy_term(f(X, Extra, Body), f(X1, Extra1, Body1)),
    Rec =.. [P, [X1|T]|Extra1],              % one storage node read per element
    Next =.. [P, T|Extra1],
    copy_term(Extra1, Extra2),
    Base =.. [P, []|Extra2],
    loops((H :- B1), Name, Mod, C1),
    loops((Rec :- (load(X1), Body1, Next)), P, Mod, C2),
    append(C1, [Base|C2], Clauses).
loops(C, _, _, [C]).

% The first loop of a body (outermost, left to right), replaced by a fresh variable.
first_loop(G, _, _, _) :- var(G), !, fail.
first_loop(G, G, M, M) :- loop_term(G, _, _, _), !.
first_loop(G, Loop, M, G2) :-
    functor(G, F, A), A > 0,
    G =.. [F|As],
    first_loop_list(As, Loop, M, As2),
    G2 =.. [F|As2].
first_loop_list([A|As], Loop, M, [A2|As]) :- first_loop(A, Loop, M, A2), !.
first_loop_list([A|As], Loop, M, [A|As2]) :- first_loop_list(As, Loop, M, As2).

% The state variables of a loop body: V of !V or of V := _ in it.
loop_state(Body, BV, LS) :- st_vars(Body, [], LS0), keep_vars(BV, LS0, LS).
st_vars(G, Acc, Acc) :- var(G), !.
st_vars('!'(V), Acc, [V|Acc]) :- var(V), !.
st_vars(':='(V, E), Acc, Out) :- var(V), !, st_vars(E, [V|Acc], Out).
st_vars(G, Acc, Out) :- G =.. [_|As], st_list(As, Acc, Out).
st_list([], Acc, Acc).
st_list([A|As], Acc, Out) :- st_vars(A, Acc, Acc1), st_list(As, Acc1, Out).

keep_vars([], _, []).
keep_vars([V|Vs], S, [V|R]) :- memberv(V, S), !, keep_vars(Vs, S, R).
keep_vars([_|Vs], S, R) :- keep_vars(Vs, S, R).
del_vars([], _, []).
del_vars([V|Vs], S, R) :- memberv(V, S), !, del_vars(Vs, S, R).
del_vars([V|Vs], S, [V|R]) :- del_vars(Vs, S, R).
inter_vars(Vs, S, R) :- keep_vars(Vs, S, R).

sv_terms([], []).
sv_terms([V|Vs], ['!'(V)|Ts]) :- sv_terms(Vs, Ts).

new_helper(Name, Mod, P) :-
    ( current_fact(loop_count(Mod, N0)) -> true ; N0 = 0 ),
    N is N0 + 1,
    retractall_fact(loop_count(Mod, _)),
    assertz_fact(loop_count(Mod, N)),
    number_codes(N, Cs), atom_codes(NA, Cs),
    atom_concat(Name, '$for', P0), atom_concat(P0, NA, P).
