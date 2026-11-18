% Example ERC721 coin (Java: io.hotmoka.examples.tokens.ExampleERC721Coin, an ERC721).
% The owner mints tokens; the owner of a token (or an approved account) transfers it.

:- module(_, [mint/8, transfer_from/12, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).                       % arithmetic is computed, as in Java

:- entry mint(Caller, Owner, To, TokenId, TO0, TO, NB0, NB) :
    (atm(Caller), atm(Owner), atm(To), int(TokenId), map(TO0), var(TO), map(NB0), var(NB)).
:- entry transfer_from(Caller, From, To, TokenId, TO0, TO, NB0, NB, Ap0, Ap, OO, Op) :
    (atm(Caller), atm(From), atm(To), int(TokenId), map(TO0), var(TO), map(NB0), var(NB),
     map(Ap0), var(Ap), map(OO), map(Op)).

% @FromContract mint(account, tokenId)
mint(Caller, Owner, To, TokenId, !TO, !NB) :-
    Caller == Owner,                                % require(caller() == owner)
    mint_(To, TokenId, !TO, !NB).

% ERC721.transferFrom(from, to, tokenId)
transfer_from(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op) :-
    transfer_from_(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op).

% No field write: the library only updates storage maps here (inferred from the standard ERC721 implementation).
% ERC721 core (the Takamaka sources are not on disk: the work of the inherited methods follows
% hotmoka-bench/costmodel/java_vs_prolog.md (lib)).
% State: TO = tokenOwners, tree map kv(TokenId, Owner);
%        NB = ownedTokensCount, tree map kv(Owner, Count);
%        Ap = tokenApprovals, tree map kv(TokenId, Approved);
%        OO = the OUTER map of operatorApprovals (owner -> inner map), a tree set kv(Owner, 1);
%        Op = the INNER maps of operatorApprovals, flattened in one tree map kv(op(Owner, Operator), Approved)
%        (CiaoPP cannot see the length of a map stored in a term: the descent in an inner map is
%        priced on the total number of pairs).
% Each UnsignedBigInteger add/subtract creates a new storage object (new_obj);
% the tree Node of a new key is part of the cost of map_put.

% _mint(to, tokenId)
mint_(To, TokenId, !TO, !NB) :-
    E = ~map_get(TokenId, TO, none),                % require(!_exists(tokenId)): tokenOwners.get
    E == none,
    map_put(TokenId, To, !TO),                      % tokenOwners.put(tokenId, to)
    C = ~map_get(To, NB, 0),                        % ownedTokensCount.getOrDefault(to, ZERO)
    new_obj(ubi),                                   % .add(ONE)
    C1 = C + 1,
    map_put(To, C1, !NB),                           % ownedTokensCount.put(to, ...)
    emit(transfer).                                 % event(new Transfer(null, to, tokenId))

% _isApprovedOrOwner(spender, tokenId), Owner = ownerOf(tokenId) already read
approved_or_owner(Spender, Owner, TokenId, Ap, OO, Op) :-
    if (Spender == Owner) { true }
    else if ((A = ~map_get(TokenId, Ap, none), A == Spender)) { true }   % getApproved(tokenId) == spender
    else {
        map_get(Owner, OO, none, _),                            % isApprovedForAll(owner, spender):
        V = ~map_get(op(Owner, Spender), Op, 0), V =:= 1        %   operatorApprovals.get(owner).getOrDefault(spender)
    }.

% transferFrom(from, to, tokenId)
transfer_from_(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op) :-
    O = ~map_get(TokenId, TO, none),                % ownerOf(tokenId) in _isApprovedOrOwner
    O \== none,
    approved_or_owner(Caller, O, TokenId, Ap, OO, Op),   % require(_isApprovedOrOwner(caller(), tokenId))
    O2 = ~map_get(TokenId, TO, none),               % require(ownerOf(tokenId) == from) in _transferFrom
    O2 == From,
    map_remove(TokenId, !Ap),                       % _clearApproval(tokenId)
    C1 = ~map_get(From, NB, 0),                     % ownedTokensCount.get(from)
    new_obj(ubi),                                   % .subtract(ONE)
    C1n = C1 - 1,
    map_put(From, C1n, !NB),                        % ownedTokensCount.put(from, ...)
    C2 = ~map_get(To, NB, 0),                       % ownedTokensCount.getOrDefault(to, ZERO)
    new_obj(ubi),                                   % .add(ONE)
    C2n = C2 + 1,
    map_put(To, C2n, !NB),                          % ownedTokensCount.put(to, ...)
    map_put(TokenId, To, !TO),                      % tokenOwners.put(tokenId, to)
    emit(transfer).                                 % event(new Transfer(from, to, tokenId))

% --- Test: owner mints token 1 to alice; alice transfers it to bob ---
% Expected: owner of token 1 = bob; counts alice 0, bob 1.
goal([Ow, A, B]) :-
    mint(owner, owner, alice, 1, [], TO1, [], NB1),
    TO1b = [kv(1, alice)], NB1b = [kv(alice, 1)],   % (literals keep the call types of the analysis typed)
    TO1 == TO1b, NB1 == NB1b,
    transfer_from(alice, alice, bob, 1, TO1b, TO2, NB1b, NB2, [], _, [], []),
    map_get(1, TO2, none, Ow),
    map_get(alice, NB2, none, A),
    map_get(bob, NB2, none, B).
