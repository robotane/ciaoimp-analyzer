% CiaoPP cost spec of auction (same shape as simple_auction, with the end
% flag in the state; build/executable/auction.pl).

:- module(_, [init/5, bid/7, end/5, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Beneficiary, AuctionEnd, HighestBidder, HighestBid, Ended);
% the bidder is the atom null until there is a bid.
:- regtype auctstate/1.
auctstate(state(Bene, End, HBidder, HBid, Ended)) :-
    atm(Bene), nnegint(End), atm(HBidder), nnegint(HBid), nnegint(Ended).

:- entry init(BiddingTime, Bene, Now, S0, S) :
    (nnegint(BiddingTime), atm(Bene), nnegint(Now), var(S0), var(S)).
:- entry bid(Caller, Amount, Now, S1, S2, B1, B2) :
    (atm(Caller), nnegint(Amount), nnegint(Now), auctstate(S1), var(S2),
     balances(B1), var(B2)).
:- entry end(Now, S1, S2, B1, B2) :
    (nnegint(Now), auctstate(S1), var(S2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
