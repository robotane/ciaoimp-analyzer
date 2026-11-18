% Example coin (Java: io.hotmoka.examples.tokens.ExampleCoin, an ERC20).
% The owner can mint and burn; anybody can transfer.
% State: Bal = balances, StorageTreeMap<Contract, UnsignedBigInteger>, tree map kv(Holder, Amount);
%        Total = totalSupply; Owner (read only).
% Each UnsignedBigInteger add/subtract creates a new storage object (new_obj);
% the tree Node of a new key is part of the cost of map_put.
% The ERC20 sources are not on disk: the work of the inherited methods follows
% hotmoka-bench/costmodel/java_vs_prolog.md (lib).
% Field writes: those of the library methods are inferred from the standard ERC20 implementation
% (totalSupply is reassigned in _mint and _burn; balances is only a map).

:- module(_, [token_transfer/5, mint/8, burn/8, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- entry token_transfer(Caller, To, Amount, Bal0, Bal) :
    (atm(Caller), atm(To), int(Amount), map(Bal0), var(Bal)).
:- entry mint(Caller, Owner, Account, Amount, Bal0, Bal, Total0, Total) :
    (atm(Caller), atm(Owner), atm(Account), int(Amount), map(Bal0), var(Bal), int(Total0), var(Total)).
:- entry burn(Caller, Owner, Account, Amount, Bal0, Bal, Total0, Total) :
    (atm(Caller), atm(Owner), atm(Account), int(Amount), map(Bal0), var(Bal), int(Total0), var(Total)).

% ERC20.transfer(recipient, amount) = _transfer(caller(), recipient, amount)
token_transfer(Caller, To, Amount, !Bal) :-
    map_get(Caller, Bal, 0, B1),                    % balanceOf(sender)
    B1 >= Amount,                                   % subtract: fails if negative
    new_obj(ubi),                                   % .subtract(amount): new UnsignedBigInteger
    B1n is B1 - Amount,
    map_put(Caller, B1n, !Bal),                     % balances.put(sender, ...)
    map_get(To, Bal, 0, B2),                        % balanceOf(recipient)
    new_obj(ubi),                                   % .add(amount): new UnsignedBigInteger
    B2n is B2 + Amount,
    map_put(To, B2n, !Bal),                         % balances.put(recipient, ...)
    emit(transfer).                                 % event(new Transfer(sender, recipient, amount))

% @FromContract mint(account, amount)
mint(Caller, Owner, Account, Amount, !Bal, !Total) :-
    Caller == Owner,                                % require(caller() == owner)
    new_obj(ubi),                                   % totalSupply.add(amount)
    Tn is Total + Amount,
    Total := Tn,                                    % lib: totalSupply = totalSupply.add/subtract(amount)
    map_get(Account, Bal, 0, B0),                   % balanceOf(account)
    new_obj(ubi),                                   % .add(amount)
    B1 is B0 + Amount,
    map_put(Account, B1, !Bal),                     % balances.put(account, ...)
    emit(transfer).                                 % event(new Transfer(null, account, amount))

% @FromContract burn(account, amount)
burn(Caller, Owner, Account, Amount, !Bal, !Total) :-
    Caller == Owner,                                % require(caller() == owner)
    new_obj(ubi),                                   % totalSupply.subtract(amount)
    Tn is Total - Amount,
    Total := Tn,                                    % lib: totalSupply = totalSupply.add/subtract(amount)
    map_get(Account, Bal, 0, B0),                   % balanceOf(account)
    B0 >= Amount,
    new_obj(ubi),                                   % .subtract(amount)
    B1 is B0 - Amount,
    map_put(Account, B1, !Bal),                     % balances.put(account, ...)
    emit(transfer).                                 % event(new Transfer(account, null, amount))

% --- Test: owner holds 1000; mints 500 to alice, transfers 300 to bob, burns 100 of alice ---
% Expected: owner 700, alice 400, bob 300, total 1400.
goal([O, A, Bo, T]) :-
    Bal0 = [kv(owner, 1000)],
    mint(owner, owner, alice, 500, Bal0, Bal1, 1000, T1),
    token_transfer(owner, bob, 300, Bal1, Bal2),
    burn(owner, owner, alice, 100, Bal2, Bal3, T1, T),
    map_get(owner, Bal3, 0, O),
    map_get(alice, Bal3, 0, A),
    map_get(bob, Bal3, 0, Bo).
