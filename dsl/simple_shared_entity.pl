% Simple shared entity (Java: io.hotmoka.examples.sharedentities.SimpleSharedEntity1).
% Shareholders sell shares through offers.
% State: Sh = shares, tree map kv(Shareholder, Number);
%        Of = offers, tree set kv(offer(Seller, Cost, Number, Ongoing), 1)
%             (Ongoing = 1 while the offer is ongoing, 0 once expired);
%        an offer is a storage object: its fields are read as in Java, V = Offer[field]
%        (see hotmoka_tr.pl: the first read of an offer on a path loads it);
%        SnapO = snapshotOfOffers, SnapS = snapshotOfShares (the last snapshots taken, or none;
%        snapshot/2 creates the view object).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [place/10, accept/11, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).                       % arithmetic is computed, as in Java

:- class(offer(seller, cost, sharesOnSale, ongoing)).

:- regtype offer/1.
offer(offer(Seller, Cost, N, Ongoing)) :- atm(Seller), int(Cost), int(N), int(Ongoing).

:- entry place(Caller, Amount, Offer, Sh, Of0, Of, SnapO0, SnapO, B0, B) :
    (atm(Caller), int(Amount), offer(Offer), map(Sh), map(Of0), var(Of),
     atm(SnapO0), var(SnapO), balances(B0), var(B)).
:- entry accept(Caller, Amount, Offer, Sh0, Sh, Of0, Of, SnapS0, SnapS, B0, B) :
    (atm(Caller), int(Amount), offer(Offer), map(Sh0), var(Sh), map(Of0), var(Of),
     atm(SnapS0), var(SnapS), balances(B0), var(B)).

:- payable(place).                             % @Payable: the amount sent is received first

% @FromContract place(amount, offer)
place(Caller, Amount, Offer, Sh, !Of, !SnapO, !B) :-
    Seller = Offer[seller],                         % offer.seller: loads the offer
    require(Seller == Caller),                      % require(offer.seller == seller)
    Mine = ~map_get(Seller, Sh, 0),                 % shares.containsKey(seller)
    require(Mine > 0),                              % require(shares.containsKey(seller))
    Shares = ~map_get(Seller, Sh, 0),               % sharesOf(seller)
    OnSale = ~on_sale(Of, Seller),                    % sharesOnSaleOf(seller): scan of the offers
    N = Offer[sharesOnSale],
    require(Shares - OnSale >= N),                  % require(sharesOf(seller) - sharesOnSaleOf(seller) >= offer.sharesOnSale)
    clean_up_loaded(Of, !Of),                       % cleanUpOffers(null): scan of the offers (already loaded)
    map_put(Offer, 1, !Of),                         % offers.add(offer)
    SnapO := ~snapshot(Of),                         % snapshotOfOffers = offers.snapshot()
    emit(offer_placed).                             % event(new OfferPlaced(offer))

:- payable(accept).                             % @Payable: the amount sent is received first

% @FromContract accept(amount, offer)
% A failed require is a failed transaction (Java exception): the call fails.
accept(Caller, Amount, Offer, !Sh, !Of, !SnapS, !B) :-
    Known = ~map_get(Offer, Of, 0),                 % offers.contains(offer)
    require(Known =:= 1, 'unknown offer'),
    Ongoing = Offer[ongoing],                       % offer.isOngoing(): loads the offer
    require(Ongoing =:= 1, 'the sale offer is not ongoing anymore'),
    Cost = Offer[cost],
    require(Cost =< Amount, 'not enough money to accept the offer'),
    Seller = Offer[seller],
    N = Offer[sharesOnSale],
    clean_up(Of, Offer, !Of),                       % cleanUpOffers(offer): scan of the offers
    remove_shares(Seller, N, !Sh),
    add_shares(Caller, N, !Sh),
    transfer(this, Seller, Cost, !B),               % offer.seller.receive(offer.cost)
    SnapS := ~snapshot(Sh),                         % snapshotOfShares = shares.snapshot()
    emit(offer_accepted).                           % event(new OfferAccepted(buyer, offer))

% sharesOnSaleOf(seller): sum of the shares of the ongoing offers of Seller.
% (no accumulator: CiaoPP then measures the recursion on the list only)
% Java loads each node of the tree set and each offer. Here each offer is loaded by its
% first read; the node of each offer is loaded by the scan of cleanUpOffers that follows in
% place (a for loop: one load per node), and Java loads a node once in a transaction.
on_sale([], _, 0).
on_sale([kv(O, _)|T], Seller, S) :-
    S1 = ~on_sale(T, Seller),
    Sel = O[seller],                                % offer.seller: loads the offer
    Ongoing = O[ongoing],                           % offer.isOngoing()
    N = O[sharesOnSale],                            % offer.sharesOnSale (read here: no gas, already loaded)
    if ((Sel == Seller, Ongoing =:= 1)) { S = S1 + N } else { S = S1 }.

% cleanUpOffers(toRemove): removes toRemove and the offers no longer ongoing.
% It scans the offers of the call (first argument) and removes from !Of: one node loaded
% per offer (for loop).
% In place (toRemove = null), the offers are already loaded by sharesOnSaleOf: no load.
clean_up_loaded(Offers, !Of) :-
    for (E in list(Offers)) {
        E = kv(O, _),
        if (expired(O)) { map_remove(O, !Of) }      % !offer.isOngoing()
    }.

expired(offer(_, _, _, 0)).

% In accept, each offer other than toRemove is loaded by its first read.
clean_up(Offers, ToRemove, !Of) :-
    for (E in list(Offers)) {
        E = kv(O, _),
        if (to_remove(O, ToRemove)) { map_remove(O, !Of) }
    }.

% offer == offerToRemove || !offer.isOngoing()
to_remove(O, R) :- O == R, !.                       % (short-circuit: the offer is not read)
to_remove(O, _) :- Ongoing = O[ongoing], Ongoing =:= 0.   % loads the offer

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
    accept(charlie, 200, O, Sh0, Sh, Of1, _, none, _, B1, B2),
    balance(alice, B2, A),
    balance(charlie, B2, C).
