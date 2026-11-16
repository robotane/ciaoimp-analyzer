% CiaoPP cost spec of blind_auction on build/normalized/blind_auction.pl (the
% CasLog input: the fields of the 6-field state are arguments).

:- module(_, [init/11, bid/18, reveal/19, auction_end/15, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% Bids: list of bid(Bidder, Hash, Amount), newest first.
:- regtype bids/1.
bids([]).
bids([B|T]) :- bidentry(B), bids(T).

:- regtype bidentry/1.
bidentry(bid(Who, Hash, Amount)) :- atm(Who), atm(Hash), int(Amount).

% State fields: Bene, BEnd, REnd, HBidder, HBid, Bids.
% init(BiddingTime, RevealTime, Caller, Now, S0, <6 state fields out>).
:- entry init(BT, RT, Caller, Now, S0, A, B, C, D, E, F) :
    (nnegint(BT), nnegint(RT), atm(Caller), nnegint(Now), var(S0), var(A),
     var(B), var(C), var(D), var(E), var(F)).
% bid(Caller, Amount, Now, Hash, <6 fields in>, <6 fields out>, B1, B2).
:- entry bid(Caller, Amount, Now, Hash, Bene, BEnd, REnd, HB, HBid, Bids,
             Bene2, BEnd2, REnd2, HB2, HBid2, Bids2, B1, B2) :
    (atm(Caller), nnegint(Amount), nnegint(Now), atm(Hash), atm(Bene),
     nnegint(BEnd), nnegint(REnd), atm(HB), nnegint(HBid), bids(Bids),
     var(Bene2), var(BEnd2), var(REnd2), var(HB2), var(HBid2), var(Bids2),
     balances(B1), var(B2)).
% reveal(Caller, Now, Hash, Value, Fake, <6 fields in>, <6 fields out>, B1, B2).
:- entry reveal(Caller, Now, Hash, Value, Fake, Bene, BEnd, REnd, HB, HBid,
                Bids, Bene2, BEnd2, REnd2, HB2, HBid2, Bids2, B1, B2) :
    (atm(Caller), nnegint(Now), atm(Hash), nnegint(Value), nnegint(Fake),
     atm(Bene), nnegint(BEnd), nnegint(REnd), atm(HB), nnegint(HBid),
     bids(Bids), var(Bene2), var(BEnd2), var(REnd2), var(HB2), var(HBid2),
     var(Bids2), balances(B1), var(B2)).
% auction_end(Now, <6 fields in>, <6 fields out>, B1, B2).
:- entry auction_end(Now, Bene, BEnd, REnd, HB, HBid, Bids,
                     Bene2, BEnd2, REnd2, HB2, HBid2, Bids2, B1, B2) :
    (nnegint(Now), atm(Bene), nnegint(BEnd), nnegint(REnd), atm(HB),
     nnegint(HBid), bids(Bids), var(Bene2), var(BEnd2), var(REnd2), var(HB2),
     var(HBid2), var(Bids2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
