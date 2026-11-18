% Simple auction (Java: io.hotmoka.examples.auction.SimpleAuction).
% Bidders place increasing bids; the previous highest bidder is refunded; at the
% end the beneficiary receives the highest bid.
% State: Bene (beneficiary), End (auctionEnd), HBid (highestBid), HBdr (highestBidder, or null).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/4, bid/10, auction_end/9, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).                       % arithmetic is computed, as in Java

:- entry bid(Caller, Amount, Now, End, HBid0, HBid, HBdr0, HBdr, B0, B) :
    (atm(Caller), int(Amount), int(Now), int(End), int(HBid0), var(HBid),
     atm(HBdr0), var(HBdr), balances(B0), var(B)).
:- entry auction_end(Bene, Now, End, HBid, HBdr0, HBdr, B0, B, Winner) :
    (atm(Bene), int(Now), int(End), int(HBid), atm(HBdr0), var(HBdr),
     balances(B0), var(B), var(Winner)).

% SimpleAuction(biddingTime, beneficiary)
init(BiddingTime, Now, End, Bidder) :-
    End = Now + BiddingTime,                        % auctionEnd = now() + biddingTime
    Bidder = null.

:- payable(bid).                             % @Payable: the amount sent is received first

% @FromContract bid(amount)
bid(Caller, Amount, Now, End, !HBid, !HBdr, !B) :-
    Now < End,                                      % require(now() < auctionEnd)
    Amount > HBid,                                  % require(amount > highestBid)
    if (HBdr \== null) {
        transfer(this, HBdr, HBid, !B)              % highestBidder.receive(highestBid)
    },
    HBdr := Caller,                                 % highestBidder = caller()
    HBid := Amount,                                 % highestBid = amount
    emit(bid_increase).                             % event(new BidIncrease(highestBidder, amount))

% auctionEnd()
auction_end(Bene, Now, End, HBid, !HBdr, !B, Winner) :-
    Now >= End,                                     % require(now() >= auctionEnd)
    Winner = HBdr,                                  % winner = highestBidder
    if (Winner \== null) {
        transfer(this, Bene, HBid, !B),             % beneficiary.receive(highestBid)
        emit(auction_end),                          % event(new AuctionEnd(winner, highestBid))
        HBdr := null                                % highestBidder = null
    }.

% --- Test: auction of 100 ms; alice bids 100, bob bids 200, end ---
% Expected: [bob, 1000, 800, 200, 0] = winner bob, alice refunded, beneficiary 200.
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
