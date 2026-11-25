% Example ERC721 coin (Java: io.hotmoka.examples.tokens.ExampleERC721Coin, an ERC721).
% The owner mints tokens; the owner of a token (or an approved account) transfers it.

:- module(_, [mint/8, transfer_from/12, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- entry mint(Caller, Owner, To, TokenId, TO0, TO, NB0, NB) :
    (atm(Caller), atm(Owner), atm(To), int(TokenId), map(TO0), var(TO), map(NB0), var(NB)).
:- entry transfer_from(Caller, From, To, TokenId, TO0, TO, NB0, NB, Ap0, Ap, OO, Op) :
    (atm(Caller), atm(From), atm(To), int(TokenId), map(TO0), var(TO), map(NB0), var(NB),
     map(Ap0), var(Ap), map(OO), map(Op)).

% @FromContract mint(account, tokenId)
mint(Caller, Owner, To, TokenId, !TO, !NB) :-
    require(Caller == Owner),
    mint_(To, TokenId, !TO, !NB).

% ERC721.transferFrom(from, to, tokenId)
transfer_from(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op) :-
    transfer_from_(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op).

% ERC721 core, following io.takamaka.code.tokens.
% TO: tokenOwners kv(TokenId, Owner); NB: ownedTokensCount kv(Owner, Count); Ap: tokenApprovals kv(TokenId, Approved);
% OO: outer map of operatorApprovals, tree set kv(Owner, 1); Op: inner maps flattened, kv(op(Owner, Operator), Approved)
% (CiaoPP cannot see the length of a map stored in a term).

% _mint(to, tokenId)
mint_(To, TokenId, !TO, !NB) :-
    E = ~map_get(TokenId, TO, none),  % _exists(tokenId)
    require(E == none),
    map_put(TokenId, To, !TO),
    C = ~map_get(To, NB, 0),
    C1 = ~ubi_add(C, 1),
    map_put(To, C1, !NB),
    emit(transfer).

% _isApprovedOrOwner(spender, tokenId), Owner = ownerOf(tokenId) already read
approved_or_owner(Spender, Owner, TokenId, Ap, OO, Op) :-
    if (Spender == Owner) { true }
    else if ((A = ~map_get(TokenId, Ap, none), A == Spender)) { true }
    else {
        map_get(Owner, OO, none, _),  % isApprovedForAll
        V = ~map_get(op(Owner, Spender), Op, 0), V =:= 1
    }.

% transferFrom(from, to, tokenId)
transfer_from_(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op) :-
    O = ~map_get(TokenId, TO, none),
    O \== none,
    require(approved_or_owner(Caller, O, TokenId, Ap, OO, Op)),
    O2 = ~map_get(TokenId, TO, none),  % second get, as in Java
    require(O2 == From),
    map_remove(TokenId, !Ap),  % _clearApproval
    C1 = ~map_get(From, NB, 0),
    C1n = ~ubi_sub(C1, 1),
    map_put(From, C1n, !NB),
    C2 = ~map_get(To, NB, 0),
    C2n = ~ubi_add(C2, 1),
    map_put(To, C2n, !NB),
    map_put(TokenId, To, !TO),
    emit(transfer).

% Test: owner mints token 1 to alice; alice transfers it to bob. Expected [bob, 0, 1].
goal([Ow, A, B]) :-
    mint(owner, owner, alice, 1, [], TO1, [], NB1),
    TO1b = [kv(1, alice)], NB1b = [kv(alice, 1)],  % literal copy: keeps the call types
    TO1 == TO1b, NB1 == NB1b,
    transfer_from(alice, alice, bob, 1, TO1b, TO2, NB1b, NB2, [], _, [], []),
    map_get(1, TO2, none, Ow),
    map_get(alice, NB2, none, A),
    map_get(bob, NB2, none, B).
