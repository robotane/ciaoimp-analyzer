% Distributeur : le propriétaire enregistre des bénéficiaires,
% puis distribue équitablement les fonds reçus.
% Etat : state(Owner, ListeBeneficiaires)
:- module(_, [goal/1], [fsyntax, statevars, hiord, loops]).
:- use_module(library(lists), [length/2]).
:- fun_eval arith(true).

% --- Infrastructure Blockchain ---

:- fun_eval get_bal/2.
get_bal(Addr, B) := Result :-
    Result := 0,
    for (Entry in list(B)) {
        Entry = bal(A, Val),
        if (A == Addr) { Result := Val }
    }.

set_bal(Addr, NewVal, !B) :-
    Acc := [],
    for (Entry in list(B)) {
        Entry = bal(A, V),
        if (A == Addr) {
            Acc := [bal(Addr, NewVal) | Acc]
        } else {
            Acc := [bal(A, V) | Acc]
        }
    },
    B := Acc.

transfer(From, To, Amount, !B) :-
    FB is ~get_bal(From, B),
    NewFB is FB - Amount,
    set_bal(From, NewFB, !B),
    TB is ~get_bal(To, B),
    NewTB is TB + Amount,
    set_bal(To, NewTB, !B).

% --- Contrat ---

init(Caller, !S) :-
    S := state(Caller, []).

add_as_payee(Caller, !S) :-
    state(Owner, Payees) = S,
    S := state(Owner, [Caller | Payees]).

distribute(Caller, Value, !S, !B) :-
    state(Owner, Payees) = S,
    length(Payees, Len),
    if (Len > 0) {
        transfer(Caller, this, Value, !B),
        EachGets is Value // Len,
        for (P in list(Payees)) {
            transfer(this, P, EachGets, !B)
        }
    }.

% --- Test ---
% Scenario : owner cree, alice+bob sont beneficiaires,
%            carol distribue 300 (150 chacun).
% Attendu : alice=1150, bob=1150, carol=700, this=0

goal(Results) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(carol, 1000), bal(this, 0)],
    init(owner, _, S1),
    add_as_payee(alice, S1, S2),
    add_as_payee(bob, S2, S3),
    distribute(carol, 300, S3, _, B0, B1),
    AliceBal is ~get_bal(alice, B1),
    BobBal   is ~get_bal(bob,   B1),
    CarolBal is ~get_bal(carol, B1),
    ThisBal  is ~get_bal(this,  B1),
    Results = [AliceBal, BobBal, CarolBal, ThisBal].
