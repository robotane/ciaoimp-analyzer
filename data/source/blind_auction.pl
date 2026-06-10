% Enchère aveugle : les enchères sont hashées pendant la phase d'enchere,
% révélées pendant la phase de révélation.
% Etat : state(Beneficiaire, BiddingEnd, RevealEnd, HBdr, HBid, AllBids)
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

init(BiddingTime, RevealTime, Beneficiary, Now, !S) :-
    AuctionEnd is Now + BiddingTime,
    RevealEnd is AuctionEnd + RevealTime,
    S := state(Beneficiary, AuctionEnd, RevealEnd, 'null', 0, []).

bid(Caller, Amount, Now, Hash, !S, !B) :-
    state(Bene, BiddingEnd, RevealEnd, HBdr, HBid, AllBids) = S,
    if (Now < BiddingEnd) {
        transfer(Caller, this, Amount, !B),
        S := state(Bene, BiddingEnd, RevealEnd, HBdr, HBid, [bid(Caller, Hash, Amount) | AllBids])
    }.

reveal(Caller, Now, Hash, Value, Fake, !S, !B) :-
    state(Bene, BiddingEnd, RevealEnd, HBdr, HBid, AllBids) = S,
    if (Now >= BiddingEnd, Now < RevealEnd) {
        Found := 0,
        SavedHash := 'null',
        Deposit := 0,
        NewBids := [],
        for (Bid in list(AllBids)) {
            Bid = bid(U, H, D),
            if (U == Caller, Found == 0) {
                Found := 1,
                SavedHash := H,
                Deposit := D
            } else {
                NewBids := [Bid | NewBids]
            }
        },
        if (Found == 1, SavedHash == Hash) {
            if (Fake == 0, Deposit >= Value, Value > HBid) {
                if (HBdr \== 'null') { transfer(this, HBdr, HBid, !B) },
                Refund is Deposit - Value,
                if (Refund > 0) { transfer(this, Caller, Refund, !B) },
                S := state(Bene, BiddingEnd, RevealEnd, Caller, Value, NewBids)
            } else {
                transfer(this, Caller, Deposit, !B),
                S := state(Bene, BiddingEnd, RevealEnd, HBdr, HBid, NewBids)
            }
        }
    }.

auction_end(Now, !S, !B) :-
    state(Bene, BiddingEnd, RevealEnd, HBdr, HBid, _AllBids) = S,
    if (Now >= RevealEnd) {
        if (HBdr \== 'null') { transfer(this, Bene, HBid, !B) },
        S := state(Bene, BiddingEnd, RevealEnd, HBdr, HBid, [])
    }.

% --- Test ---
% Scenario : alice encherit (depot=200, valeur=150, hash=h_alice),
%            bob encherit (depot=100, valeur=100, hash=h_bob),
%            revelation : alice revele 150 (gagnant), bob revele 100 (rembourse),
%            fin : bene recoit 150.
% Attendu : alice=1000-200+50=850, bob=1000-100+100=1000, bene=150, this=0

goal(Results) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
    init(100, 100, bene, 0, _, S1),
    bid(alice, 200, 10, h_alice, S1, S2, B0, B1),
    bid(bob,   100, 20, h_bob,   S2, S3, B1, B2),
    reveal(alice, 110, h_alice, 150, 0, S3, S4, B2, B3),
    reveal(bob,   120, h_bob,   100, 0, S4, S5, B3, B4),
    auction_end(210, S5, _, B4, B5),
    AliceBal is ~get_bal(alice, B5),
    BobBal   is ~get_bal(bob,   B5),
    BeneBal  is ~get_bal(bene,  B5),
    ThisBal  is ~get_bal(this,  B5),
    Results = [AliceBal, BobBal, BeneBal, ThisBal],
    !.
