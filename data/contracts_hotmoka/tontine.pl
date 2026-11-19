% Tontine (Java: io.hotmoka.examples.tontine.Tontine), collective savings fund.
% The creator fixes the contribution; members join by paying exactly it. Each round,
% the creator credits the next member (circular queue, in order of membership) with one
% contribution; a member withdraws its balance; the creator refunds all members (linear loop).
% State: Soldes = soldes, StorageTreeMap<PayableContract, BigInteger>, tree map kv(Member, Balance);
%        Membres = membres, StorageLinkedList<PayableContract>, list of addresses;
%        Tour = round counter; Createur and Cotis (creator, contribution) are read only.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/7, rejoindre/9, distribuer/9, retrait/5, rembourser_tous/7, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).                       % arithmetic is computed, as in Java

:- regtype addrs/1.
addrs([]).
addrs([A|T]) :- atm(A), addrs(T).

:- entry rejoindre(Caller, Amount, Cotis, Soldes0, Soldes, Membres0, Membres, B0, B) :
    (atm(Caller), int(Amount), int(Cotis), map(Soldes0), var(Soldes), addrs(Membres0), var(Membres),
     balances(B0), var(B)).
:- entry distribuer(Caller, Createur, Cotis, Soldes0, Soldes, Membres0, Membres, Tour0, Tour) :
    (atm(Caller), atm(Createur), int(Cotis), map(Soldes0), var(Soldes), addrs(Membres0), var(Membres),
     int(Tour0), var(Tour)).
:- entry retrait(Caller, Soldes0, Soldes, B0, B) :
    (atm(Caller), map(Soldes0), var(Soldes), balances(B0), var(B)).
:- entry rembourser_tous(Caller, Createur, Membres, Soldes0, Soldes, B0, B) :
    (atm(Caller), atm(Createur), addrs(Membres), map(Soldes0), var(Soldes), balances(B0), var(B)).

% Tontine(cotisation): the creator and the contribution are fixed
init(Creator, Cotis, Creator, Cotis, [], [], 0).

:- payable(rejoindre).                          % @Payable: the amount sent is received first

% @FromContract rejoindre(amount)
rejoindre(Caller, Amount, Cotis, !Soldes, !Membres, !B) :-
    Amount =:= Cotis,                               % require(compareTo(amount, cotisation) == 0)
    S0 = ~map_get(Caller, Soldes, none),            % require(!soldes.containsKey(membre))
    S0 == none,
    map_put(Caller, 0, !Soldes),                    % soldes.put(membre, ZERO): new key
    list_add(Caller, !Membres),                     % membres.add(membre): one new list node
    emit(adhesion).                                 % event(new Adhesion(membre))

% @FromContract distribuer()
distribuer(Caller, Createur, Cotis, !Soldes, !Membres, !Tour) :-
    Caller == Createur,                             % require(caller() == createur)
    list_remove_first(Ben, Membres, Rest),          % beneficiaire = membres.removeFirst()
    Membres := Rest,
    list_add(Ben, !Membres),                        % membres.add(beneficiaire)
    S = ~map_get(Ben, Soldes, 0),                   % soldes.getOrDefault(beneficiaire, ZERO)
    S1 = S + Cotis,                                 % add(solde, cotisation)
    map_put(Ben, S1, !Soldes),                      % soldes.put(beneficiaire, ...)
    Tour := Tour + 1,                               % tour++
    emit(distribution).                             % event(new Distribution(beneficiaire, tour))

% @FromContract retrait()
retrait(Caller, !Soldes, !B) :-
    S = ~map_get(Caller, Soldes, 0),                % soldes.getOrDefault(membre, ZERO)
    S > 0,                                          % require(solde > 0)
    map_put(Caller, 0, !Soldes),                    % soldes.put(membre, ZERO)
    transfer(this, Caller, S, !B),                  % membre.receive(solde)
    emit(retrait).                                  % event(new Retrait(membre, solde))

% @FromContract rembourserTous()
rembourser_tous(Caller, Createur, Membres, !Soldes, !B) :-
    Caller == Createur,                             % require(caller() == createur)
    for (M in list(Membres)) {                      % membres.forEach(membre -> ...)
        S = ~map_get(M, Soldes, 0),                 % soldes.getOrDefault(membre, ZERO)
        map_put(M, 0, !Soldes),                     % soldes.put(membre, ZERO)
        transfer(this, M, S, !B)                    % membre.receive(solde)
    },
    emit(remboursement).                            % event(new Remboursement(tour))

% --- Test: contribution 100; alice (creator), bob and carol join; round 1 credits alice, she withdraws;
% round 2 credits bob; the creator refunds everybody ---
% Expected: [alice, bob, carol, this] = [900 + 100, 900 + 100, 900, 100].
goal([A, Bo, C, T]) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(carol, 1000), bal(this, 0)],
    init(alice, 100, Cr, Co, _S0, _M0, _T0),
    Cr == alice, Co == 100,
    rejoindre(alice, 100, 100, [], S1, [], M1, B0, B1),
    M1 == [alice], S1 == [kv(alice, 0)],
    rejoindre(bob, 100, 100, [kv(alice, 0)], _S2, [alice], _M2, B1, B2),
    rejoindre(carol, 100, 100, [kv(alice, 0), kv(bob, 0)], _S3, [alice, bob], M3, B2, B3),
    M3 == [alice, bob, carol],
    distribuer(alice, alice, 100, [kv(alice, 0), kv(bob, 0), kv(carol, 0)], _S4, [alice, bob, carol], M4, 0, T1),
    M4 == [bob, carol, alice], T1 == 1,
    retrait(alice, [kv(alice, 100), kv(bob, 0), kv(carol, 0)], _S5, B3, B4),
    distribuer(alice, alice, 100, [kv(alice, 0), kv(bob, 0), kv(carol, 0)], _S6, [bob, carol, alice], _, 1, _),
    rembourser_tous(alice, alice, [bob, carol, alice], [kv(alice, 0), kv(bob, 100), kv(carol, 0)], _S7, B4, B5),
    balance(alice, B5, A),
    balance(bob, B5, Bo),
    balance(carol, B5, C),
    balance(this, B5, T).
