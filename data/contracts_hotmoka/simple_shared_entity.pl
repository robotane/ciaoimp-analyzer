% Simple shared entity (Java: io.hotmoka.examples.sharedentities.SimpleSharedEntity1).
% Shareholders sell shares through offers.
% State: Sh = shares, tree map kv(Shareholder, Number);
%        Of = offers, tree set kv(offer(Seller, Cost, Number, Ongoing), 1)
%             (Ongoing = 1 while the offer is ongoing, 0 once expired).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [place/8, accept/10, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, .(hotmoka_gas)]).

:- regtype offer/1.
offer(offer(Seller, Cost, N, Ongoing)) :- atm(Seller), int(Cost), int(N), int(Ongoing).

:- entry place(Amount, Offer, Caller, Sh, Of0, Of, B0, B) :
    (int(Amount), offer(Offer), atm(Caller), map(Sh), map(Of0), var(Of),
     balances(B0), var(B)).
:- entry accept(Amount, Offer, Caller, Sh0, Sh, Of0, Of, B0, B, Ok) :
    (int(Amount), offer(Offer), atm(Caller), map(Sh0), var(Sh), map(Of0), var(Of),
     balances(B0), var(B), var(Ok)).

% @FromContract @Payable place(amount, offer)
place(Amount, Offer, Caller, Sh, !Of, !B) :-
    transfer(Caller, this, Amount, !B),             % the amount sent with the call
    Offer = offer(Seller, _, N, _),
    Seller == Caller,                               % require(offer.seller == seller)
    map_get(Seller, Sh, 0, Mine), Mine > 0,         % require(shares.containsKey(seller))
    map_get(Seller, Sh, 0, Shares),                 % sharesOf(seller)
    on_sale(Of, Seller, OnSale),                      % sharesOnSaleOf(seller): scan of the offers
    Shares - OnSale >= N,
    clean_up(Of, none, !Of),                        % cleanUpOffers(null): scan of the offers
    map_put(Offer, 1, !Of),                         % offers.add(offer)
    store(snapshotOfOffers),                        % Java: snapshotOfOffers = offers.snapshot()
    emit(offer_placed).                             % event(new OfferPlaced(offer))

% @FromContract @Payable accept(amount, offer)
% Ok = 1 when the offer is accepted (the Java call fails otherwise).
accept(Amount, Offer, Caller, !Sh, !Of, !B, Ok) :-
    transfer(Caller, this, Amount, !B),             % the amount sent with the call
    map_get(Offer, Of, 0, Known),                   % require(offers.contains(offer))
    Offer = offer(Seller, Cost, N, Ongoing),
    ( Known =:= 1, Ongoing =:= 1, Cost =< Amount ->
        clean_up(Of, Offer, !Of),                   % cleanUpOffers(offer): scan of the offers
        remove_shares(Seller, N, !Sh),
        add_shares(Caller, N, !Sh),
        transfer(this, Seller, Cost, !B),           % offer.seller.receive(offer.cost)
        store(snapshotOfShares),                    % Java: snapshotOfShares = shares.snapshot()
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
    place(0, O, alice, Sh0, [], Of1, B0, B1),
    accept(200, O, charlie, Sh0, Sh, Of1, _, B1, B2, 1),
    balance(alice, B2, A),
    balance(charlie, B2, C).
