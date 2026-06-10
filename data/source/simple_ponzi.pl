% Ponzi simple : chaque nouvel investisseur doit miser au moins 110% du
% precedent. La totalite de sa mise est reversee a l'investisseur precedent.
% Etat : state(DernierInvestisseur, DernierMontant)
:- module(_, [goal/1], [fsyntax, statevars, hiord, loops]).

% --- Infrastructure Blockchain ---
% Soldes : liste de bal(Adresse, Montant).

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

init(!S) :-
    S := state(null, 0).

invest(Caller, Value, !S, !B) :-
    state(LastInv, LastAmt) = S,
    Threshold is LastAmt * 11 // 10,
    if (Value > Threshold) {
        transfer(Caller, this, Value, !B),
        if (LastInv \== null) {
            transfer(this, LastInv, Value, !B)
        },
        S := state(Caller, Value)
    }.

% --- Scenario de test ---
% Appeler goal(R) pour verifier l'execution.
% R = [AliceSolde, BobSolde, ContratSolde]
% Attendu apres (alice:100, bob:120) : alice=1020, bob=880, this=0

goal(Results) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(this, 0)],
    init(_, S1),
    invest(alice, 100, S1, S2, B0, B1),
    invest(bob,   120, S2, _S3, B1, B2),
    AliceBal is ~get_bal(alice, B2),
    BobBal   is ~get_bal(bob,   B2),
    ThisBal  is ~get_bal(this,  B2),
    Results = [AliceBal, BobBal, ThisBal].
