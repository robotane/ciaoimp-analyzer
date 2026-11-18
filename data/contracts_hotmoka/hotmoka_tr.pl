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
%    A field name must belong to a single declared class of the module.
%
%  - Payable method. Before a @Payable method runs, Hotmoka moves the amount
%    sent from the caller to the contract. The contract declares
%        :- payable(Name).
%    and every clause of Name, whose first two arguments are the caller and the
%    amount and whose last state variable is the coin balances, starts with
%        transfer(Caller, this, Amount, !Balances).

:- module(hotmoka_tr, [tr/3], [datafacts]).

:- use_module(library(aggregates), [findall/3]).
:- use_module(library(lists), [length/2]).

:- data payable_pred/2.   % payable_pred(Module, Name)
:- data class_def/3.      % class_def(Module, Class, FieldNames)

tr(end_of_file, end_of_file, Mod) :- !,
    retractall_fact(payable_pred(Mod, _)),
    retractall_fact(class_def(Mod, _, _)).
tr((:- payable(Names)), [], Mod) :- !,
    add_payable(Names, Mod).
tr((:- class(Spec)), [], Mod) :- !,
    Spec =.. [C|Fields],
    assertz_fact(class_def(Mod, C, Fields)).
tr((H :- B), (H :- B2), Mod) :- !,
    state_vars(H, SV),
    body(B, SV, Mod, B1),
    payable_prefix(H, SV, Mod, B1, B2).
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
