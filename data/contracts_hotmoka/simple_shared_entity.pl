% Simple shared entity (Java: io.hotmoka.examples.sharedentities.SimpleSharedEntity1).
% Shareholders sell shares through offers.
% State: Sh = shares, tree map kv(Shareholder, Number);
%        Of = offers, tree set kv(offer(Seller, Cost, Number, Ongoing), 1)
%             (Ongoing = 1 while the offer is ongoing, 0 once expired);
%        SnapO = snapshotOfOffers, SnapS = snapshotOfShares (the last snapshots taken, or none).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [place/10, accept/12, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, .(hotmoka_gas)]).

:- regtype offer/1.
offer(offer(Seller, Cost, N, Ongoing)) :- atm(Seller), int(Cost), int(N), int(Ongoing).

:- entry place(Caller, Amount, Offer, Sh, Of0, Of, SnapO0, SnapO, B0, B) :
    (atm(Caller), int(Amount), offer(Offer), map(Sh), map(Of0), var(Of),
     atm(SnapO0), var(SnapO), balances(B0), var(B)).
:- entry accept(Caller, Amount, Offer, Sh0, Sh, Of0, Of, SnapS0, SnapS, B0, B, Ok) :
    (atm(Caller), int(Amount), offer(Offer), map(Sh0), var(Sh), map(Of0), var(Of),
     atm(SnapS0), var(SnapS), balances(B0), var(B), var(Ok)).

:- payable(place).                             % @Payable: the amount sent is received first

% @FromContract place(amount, offer)
place(Caller, Amount, Offer, Sh, !Of, !SnapO, !B) :-
    Offer = offer(Seller, _, N, _),
    Seller == Caller,                               % require(offer.seller == seller)
    map_get(Seller, Sh, 0, Mine), Mine > 0,         % require(shares.containsKey(seller))
    map_get(Seller, Sh, 0, Shares),                 % sharesOf(seller)
    on_sale(Of, Seller, OnSale),                      % sharesOnSaleOf(seller): scan of the offers
    Shares - OnSale >= N,
    clean_up(Of, none, !Of),                        % cleanUpOffers(null): scan of the offers
    map_put(Offer, 1, !Of),                         % offers.add(offer)
    new_obj(snapshot),                              % Java: offers.snapshot() creates a view object
    SnapO := snapshot,                              % snapshotOfOffers = offers.snapshot()
    emit(offer_placed).                             % event(new OfferPlaced(offer))

:- payable(accept).                             % @Payable: the amount sent is received first

% @FromContract accept(amount, offer)
% Ok = 1 when the offer is accepted (the Java call fails otherwise).
accept(Caller, Amount, Offer, !Sh, !Of, !SnapS, !B, Ok) :-
    map_get(Offer, Of, 0, Known),                   % require(offers.contains(offer))
    Offer = offer(Seller, Cost, N, Ongoing),
    ( Known =:= 1, Ongoing =:= 1, Cost =< Amount ->
        clean_up(Of, Offer, !Of),                   % cleanUpOffers(offer): scan of the offers
        remove_shares(Seller, N, !Sh),
        add_shares(Caller, N, !Sh),
        transfer(this, Seller, Cost, !B),           % offer.seller.receive(offer.cost)
        new_obj(snapshot),                          % Java: shares.snapshot() creates a view object
        SnapS := snapshot,                          % snapshotOfShares = shares.snapshot()
        emit(offer_accepted),                       % event(new OfferAccepted(buyer, offer))
        Ok = 1
    ; Ok = 0
    ).

% sharesOnSaleOf(seller): sum of the shares of the ongoing offers of Seller.
% (no accumulator: CiaoPP then measures the recursion on the list only)
on_sale([], _, 0).
on_sale([kv(O, _)|T], Seller, S) :-
    on_sale(T, Seller, S1),
    load(O),
    O = offer(Sel, _, N, Ongoing),
    ( Sel == Seller, Ongoing =:= 1 -> S is S1 + N ; S = S1 ).

% cleanUpOffers(toRemove): removes toRemove and the offers no longer ongoing.
% It scans the offers of the call (first argument) and removes from !Of.
clean_up([], _, !Of).
clean_up([kv(O, _)|T], ToRemove, !Of) :-
    load(O),
    ( to_remove(O, ToRemove) -> map_remove(O, !Of) ; true ),
    clean_up(T, ToRemove, !Of).

to_remove(O, O) :- !.
to_remove(offer(_, _, _, 0), _).

% removeShares: shares.update (get + put); the entry goes when it reaches 0.
remove_shares(Holder, N, !Sh) :-
    map_get(Holder, Sh, 0, S0),
    S1 is S0 - N,
    map_put(Holder, S1, !Sh),
    map_get(Holder, Sh, 0, S2),                     % shares.get(shareholder).signum()
    ( S2 =:= 0 ->
        map_remove(Holder, !Sh),
        emit(shareholder_removed)
    ; true
    ).

% addShares: shares.update with a default (new shareholder: one more event).
add_shares(Holder, N, !Sh) :-
    map_get(Holder, Sh, none, S0),
    ( S0 == none -> emit(shareholder_added), S1 is N ; S1 is S0 + N ),
    map_put(Holder, S1, !Sh).

% --- Test: alice 60 shares, bob 40; alice offers 10 shares for 200, charlie accepts ---
% Expected shares: alice 50, bob 40, charlie 10; coins: alice 1200, charlie 800.
goal([Sh, A, C]) :-
    Sh0 = [kv(alice, 60), kv(bob, 40)],
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(charlie, 1000), bal(this, 0)],
    O = offer(alice, 200, 10, 1),
    place(alice, 0, O, Sh0, [], Of1, none, _, B0, B1),
    accept(charlie, 200, O, Sh0, Sh, Of1, _, none, _, B1, B2, 1),
    balance(alice, B2, A),
    balance(charlie, B2, C).
