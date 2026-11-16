% CiaoPP cost spec of auction on build/normalized/auction.pl (the CasLog
% input: the fields of state(Bene, End, HBidder, HBid, Ended) are arguments).

:- module(_, [init/9, bid/15, end/13, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% init(BiddingTime, Bene, Now, S0, Bene2, End2, HBidder2, HBid2, Ended2).
:- entry init(BT, Bene, Now, S0, B2, E2, HB2, HBid2, En2) :
    (nnegint(BT), atm(Bene), nnegint(Now), var(S0), var(B2), var(E2),
     var(HB2), var(HBid2), var(En2)).
% bid(Caller, Amount, Now, Bene, End, HBidder, HBid, Ended, <same 5 out>, B1, B2).
:- entry bid(Caller, Amount, Now, Bene, End, HB, HBid, Ended,
             Bene2, End2, HB2, HBid2, Ended2, B1, B2) :
    (atm(Caller), nnegint(Amount), nnegint(Now), atm(Bene), nnegint(End),
     atm(HB), nnegint(HBid), nnegint(Ended), var(Bene2), var(End2), var(HB2),
     var(HBid2), var(Ended2), balances(B1), var(B2)).
% end(Now, Bene, End, HBidder, HBid, Ended, <same 5 out>, B1, B2).
:- entry end(Now, Bene, End, HB, HBid, Ended,
             Bene2, End2, HB2, HBid2, Ended2, B1, B2) :
    (nnegint(Now), atm(Bene), nnegint(End), atm(HB), nnegint(HBid),
     nnegint(Ended), var(Bene2), var(End2), var(HB2), var(HBid2), var(Ended2),
     balances(B1), var(B2)).
:- entry goal(R) : var(R).
