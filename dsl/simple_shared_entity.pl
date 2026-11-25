% Simple shared entity (Java: io.hotmoka.examples.sharedentities.SimpleSharedEntity1).
% Shareholders sell shares through offers.
% Sh: shares, tree map kv(Shareholder, Number); Of: offers, tree set kv(offer(Seller, Cost, Number, Ongoing), 1);
% SnapO, SnapS: last snapshots of offers and shares (or none). B: coin balances.

:- module(_, [place/10, accept/11, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- class(offer(seller, cost, sharesOnSale, ongoing)).

:- regtype offer/1.
offer(offer(Seller, Cost, N, Ongoing)) :- atm(Seller), int(Cost), int(N), int(Ongoing).

:- entry place(Caller, Amount, Offer, Sh, Of0, Of, SnapO0, SnapO, B0, B) :
    (atm(Caller), int(Amount), offer(Offer), map(Sh), map(Of0), var(Of),
     atm(SnapO0), var(SnapO), balances(B0), var(B)).
:- entry accept(Caller, Amount, Offer, Sh0, Sh, Of0, Of, SnapS0, SnapS, B0, B) :
    (atm(Caller), int(Amount), offer(Offer), map(Sh0), var(Sh), map(Of0), var(Of),
     atm(SnapS0), var(SnapS), balances(B0), var(B)).

:- payable(place).

% @FromContract place(amount, offer)
place(Caller, Amount, Offer, Sh, !Of, !SnapO, !B) :-
    Seller = Offer[seller],
    require(Seller == Caller),
    Mine = ~map_get(Seller, Sh, 0),
    require(Mine > 0),
    Shares = ~map_get(Seller, Sh, 0),  % second read of the key, as in Java
    OnSale = ~on_sale(Of, Seller),
    N = Offer[sharesOnSale],
    require(Shares - OnSale >= N),
    clean_up_loaded(Of, !Of),  % offers already loaded
    map_put(Offer, 1, !Of),
    SnapO := ~snapshot(Of),
    emit(offer_placed).

:- payable(accept).

% @FromContract accept(amount, offer)
accept(Caller, Amount, Offer, !Sh, !Of, !SnapS, !B) :-
    Known = ~map_get(Offer, Of, 0),
    require(Known =:= 1, 'unknown offer'),
    Ongoing = Offer[ongoing],
    require(Ongoing =:= 1, 'the sale offer is not ongoing anymore'),
    Cost = Offer[cost],
    require(Cost =< Amount, 'not enough money to accept the offer'),
    Seller = Offer[seller],
    N = Offer[sharesOnSale],
    clean_up(Of, Offer, !Of),
    remove_shares(Seller, N, !Sh),
    add_shares(Caller, N, !Sh),
    transfer(this, Seller, Cost, !B),
    SnapS := ~snapshot(Sh),
    emit(offer_accepted).

% sharesOnSaleOf(seller). No accumulator: CiaoPP then measures the recursion on the list only.
% Each offer is loaded by its first read; the tree set nodes by the cleanUpOffers scan that follows.
on_sale([], _, 0).
on_sale([kv(O, _)|T], Seller, S) :-
    S1 = ~on_sale(T, Seller),
    Sel = O[seller],
    Ongoing = O[ongoing],
    N = O[sharesOnSale],  % already loaded
    if ((Sel == Seller, Ongoing =:= 1)) { S = S1 + N } else { S = S1 }.

% cleanUpOffers(null): scans the offers (one node load each) and removes the expired ones.
clean_up_loaded(Offers, !Of) :-
    for (E in list(Offers)) {
        E = kv(O, _),
        if (expired(O)) { map_remove(O, !Of) }
    }.

expired(offer(_, _, _, 0)).

% In accept, each offer other than toRemove is loaded by its first read.
clean_up(Offers, ToRemove, !Of) :-
    for (E in list(Offers)) {
        E = kv(O, _),
        if (to_remove(O, ToRemove)) { map_remove(O, !Of) }
    }.

% offer == offerToRemove || !offer.isOngoing()
to_remove(O, R) :- O == R, !.  % short-circuit: the offer is not read
to_remove(O, _) :- Ongoing = O[ongoing], Ongoing =:= 0.  % loads the offer

% removeShares: shares.update (get + put); the entry goes when it reaches 0.
remove_shares(Holder, N, !Sh) :-
    S0 = ~map_get(Holder, Sh, 0),
    S1 = S0 - N,
    map_put(Holder, S1, !Sh),
    S2 = ~map_get(Holder, Sh, 0),
    if (S2 =:= 0) {
        map_remove(Holder, !Sh),
        emit(shareholder_removed)
    }.

% addShares: shares.update with a default (new shareholder: one more event).
add_shares(Holder, N, !Sh) :-
    S0 = ~map_get(Holder, Sh, none),
    if (S0 == none) { emit(shareholder_added), S1 is N } else { S1 = S0 + N },
    map_put(Holder, S1, !Sh).

% Test: alice (60 shares) offers 10 for 200, charlie accepts. Expected shares alice 50, bob 40, charlie 10; coins 1200, 800.
goal([Sh, A, C]) :-
    Sh0 = [kv(alice, 60), kv(bob, 40)],
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(charlie, 1000), bal(this, 0)],
    O = offer(alice, 200, 10, 1),
    place(alice, 0, O, Sh0, [], Of1, none, _, B0, B1),
    accept(charlie, 200, O, Sh0, Sh, Of1, _, none, _, B1, B2),
    balance(alice, B2, A),
    balance(charlie, B2, C).
