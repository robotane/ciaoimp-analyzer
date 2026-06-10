% Enchère simple sans dépôt préalable.
% Etat : state(Beneficiaire, FinEnchere, MeilleureMise, MeilleurEncherisseur)
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
    S := state(Beneficiary, AuctionEnd, 0, 'null').

bid(Caller, Amount, Now, !S, !B) :-
    state(Bene, AuctionEnd, HighestBid, HighestBidder) = S,
    if (Now < AuctionEnd, Amount > HighestBid) {
        transfer(Caller, this, Amount, !B),
        if (HighestBidder \== 'null') {
            transfer(this, HighestBidder, HighestBid, !B)
        },
        S := state(Bene, AuctionEnd, Amount, Caller)
    }.

auction_end(Now, !S, !B) :-
    state(Bene, AuctionEnd, HighestBid, HighestBidder) = S,
    if (Now >= AuctionEnd, HighestBidder \== 'null') {
        transfer(this, Bene, HighestBid, !B),
        S := state(Bene, AuctionEnd, HighestBid, 'null')
    }.

% --- Test ---
% Scenario : alice=100, bob=200, fin. Attendu : alice=900, bob=800, bene=200, this=0

goal(Results) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
    init(100, bene, 0, _, S1),
    bid(alice, 100, 10, S1, S2, B0, B1),
    bid(bob,   200, 20, S2, S3, B1, B2),
    auction_end(200, S3, _, B2, B3),
    AliceBal is ~get_bal(alice, B3),
    BobBal   is ~get_bal(bob,   B3),
    BeneBal  is ~get_bal(bene,  B3),
    ThisBal  is ~get_bal(this,  B3),
    Results = [AliceBal, BobBal, BeneBal, ThisBal].
