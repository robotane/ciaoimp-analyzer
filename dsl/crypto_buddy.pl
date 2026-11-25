% CryptoBuddy (Java: io.hotmoka.tutorial.examples.erc20.CryptoBuddy, an ERC20).
% Bal: balances, tree map kv(Holder, Amount); Own: outer allowance map, tree set kv(Owner, 1);
% Al: inner allowance maps flattened in one tree map kv(al(Owner, Spender), Amount), because CiaoPP
% cannot see the length of a map stored in a term. Only the measured operations are written.

:- module(_, [token_transfer/5, approve/7, transfer_from/10, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

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
    transfer_(Sender, To, Amount, !Bal),
    map_get(Sender, Own, none, _),  % allowances.get(owner)
    A = ~map_get(al(Sender, Caller), Al, 0),  % inner get
    require(A >= Amount),
    An = ~ubi_sub(A, Amount),
    approve_(Sender, Caller, An, !Own, !Al).

% _transfer(sender, recipient, amount)
transfer_(Sender, To, Amount, !Bal) :-
    B1 = ~map_get(Sender, Bal, 0),  % balanceOf(sender)
    require(B1 >= Amount),  % subtract: no negative result
    B1n = ~ubi_sub(B1, Amount),
    map_put(Sender, B1n, !Bal),
    B2 = ~map_get(To, Bal, 0),
    B2n = ~ubi_add(B2, Amount),
    map_put(To, B2n, !Bal),
    emit(transfer).

% _approve(owner, spender, value)
approve_(Owner, Spender, Value, !Own, !Al) :-
    O1 = ~map_get(Owner, Own, none),
    if (O1 == none) {
        new_obj(inner_map),  % new owner: new inner map
        map_put(Owner, 1, !Own)
    },
    map_put(al(Owner, Spender), Value, !Al),
    emit(approval).

% Test: alice (1000) approves bob for 500; bob moves 200 of alice to carol. Expected [800, 200, 300].
% Expected: alice 800, carol 200, allowance of bob over alice 300.
goal([A, C, Allow]) :-
    approve(alice, bob, 500, [], Own1, [], Al1),
    transfer_from(bob, alice, carol, 200, [kv(alice, 1000)], Bal2, Own1, _, Al1, Al2),
    map_get(alice, Bal2, 0, A),
    map_get(carol, Bal2, 0, C),
    map_get(al(alice, bob), Al2, 0, Allow).
