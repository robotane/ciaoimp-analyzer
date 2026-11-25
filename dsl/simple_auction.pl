% Simple auction (Java: io.hotmoka.examples.auction.SimpleAuction).
% Bidders place increasing bids; the previous highest bidder is refunded; at the end the beneficiary is paid.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/4, bid/10, auction_end/9, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- entry bid(Caller, Amount, Now, End, HBid0, HBid, HBdr0, HBdr, B0, B) :
    (atm(Caller), int(Amount), int(Now), int(End), int(HBid0), var(HBid),
     atm(HBdr0), var(HBdr), balances(B0), var(B)).
:- entry auction_end(Bene, Now, End, HBid, HBdr0, HBdr, B0, B, Winner) :
    (atm(Bene), int(Now), int(End), int(HBid), atm(HBdr0), var(HBdr),
     balances(B0), var(B), var(Winner)).

% SimpleAuction(biddingTime, beneficiary)
init(BiddingTime, Now, End, Bidder) :-
    End = Now + BiddingTime,
    Bidder = null.

:- payable(bid).

% @FromContract bid(amount)
bid(Caller, Amount, Now, End, !HBid, !HBdr, !B) :-
    require(Now < End),
    require(Amount > HBid),
    if (HBdr \== null) {
        transfer(this, HBdr, HBid, !B)
    },
    HBdr := Caller,
    HBid := Amount,
    emit(bid_increase).

% auctionEnd()
auction_end(Bene, Now, End, HBid, !HBdr, !B, Winner) :-
    require(Now >= End),
    Winner = HBdr,
    if (Winner \== null) {
        transfer(this, Bene, HBid, !B),
        emit(auction_end),
        HBdr := null
    }.

% Test: alice bids 100, bob 200, end. Expected [bob, 1000, 800, 200, 0].
goal([W, A, Bo, Be, T]) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
    init(100, 0, End, H0),
    bid(alice, 100, 10, End, 0, HB1, H0, H1, B0, B1),
    bid(bob, 200, 20, End, HB1, HB2, H1, H2, B1, B2),
    auction_end(bene, 200, End, HB2, H2, _, B2, B3, W),
    balance(alice, B3, A),
    balance(bob, B3, Bo),
    balance(bene, B3, Be),
    balance(this, B3, T).
