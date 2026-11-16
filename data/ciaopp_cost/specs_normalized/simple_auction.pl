% CiaoPP cost spec of simple_auction on build/normalized/simple_auction.pl
% (the CasLog input: the fields of state(Bene, End, HBid, HBidder) are
% arguments).

:- module(_, [init/8, bid/13, auction_end/11, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% init(BiddingTime, Bene, Now, S0, Bene2, End2, HBid2, HBidder2).
:- entry init(BT, Bene, Now, S0, B2, E2, HBid2, HB2) :
    (nnegint(BT), atm(Bene), nnegint(Now), var(S0), var(B2), var(E2),
     var(HBid2), var(HB2)).
% bid(Caller, Amount, Now, Bene, End, HBid, HBidder, <4 fields out>, B1, B2).
:- entry bid(Caller, Amount, Now, Bene, End, HBid, HB,
             Bene2, End2, HBid2, HB2, B1, B2) :
    (atm(Caller), nnegint(Amount), nnegint(Now), atm(Bene), nnegint(End),
     nnegint(HBid), atm(HB), var(Bene2), var(End2), var(HBid2), var(HB2),
     balances(B1), var(B2)).
% auction_end(Now, Bene, End, HBid, HBidder, <4 fields out>, B1, B2).
:- entry auction_end(Now, Bene, End, HBid, HB, Bene2, End2, HBid2, HB2, B1, B2) :
    (nnegint(Now), atm(Bene), nnegint(End), nnegint(HBid), atm(HB),
     var(Bene2), var(End2), var(HBid2), var(HB2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
