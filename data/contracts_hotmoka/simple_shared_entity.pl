% Simple shared entity (Java: io.hotmoka.examples.sharedentities.SimpleSharedEntity1).
% Shareholders sell shares through offers.
% State: Sh = shares, tree map kv(Shareholder, Number);
%        Of = offers, tree set kv(offer(Seller, Cost, Number, Ongoing), 1)
%             (Ongoing = 1 while the offer is ongoing, 0 once expired);
%        SnapO = snapshotOfOffers, SnapS = snapshotOfShares (the last snapshots taken, or none).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [place/10, accept/12, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).                       % arithmetic is computed, as in Java

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
    Mine = ~map_get(Seller, Sh, 0), Mine > 0,       % require(shares.containsKey(seller))
    Shares = ~map_get(Seller, Sh, 0),               % sharesOf(seller)
    OnSale = ~on_sale(Of, Seller),                    % sharesOnSaleOf(seller): scan of the offers
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
    Known = ~map_get(Offer, Of, 0),                 % require(offers.contains(offer))
    Offer = offer(Seller, Cost, N, Ongoing),
    if ((Known =:= 1, Ongoing =:= 1, Cost =< Amount)) {
        clean_up(Of, Offer, !Of),                   % cleanUpOffers(offer): scan of the offers
        remove_shares(Seller, N, !Sh),
        add_shares(Caller, N, !Sh),
        transfer(this, Seller, Cost, !B),           % offer.seller.receive(offer.cost)
        new_obj(snapshot),                          % Java: shares.snapshot() creates a view object
        SnapS := snapshot,                          % snapshotOfShares = shares.snapshot()
        emit(offer_accepted),                       % event(new OfferAccepted(buyer, offer))
        Ok = 1
    } else { Ok = 0 }.

% sharesOnSaleOf(seller): sum of the shares of the ongoing offers of Seller.
% (no accumulator: CiaoPP then measures the recursion on the list only)
on_sale([], _, 0).
on_sale([kv(O, _)|T], Seller, S) :-
    S1 = ~on_sale(T, Seller),
    load(O),
    O = offer(Sel, _, N, Ongoing),
    if ((Sel == Seller, Ongoing =:= 1)) { S = S1 + N } else { S = S1 }.

% cleanUpOffers(toRemove): removes toRemove and the offers no longer ongoing.
% It scans the offers of the call (first argument) and removes from !Of.
clean_up(Offers, ToRemove, !Of) :-
    for (E in list(Offers)) {
        E = kv(O, _),
        if (to_remove(O, ToRemove)) { map_remove(O, !Of) }
    }.

to_remove(O, O) :- !.
to_remove(offer(_, _, _, 0), _).

% removeShares: shares.update (get + put); the entry goes when it reaches 0.
remove_shares(Holder, N, !Sh) :-
    S0 = ~map_get(Holder, Sh, 0),
    S1 = S0 - N,
    map_put(Holder, S1, !Sh),
    S2 = ~map_get(Holder, Sh, 0),                   % shares.get(shareholder).signum()
    if (S2 =:= 0) {
        map_remove(Holder, !Sh),
        emit(shareholder_removed)
    }.

% addShares: shares.update with a default (new shareholder: one more event).
add_shares(Holder, N, !Sh) :-
    S0 = ~map_get(Holder, Sh, none),
    if (S0 == none) { emit(shareholder_added), S1 is N } else { S1 = S0 + N },
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
