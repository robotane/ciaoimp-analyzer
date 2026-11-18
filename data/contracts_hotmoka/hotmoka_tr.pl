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
%  - Payable method. Before a @Payable method runs, Hotmoka moves the amount
%    sent from the caller to the contract. The contract declares
%        :- payable(Name).
%    and every clause of Name, whose first two arguments are the caller and the
%    amount and whose last state variable is the coin balances, starts with
%        transfer(Caller, this, Amount, !Balances).
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

:- module(hotmoka_tr, [tr/3], [datafacts]).

:- use_module(library(aggregates), [findall/3]).
:- use_module(library(lists), [length/2, append/3]).
:- use_module(library(terms_vars), [varset/2]).

:- data payable_pred/2.   % payable_pred(Module, Name)
:- data class_def/3.      % class_def(Module, Class, FieldNames)
:- data loop_count/2.     % loop_count(Module, N): helpers of loops created so far

tr(end_of_file, end_of_file, Mod) :- !,
    retractall_fact(payable_pred(Mod, _)),
    retractall_fact(class_def(Mod, _, _)),
    retractall_fact(loop_count(Mod, _)).
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
    loops((H :- B2), Name, Mod, Clauses).
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
body(':='(X, V), SV, _, (store(field), ':='(X, V))) :- var(X), memberv(X, SV), !.
body(set_field(O0, F, V, O), _, Mod, (store(field), O0 = T0, O = T)) :- !,
    field_terms(Mod, F, V, T0, T).
body(':='('\6\postfix_block'(O, [F]), V), _, Mod, (store(field), O = T0, ':='(O, T))) :-
    var(O), atom(F), !,
    field_terms(Mod, F, V, T0, T).
body(G, SV, Mod, G2) :-
    nonvar(G), functor(G, _, Ar), Ar > 0, !,
    G =.. [F|As],
    body_list(As, SV, Mod, As2),
    G2 =.. [F|As2].
body(G, _, _, G).
body_list([], _, _, []).
body_list([A|As], SV, Mod, [A2|As2]) :- body(A, SV, Mod, A2), body_list(As, SV, Mod, As2).

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
    Rec =.. [P, [X1|T]|Extra1],
    Next =.. [P, T|Extra1],
    copy_term(Extra1, Extra2),
    Base =.. [P, []|Extra2],
    loops((H :- B1), Name, Mod, C1),
    loops((Rec :- (Body1, Next)), P, Mod, C2),
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
