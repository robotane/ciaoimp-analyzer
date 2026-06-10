% Enchère simple : le bénéficiaire fixe un délai ; le plus offrant emporte.
% Etat : state(Beneficiaire, FinEnchere, MeilleurEncherisseur, MeilleureMise, Terminee)
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

init(BiddingTime, Beneficiary, Now, !S) :-
    AuctionEnd is Now + BiddingTime,
    S := state(Beneficiary, AuctionEnd, 'null', 0, 0).

bid(Caller, Amount, Now, !S, !B) :-
    state(Bene, AuctionEnd, HighestBidder, HighestBid, Ended) = S,
    if (Now < AuctionEnd, Amount > HighestBid, Ended == 0) {
        transfer(Caller, this, Amount, !B),
        if (HighestBidder \== 'null') {
            transfer(this, HighestBidder, HighestBid, !B)
        },
        S := state(Bene, AuctionEnd, Caller, Amount, Ended)
    }.

end(Now, !S, !B) :-
    state(Bene, AuctionEnd, HighestBidder, HighestBid, Ended) = S,
    if (Now >= AuctionEnd, Ended == 0) {
        transfer(this, Bene, HighestBid, !B),
        S := state(Bene, AuctionEnd, HighestBidder, HighestBid, 1)
    }.

% --- Test ---
% Scenario : alice mise 100, bob mise 150, alice tente 120 (refusee), fin.
% Attendu : alice=900, bob=850, bene=150, this=0

goal(Results) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
    init(100, bene, 0, _, S1),
    bid(alice, 100, 10, S1, S2, B0, B1),
    bid(bob,   150, 20, S2, S3, B1, B2),
    bid(alice, 120, 30, S3, S4, B2, B3),   % refusee : 120 < 150
    end(200, S4, _, B3, B4),
    AliceBal is ~get_bal(alice, B4),
    BobBal   is ~get_bal(bob,   B4),
    BeneBal  is ~get_bal(bene,  B4),
    ThisBal  is ~get_bal(this,  B4),
    Results = [AliceBal, BobBal, BeneBal, ThisBal].
