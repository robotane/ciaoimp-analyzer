% Gradual Ponzi : chaque investissement >= 1000 est redistribué
% équitablement à tous les investisseurs précédents.
% Etat : state(ListeInvestisseurs)
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
    S := state([Caller]).

invest(Caller, Amount, !S, !B) :-
    state(Investors) = S,
    if (Amount >= 1000) {
        transfer(Caller, this, Amount, !B),
        Num := 0,
        for (_ in list(Investors)) { Num := Num + 1 },
        EachGets is Amount // Num,
        for (Inv in list(Investors)) {
            transfer(this, Inv, EachGets, !B)
        },
        S := state([Caller | Investors])
    }.

% --- Test ---
% Scenario : fondateur=alice, bob investit 1000 (alice recoit 1000),
%            charlie investit 2000 (alice+bob recoivent 1000 chacun).
% Attendu : alice=2000+1000=3000 (1000 init + 1000 + 1000),
%           bob=0+1000-2000+1000=0 => bob: 1000-1000+1000=1000,
%           charlie: 1000-2000=-1000... let me recalc:
% alice: 1000 init; bob investit 1000 -> alice+1000=2000, bob=1000-1000=0
%   charlie investit 2000 -> alice+1000=3000, bob+1000=1000, charlie=1000-2000=-1000
% this: starts 0, receives 1000 gives 1000, receives 2000 gives 2000 => 0

goal(Results) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(charlie, 1000), bal(this, 0)],
    init(alice, _, S1),
    invest(bob,     1000, S1, S2, B0, B1),
    invest(charlie, 2000, S2, _S3, B1, B2),
    AliceBal   is ~get_bal(alice,   B2),
    BobBal     is ~get_bal(bob,     B2),
    CharlieBal is ~get_bal(charlie, B2),
    ThisBal    is ~get_bal(this,    B2),
    Results = [AliceBal, BobBal, CharlieBal, ThisBal].
