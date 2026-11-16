% CiaoPP cost spec of simple_auction (types as in interreg-imdea,
% march2026/simple_auction.pl, against build/executable/simple_auction.pl).

:- module(_, [init/5, bid/7, auction_end/5, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Beneficiary, AuctionEnd, HighestBid, HighestBidder); the
% bidder is the atom null until there is a bid.
:- regtype auctstate/1.
auctstate(state(Bene, End, HBid, HBidder)) :-
    atm(Bene), nnegint(End), nnegint(HBid), atm(HBidder).

:- entry init(BiddingTime, Bene, Now, S0, S) :
    (nnegint(BiddingTime), atm(Bene), nnegint(Now), var(S0), var(S)).
:- entry bid(Caller, Amount, Now, S1, S2, B1, B2) :
    (atm(Caller), nnegint(Amount), nnegint(Now), auctstate(S1), var(S2),
     balances(B1), var(B2)).
:- entry auction_end(Now, S1, S2, B1, B2) :
    (nnegint(Now), auctstate(S1), var(S2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
