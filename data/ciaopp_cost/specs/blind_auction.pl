% CiaoPP cost spec of blind_auction (types as in interreg-imdea,
% march2026/bind_auction.pl, against build/executable/blind_auction.pl).

:- module(_, [init/6, bid/8, reveal/9, auction_end/5, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Beneficiary, BiddingEnd, RevealEnd, HighestBidder,
% HighestBid, Bids). The bidder is the atom null until a bid is revealed;
% Bids is the list of bid(Bidder, Hash, Amount), newest first.
:- regtype bids/1.
bids([]).
bids([B|T]) :- bidentry(B), bids(T).

:- regtype bidentry/1.
bidentry(bid(Who, Hash, Amount)) :- atm(Who), atm(Hash), int(Amount).

:- regtype blindstate/1.
blindstate(state(Bene, BEnd, REnd, HBidder, HBid, Bids)) :-
    atm(Bene), nnegint(BEnd), nnegint(REnd), atm(HBidder), nnegint(HBid),
    bids(Bids).

:- entry init(BiddingTime, RevealTime, Caller, Now, S0, S) :
    (nnegint(BiddingTime), nnegint(RevealTime), atm(Caller), nnegint(Now),
     var(S0), var(S)).
% inf upper bounds of reveal/9 and auction_end/5 (and of goal/1, which
% calls them): the loops over Bids depend on a list inside the state, which
% the analysis measures by term size only.
:- entry bid(Caller, Amount, Now, Hash, S1, S2, B1, B2) :
    (atm(Caller), nnegint(Amount), nnegint(Now), atm(Hash), blindstate(S1),
     var(S2), balances(B1), var(B2)).
:- entry reveal(Caller, Now, Hash, Value, Fake, S1, S2, B1, B2) :
    (atm(Caller), nnegint(Now), atm(Hash), nnegint(Value), nnegint(Fake),
     blindstate(S1), var(S2), balances(B1), var(B2)).
:- entry auction_end(Now, S1, S2, B1, B2) :
    (nnegint(Now), blindstate(S1), var(S2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
