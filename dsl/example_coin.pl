% Example coin (Java: io.hotmoka.examples.tokens.ExampleCoin, an ERC20).
% The owner can mint and burn; anybody can transfer.
% Bal: balances, tree map kv(Holder, Amount); Total: totalSupply.

:- module(_, [token_transfer/5, mint/8, burn/8, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- entry token_transfer(Caller, To, Amount, Bal0, Bal) :
    (atm(Caller), atm(To), int(Amount), map(Bal0), var(Bal)).
:- entry mint(Caller, Owner, Account, Amount, Bal0, Bal, Total0, Total) :
    (atm(Caller), atm(Owner), atm(Account), int(Amount), map(Bal0), var(Bal), int(Total0), var(Total)).
:- entry burn(Caller, Owner, Account, Amount, Bal0, Bal, Total0, Total) :
    (atm(Caller), atm(Owner), atm(Account), int(Amount), map(Bal0), var(Bal), int(Total0), var(Total)).

:- storage(Bal, map(amount, 0)).  % getOrDefault(holder, ZERO)
:- storage(Total, amount).
:- amount(ubi).  % UnsignedBigInteger: ubi_add/ubi_sub

% transfer(recipient, amount)
token_transfer(Caller, To, Amount, !Bal) :-
    B = Bal[Caller],
    require(B >= Amount),  % subtract: no negative result
    Bal[Caller] := ~ubi_sub(B, Amount),
    Bal[To] += Amount,
    emit(transfer).

% @FromContract mint(account, amount)
mint(Caller, Owner, Account, Amount, !Bal, !Total) :-
    require(Caller == Owner),
    Total += Amount,
    Bal[Account] += Amount,
    emit(transfer).

% @FromContract burn(account, amount)
burn(Caller, Owner, Account, Amount, !Bal, !Total) :-
    require(Caller == Owner),
    Total -= Amount,
    B = Bal[Account],
    require(B >= Amount),
    Bal[Account] := ~ubi_sub(B, Amount),
    emit(transfer).

% Test: owner holds 1000; mints 500 to alice, sends 300 to bob, burns 100 of alice. Expected [700, 400, 300, 1400].
goal([O, A, Bo, T]) :-
    Bal0 = [kv(owner, 1000)],
    mint(owner, owner, alice, 500, Bal0, Bal1, 1000, T1),
    token_transfer(owner, bob, 300, Bal1, Bal2),
    burn(owner, owner, alice, 100, Bal2, Bal3, T1, T),
    map_get(owner, Bal3, 0, O),
    map_get(alice, Bal3, 0, A),
    map_get(bob, Bal3, 0, Bo).
