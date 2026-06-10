% Entité partagée : les actionnaires peuvent mettre en vente leurs parts
% et les acheteurs peuvent accepter les offres.
% Etat : state(SharesList, Offers, NextId)
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

% --- Helpers ---

get_share(A, Shares, V) :-
    V := 0,
    for (Entry in list(Shares)) {
        Entry = sh(A1, V1),
        if (A == A1, V == 0) { V := V1 }
    }.

% --- Contrat ---

init(Shares, !S) :-
    S := state(Shares, [], 0).

place_offer(Amount, SharesOnSale, Caller, !S) :-
    state(SharesList, Offers, NextId) = S,
    get_share(Caller, SharesList, MyShares),
    if (MyShares >= SharesOnSale) {
        NewNextId is NextId + 1,
        Offers1 := [offer(NextId, Caller, Amount, SharesOnSale, 1) | Offers],
        S := state(SharesList, Offers1, NewNextId)
    }.

accept_offer(OfferId, Caller, Value, !S, !B) :-
    state(SharesList, Offers, NextId) = S,
    NewOffers := [],
    NewSharesList := SharesList,
    for (O in list(Offers)) {
        O = offer(Id, Seller, Amt, ShOnSale, Active),
        if (Id == OfferId, Active == 1, Value >= Amt) {
            transfer(Caller, this, Value, !B),
            transfer(this, Seller, Value, !B),
            get_share(Seller, NewSharesList, SellerShares),
            NewSS is SellerShares - ShOnSale,
            SL1 := [sh(Seller, NewSS) | NewSharesList],
            get_share(Caller, SL1, CallerShares),
            NewCS is CallerShares + ShOnSale,
            NewSharesList := [sh(Caller, NewCS) | SL1],
            NewOffers := [offer(Id, Seller, Amt, ShOnSale, 0) | NewOffers]
        } else {
            NewOffers := [O | NewOffers]
        }
    },
    S := state(NewSharesList, NewOffers, NextId).

% --- Test ---
% Scenario : alice=60 parts, bob=40 parts.
%   alice met en vente 20 parts à 500, charlie achète pour 500.
% Attendu : alice=500 ETH gagnés, charlie=500 ETH dépensés,
%           parts : alice=40, charlie=20, bob inchangé.

goal(Results) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(charlie, 1000), bal(this, 0)],
    init([sh(alice, 60), sh(bob, 40)], _, S1),
    place_offer(500, 20, alice, S1, S2),
    accept_offer(0, charlie, 500, S2, _S3, B0, B1),
    AliceBal   is ~get_bal(alice,   B1),
    BobBal     is ~get_bal(bob,     B1),
    CharlieBal is ~get_bal(charlie, B1),
    ThisBal    is ~get_bal(this,    B1),
    Results = [AliceBal, BobBal, CharlieBal, ThisBal].
