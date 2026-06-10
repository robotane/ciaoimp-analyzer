% Pyramide simple : chaque investissement doit dépasser 110% du précédent.
% La mise est redistribuée équitablement à tous les investisseurs précédents.
% Etat : state(ListeInvestisseurs, DernierMontant)
:- module(_, [goal/1], [fsyntax, statevars, hiord, loops]).
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
    S := state([Caller], 1000).

invest(Caller, Amount, !S, !B) :-
    state(Investors, PrevAmt) = S,
    Threshold is PrevAmt * 11 // 10,
    if (Amount >= Threshold) {
        transfer(Caller, this, Amount, !B),
        Num := 0,
        for (_ in list(Investors)) { Num := Num + 1 },
        EachGets is Amount // Num,
        for (Inv in list(Investors)) {
            transfer(this, Inv, EachGets, !B)
        },
        S := state([Caller | Investors], Amount)
    }.

% --- Test ---
% Scenario : fondateur=alice (seuil initial=1000),
%   bob investit 1100 (>= 1100) -> alice recoit 1100, bob est ajouté
%   charlie investit 1210 (>= 1210) -> alice+bob recoivent 605 chacun
% Attendu :
%   alice : 1000 - 0 + 1100 + 605 = 2705
%   bob   : 2000 - 1100 + 605 = 1505
%   charlie: 1000 - 1210 = -210  (dette)
%   this  : 0

goal(Results) :-
    B0 = [bal(alice, 1000), bal(bob, 2000), bal(charlie, 1500), bal(this, 0)],
    init(alice, _, S1),
    invest(bob,     1100, S1, S2, B0, B1),
    invest(charlie, 1210, S2, _S3, B1, B2),
    AliceBal   is ~get_bal(alice,   B2),
    BobBal     is ~get_bal(bob,     B2),
    CharlieBal is ~get_bal(charlie, B2),
    ThisBal    is ~get_bal(this,    B2),
    Results = [AliceBal, BobBal, CharlieBal, ThisBal].
