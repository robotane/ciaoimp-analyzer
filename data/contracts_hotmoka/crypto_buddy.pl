% CryptoBuddy (Java: io.hotmoka.tutorial.examples.erc20.CryptoBuddy, an ERC20).
% State: Bal = balances, StorageTreeMap<Contract, UnsignedBigInteger>, tree map kv(Holder, Amount);
%        Own = the OUTER map of allowances (owner -> inner map), a tree set kv(Owner, 1);
%        Al = the INNER maps of allowances, all in one tree map kv(al(Owner, Spender), Amount)
%        (CiaoPP cannot see the length of a map stored in a term: the inner maps are flattened,
%        so the descent in an inner map is priced on the total number of allowances).
% Each UnsignedBigInteger add/subtract creates a new storage object (its gas is in ubi_add/ubi_sub);
% the tree Node of a new key is part of the cost of map_put.
% The ERC20 sources are not on disk: the work of the inherited methods follows
% hotmoka-bench/costmodel/java_vs_prolog.md (lib).
% Only the measured operations are written (the constructor, mint and burn are not).

:- module(_, [token_transfer/5, approve/7, transfer_from/10, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).                       % arithmetic is computed, as in Java

:- entry token_transfer(Caller, To, Amount, Bal0, Bal) :
    (atm(Caller), atm(To), int(Amount), map(Bal0), var(Bal)).
:- entry approve(Caller, Spender, Amount, Own0, Own, Al0, Al) :
    (atm(Caller), atm(Spender), int(Amount), map(Own0), var(Own), map(Al0), var(Al)).
:- entry transfer_from(Caller, Sender, To, Amount, Bal0, Bal, Own0, Own, Al0, Al) :
    (atm(Caller), atm(Sender), atm(To), int(Amount), map(Bal0), var(Bal),
     map(Own0), var(Own), map(Al0), var(Al)).

% ERC20.transfer(recipient, amount) = _transfer(caller(), recipient, amount)
token_transfer(Caller, To, Amount, !Bal) :-
    transfer_(Caller, To, Amount, !Bal).

% ERC20.approve(spender, value) = _approve(caller(), spender, value)
approve(Caller, Spender, Amount, !Own, !Al) :-
    approve_(Caller, Spender, Amount, !Own, !Al).

% ERC20.transferFrom(sender, recipient, amount)
transfer_from(Caller, Sender, To, Amount, !Bal, !Own, !Al) :-
    transfer_(Sender, To, Amount, !Bal),            % _transfer(sender, recipient, amount)
    map_get(Sender, Own, none, _),                  % allowance(sender, caller()): allowances.get(owner)
    A = ~map_get(al(Sender, Caller), Al, 0),        %   .getOrDefault(spender)
    require(A >= Amount),                           % require of subtract: no negative result
    An = ~ubi_sub(A, Amount),                       % .subtract(amount)
    approve_(Sender, Caller, An, !Own, !Al).        % _approve(sender, caller(), ...)

% _transfer(sender, recipient, amount)
transfer_(Sender, To, Amount, !Bal) :-
    B1 = ~map_get(Sender, Bal, 0),                  % balanceOf(sender)
    require(B1 >= Amount),                          % require of subtract: no negative result
    B1n = ~ubi_sub(B1, Amount),                     % .subtract(amount)
    map_put(Sender, B1n, !Bal),                     % balances.put(sender, ...)
    B2 = ~map_get(To, Bal, 0),                      % balanceOf(recipient)
    B2n = ~ubi_add(B2, Amount),                     % .add(amount)
    map_put(To, B2n, !Bal),                         % balances.put(recipient, ...)
    emit(transfer).                                 % event(new Transfer(sender, recipient, amount))

% _approve(owner, spender, value)
approve_(Owner, Spender, Value, !Own, !Al) :-
    O1 = ~map_get(Owner, Own, none),                % allowances.computeIfAbsent(owner, ...): outer get
    if (O1 == none) {
        new_obj(inner_map),                         % new StorageTreeMap<>() for a new owner
        map_put(Owner, 1, !Own)                     % and its put in the outer map
    },
    map_put(al(Owner, Spender), Value, !Al),        % .put(spender, value): inner map
    emit(approval).                                 % event(new Approval(owner, spender, value))

% --- Test: alice (1000) approves bob for 500; bob moves 200 of alice to carol ---
% Expected: alice 800, carol 200, allowance of bob over alice 300.
goal([A, C, Allow]) :-
    approve(alice, bob, 500, [], Own1, [], Al1),
    transfer_from(bob, alice, carol, 200, [kv(alice, 1000)], Bal2, Own1, _, Al1, Al2),
    map_get(alice, Bal2, 0, A),
    map_get(carol, Bal2, 0, C),
    map_get(al(alice, bob), Al2, 0, Allow).
