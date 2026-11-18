% Blind auction (Java: io.hotmoka.examples.auction.BlindAuction).
% Bidders place hashed bids with a deposit; later they reveal them; the highest
% revealed bid wins and the other deposits are refunded.
% State: Bene (beneficiary), BEnd (biddingEnd), REnd (revealEnd), HBdr (highestBidder,
%        or null), HBid (highestBid, or null), Bids = tree map, list of
%        kv(Bidder, [bid(Hash, Deposit), ...]) (StorageTreeMap<Contract, StorageList<Bid>>).
% The hash of a bid is the term hash(Value, Fake, Salt), the digest of the revealed bid;
% a revealed bid (RevealedBid) is the term revealed_bid(Value, Fake, Salt).
% Fields of the storage objects (a bid, a revealed bid) are read as in Java, V = Obj[field]
% (see hotmoka_tr.pl: the first read of an object loads it).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/4, bid/9, reveal/13, auction_end/9, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).                       % arithmetic is computed, as in Java

:- class(bid(hash, deposit)).
:- class(revealed_bid(value, fake, salt)).

:- regtype revealed_bid/1.
revealed_bid(revealed_bid(Value, Fake, Salt)) :- int(Value), int(Fake), gnd(Salt).

:- regtype opt/1.
opt(null).
opt(X) :- int(X).

:- entry bid(Caller, Amount, Now, BEnd, Hash, Bids0, Bids, B0, B) :
    (atm(Caller), int(Amount), int(Now), int(BEnd), gnd(Hash), map(Bids0), var(Bids),
     balances(B0), var(B)).
:- entry reveal(Caller, Now, BEnd, REnd, Revealed, Bids0, Bids, HBdr0, HBdr, HBid0, HBid, B0, B) :
    (atm(Caller), int(Now), int(BEnd), int(REnd), revealed_bid(Revealed),
     map(Bids0), var(Bids), atm(HBdr0), var(HBdr), opt(HBid0), var(HBid),
     balances(B0), var(B)).
:- entry auction_end(Bene, Now, REnd, HBid, HBdr0, HBdr, B0, B, Winner) :
    (atm(Bene), int(Now), int(REnd), opt(HBid), atm(HBdr0), var(HBdr),
     balances(B0), var(B), var(Winner)).

% BlindAuction(biddingTime, revealTime)
init(BiddingTime, Now, BEnd, HBdr) :-
    BEnd = Now + BiddingTime,                       % biddingEnd = now() + biddingTime
    HBdr = null.                                    % no highest bidder yet

:- payable(bid).                             % @Payable: the amount sent is received first

% @FromContract bid(amount, hash)
bid(Caller, Amount, Now, BEnd, Hash, !Bids, !B) :-
    Now =< BEnd,                                    % onlyBefore(biddingEnd)
    L0 = ~map_get(Caller, Bids, none),              % bids.computeIfAbsent(caller, ...): tree get
    if (L0 == none) {
        new_obj(list),                              % new StorageLinkedList (bidder not yet in the tree)
        L = []
    } else { L = L0 },
    new_obj(bid),                                   % new Bid(hash, amount)
    L1 = ~list_add(bid(Hash, Amount), L),           % .add(bid): one new list node
    map_put(Caller, L1, !Bids).                     % new key: tree put (an existing list is mutated in place in Java)

% @FromContract reveal(revealed)
reveal(Caller, Now, BEnd, REnd, Revealed, !Bids, !HBdr, !HBid, !B) :-
    Now >= BEnd,                                    % onlyAfter(biddingEnd)
    Now =< REnd,                                    % onlyBefore(revealEnd)
    L = ~map_get(Caller, Bids, none),               % this.bids.get(bidder)
    list_remove_first(Bid, L, Rest),                % require(bids != null && bids.size() > 0), bids.removeFirst()
    map_put(Caller, Rest, !Bids),                   % (Java mutates the list in place, no tree put)
    % refundFor(bidder, bid, revealed, digest), bid.matches(revealed, digest):
    Value = Revealed[value],                        % revealed.value
    Fake = Revealed[fake],                          % revealed.fake
    Salt = Revealed[salt],
    SaltBytes = ~to_array(Salt),                    % revealed.salt.toArray()
    Hash = Bid[hash],
    HashBytes = ~to_array(Hash),                    % hash.toArray()
    Deposit = Bid[deposit],                         % bid.deposit
    if (HashBytes \== hash(Value, Fake, SaltBytes)) {   % !bid.matches(revealed, digest)
        Refund = 0
    } else if ((Fake =:= 0, Deposit >= Value, better(Value, HBid))) {
        place_bid(Caller, Value, !HBdr, !HBid, !B), % placeBid(bidder, revealed.value)
        Refund = Deposit - Value
    } else { Refund = Deposit },
    transfer(this, Caller, Refund, !B).             % bidder.receive(refundFor(...)): always executed

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
    reveal(alice, 110, BEnd, REnd, revealed_bid(150, 0, sa), Bids2, Bids3, H0, H1, null, HB1, B2, B3),
    reveal(bob, 120, BEnd, REnd, revealed_bid(100, 0, sb), Bids3, _, H1, H2, HB1, HB2, B3, B4),
    auction_end(bene, 210, REnd, HB2, H2, _, B4, B5, _),
    balance(alice, B5, A),
    balance(bob, B5, Bo),
    balance(bene, B5, Be),
    balance(this, B5, T).
