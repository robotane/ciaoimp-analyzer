% Blind auction (Java: io.hotmoka.examples.auction.BlindAuction).
% Bidders place hashed bids with a deposit, then reveal them; the highest revealed bid wins.
% Bids: tree map kv(Bidder, [bid(Hash, Deposit), ...]); a hash is the term hash(Value, Fake, Salt).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/4, bid/9, reveal/13, auction_end/9, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- class(bid(hash, deposit)).
:- class(revealed_bid(value, fake, salt)).

:- regtype revealed_bid/1.
revealed_bid(revealed_bid(Value, Fake, Salt)) :- int(Value), int(Fake), gnd(Salt).

:- regtype bid_obj/1.
bid_obj(bid(Hash, Deposit)) :- gnd(Hash), int(Deposit).

% known shape of the Bid: reading its fields cannot fail.
:- trust success list_remove_first(Bid, _, _) => bid_obj(Bid).

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
    BEnd = Now + BiddingTime,
    HBdr = null.

:- payable(bid).

% @FromContract bid(amount, hash)
bid(Caller, Amount, Now, BEnd, Hash, !Bids, !B) :-
    require(Now =< BEnd),
    L0 = ~map_get(Caller, Bids, none),
    if (L0 == none) {
        new_obj(list),
        L = []
    } else { L = L0 },
    new_obj(bid),
    L1 = ~list_add(bid(Hash, Amount), L),
    % two ifs on L0: one if with the add in each branch would cost 2*C_NEW too much
    if (L0 == none) {
        map_put(Caller, L1, !Bids)
    } else {
        map_set(Caller, L1, !Bids)  % list mutated in place
    }.

% @FromContract reveal(revealed)
reveal(Caller, Now, BEnd, REnd, Revealed, !Bids, !HBdr, !HBid, !B) :-
    require(Now >= BEnd),
    require(Now =< REnd),
    L = ~map_get(Caller, Bids, none),
    require((L \== none, ~list_size(L) > 0), 'No bids to reveal'),
    list_remove_first(Bid, L, Rest),
    map_set(Caller, Rest, !Bids),
    % refundFor(bidder, bid, revealed, digest), bid.matches(revealed, digest):
    Value = Revealed[value],
    Fake = Revealed[fake],
    Salt = Revealed[salt],
    SaltBytes = ~to_array(Salt),
    Hash = Bid[hash],
    HashBytes = ~to_array(Hash),
    Deposit = Bid[deposit],
    if (HashBytes \== hash(Value, Fake, SaltBytes)) {  % !bid.matches(revealed, digest)
        Refund = 0
    } else if ((Fake =:= 0, Deposit >= Value, (HBid == null ; Value > HBid))) {
        place_bid(Caller, Value, !HBdr, !HBid, !B),
        Refund = Deposit - Value
    } else { Refund = Deposit },
    transfer(this, Caller, Refund, !B).  % always executed

% placeBid(bidder, value)
place_bid(Bidder, Value, !HBdr, !HBid, !B) :-
    if (HBdr \== null) {
        transfer(this, HBdr, HBid, !B)
    },
    HBid := Value,
    HBdr := Bidder,
    emit(bid_increase).

% auctionEnd()
auction_end(Bene, Now, REnd, HBid, !HBdr, !B, Winner) :-
    require(Now >= REnd),
    Winner = HBdr,
    if (Winner \== null) {
        transfer(this, Bene, HBid, !B),
        emit(auction_end),
        HBdr := null
    }.

% Test: alice bids (deposit 200, value 150), bob (deposit 100, value 100); both reveal; end. Expected [850, 1000, 150, 0].
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
