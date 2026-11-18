% Blind auction (Java: io.hotmoka.examples.auction.BlindAuction).
% Bidders place hashed bids with a deposit; later they reveal them; the highest
% revealed bid wins and the other deposits are refunded.
% State: Bene (beneficiary), BEnd (biddingEnd), REnd (revealEnd), HBdr (highestBidder,
%        or null), HBid (highestBid, or null), Bids = tree map, list of
%        kv(Bidder, [bid(Hash, Deposit), ...]) (StorageTreeMap<Contract, StorageList<Bid>>).
% The hash of a bid is the term hash(Value, Fake, Salt), the digest of the revealed bid.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/4, bid/9, reveal/15, auction_end/9, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- regtype opt/1.
opt(null).
opt(X) :- int(X).

:- entry bid(Caller, Amount, Now, BEnd, Hash, Bids0, Bids, B0, B) :
    (atm(Caller), int(Amount), int(Now), int(BEnd), gnd(Hash), map(Bids0), var(Bids),
     balances(B0), var(B)).
:- entry reveal(Caller, Now, BEnd, REnd, Value, Fake, Salt, Bids0, Bids, HBdr0, HBdr, HBid0, HBid, B0, B) :
    (atm(Caller), int(Now), int(BEnd), int(REnd), int(Value), int(Fake), gnd(Salt),
     map(Bids0), var(Bids), atm(HBdr0), var(HBdr), opt(HBid0), var(HBid),
     balances(B0), var(B)).
:- entry auction_end(Bene, Now, REnd, HBid, HBdr0, HBdr, B0, B, Winner) :
    (atm(Bene), int(Now), int(REnd), opt(HBid), atm(HBdr0), var(HBdr),
     balances(B0), var(B), var(Winner)).

% BlindAuction(biddingTime, revealTime)
init(BiddingTime, Now, BEnd, HBdr) :-
    BEnd is Now + BiddingTime,                      % biddingEnd = now() + biddingTime
    HBdr = null.                                    % no highest bidder yet

:- payable(bid).                             % @Payable: the amount sent is received first

% @FromContract bid(amount, hash)
bid(Caller, Amount, Now, BEnd, Hash, !Bids, !B) :-
    Now =< BEnd,                                    % onlyBefore(biddingEnd)
    map_get(Caller, Bids, none, L0),                % bids.computeIfAbsent(caller, ...): tree get
    if (L0 == none) {
        new_obj(list),                              % new StorageLinkedList (bidder not yet in the tree)
        L = []
    } else { L = L0 },
    new_obj(bid),                                   % new Bid(hash, amount)
    list_add(bid(Hash, Amount), L, L1),             % .add(bid): one new list node
    map_put(Caller, L1, !Bids).                     % new key: tree put (an existing list is mutated in place in Java)

% @FromContract reveal(revealed), revealed = RevealedBid(Value, Fake, Salt)
reveal(Caller, Now, BEnd, REnd, Value, Fake, Salt, !Bids, !HBdr, !HBid, !B) :-
    Now >= BEnd,                                    % onlyAfter(biddingEnd)
    Now =< REnd,                                    % onlyBefore(revealEnd)
    map_get(Caller, Bids, none, L),                 % this.bids.get(bidder)
    first_bid(L, BidHash, Deposit, Rest),           % require(bids != null && bids.size() > 0), bids.removeFirst()
    load(head_node),                                % bids.removeFirst(): the head node
    map_put(Caller, Rest, !Bids),                   % (Java mutates the list in place, no tree put)
    load(revealed),                                 % revealed.value, revealed.fake
    load(salt),                                     % revealed.salt.toArray()
    load(stored_hash),                              % hash.toArray()
    load(bid_object),                               % bid.deposit
    if (BidHash \== hash(Value, Fake, Salt)) {      % !bid.matches(revealed, digest)
        Refund = 0
    } else if ((Fake =:= 0, Deposit >= Value, better(Value, HBid))) {
        place_bid(Caller, Value, !HBdr, !HBid, !B), % placeBid(bidder, revealed.value)
        Refund is Deposit - Value
    } else { Refund = Deposit },
    transfer(this, Caller, Refund, !B).             % bidder.receive(refundFor(...)): always executed

% The first bid of the list of a bidder (fails if there is none).
first_bid([bid(H, D)|R], H, D, R).

% placeBid: the first test of Java, highestBid == null || value > highestBid
better(_, null) :- !.
better(Value, HBid) :- Value > HBid.

% placeBid: the previous highest bidder is refunded, the new bid is recorded.
place_bid(Bidder, Value, !HBdr, !HBid, !B) :-
    if (HBdr \== null) {
        transfer(this, HBdr, HBid, !B)              % highestBidder.receive(highestBid)
    },
    HBid := Value,                                  % highestBid = value
    HBdr := Bidder,                                 % highestBidder = bidder
    emit(bid_increase).                             % event(new BidIncrease(bidder, value))

% auctionEnd()
auction_end(Bene, Now, REnd, HBid, !HBdr, !B, Winner) :-
    Now >= REnd,                                    % onlyAfter(revealEnd)
    Winner = HBdr,                                  % winner = highestBidder
    if (Winner \== null) {
        transfer(this, Bene, HBid, !B),             % beneficiary.receive(highestBid)
        emit(auction_end),                          % event(new AuctionEnd(winner, highestBid))
        HBdr := null                                % highestBidder = null
    }.

% --- Test: alice bids (deposit 200, value 150), bob bids (deposit 100, value 100);
% both reveal; alice wins; end. ---
% Expected: [alice, bob, bene, this] = [850, 1000, 150, 0].
goal([A, Bo, Be, T]) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
    init(100, 0, BEnd, H0),
    REnd = 200,
    bid(alice, 200, 10, BEnd, hash(150, 0, sa), [], Bids1, B0, B1),
    bid(bob, 100, 20, BEnd, hash(100, 0, sb), Bids1, Bids2, B1, B2),
    reveal(alice, 110, BEnd, REnd, 150, 0, sa, Bids2, Bids3, H0, H1, null, HB1, B2, B3),
    reveal(bob, 120, BEnd, REnd, 100, 0, sb, Bids3, _, H1, H2, HB1, HB2, B3, B4),
    auction_end(bene, 210, REnd, HB2, H2, _, B4, B5, _),
    balance(alice, B5, A),
    balance(bob, B5, Bo),
    balance(bene, B5, Be),
    balance(this, B5, T).
