% CryptoShark (Java: io.hotmoka.tutorial.examples.erc721.CryptoShark, an ERC721).
% The owner mints tokens; token owners approve and transfer.

:- module(_, [mint/8, approve/8, set_approval_for_all/7, transfer_from/12, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).                       % arithmetic is computed, as in Java

:- entry mint(Caller, Owner, To, TokenId, TO0, TO, NB0, NB) :
    (atm(Caller), atm(Owner), atm(To), int(TokenId), map(TO0), var(TO), map(NB0), var(NB)).
:- entry approve(Caller, To, TokenId, TO, Ap0, Ap, OO, Op) :
    (atm(Caller), atm(To), int(TokenId), map(TO), map(Ap0), var(Ap), map(OO), map(Op)).
:- entry set_approval_for_all(Caller, To, Approved, OO0, OO, Op0, Op) :
    (atm(Caller), atm(To), int(Approved), map(OO0), var(OO), map(Op0), var(Op)).
:- entry transfer_from(Caller, From, To, TokenId, TO0, TO, NB0, NB, Ap0, Ap, OO, Op) :
    (atm(Caller), atm(From), atm(To), int(TokenId), map(TO0), var(TO), map(NB0), var(NB),
     map(Ap0), var(Ap), map(OO), map(Op)).

% @FromContract mint(account, tokenId)
mint(Caller, Owner, To, TokenId, !TO, !NB) :-
    require(Caller == Owner),                       % require(caller() == owner)
    mint_(To, TokenId, !TO, !NB).

% ERC721.approve(to, tokenId)
approve(Caller, To, TokenId, TO, !Ap, OO, Op) :-
    O = ~map_get(TokenId, TO, none),                % Contract owner = ownerOf(tokenId)
    O \== none,
    require(To \== O),                              % require(to != owner)
    require((Caller == O                            % require(caller() == owner
            ; map_get(O, OO, none, _),              %   || isApprovedForAll(owner, caller()))
              V = ~map_get(op(O, Caller), Op, 0), V =:= 1)),
    map_put(TokenId, To, !Ap),                      % tokenApprovals.put(tokenId, to)
    emit(approval).                                 % event(new Approval(owner, to, tokenId))

% ERC721.setApprovalForAll(to, approved)
set_approval_for_all(Caller, To, Approved, !OO, !Op) :-
    require(To \== Caller),                         % require(to != caller())
    O1 = ~map_get(Caller, OO, none),                % operatorApprovals.computeIfAbsent(caller(), ...): outer get
    if (O1 == none) {
        new_obj(inner_map),                         % new StorageTreeMap<>() for a new owner
        map_put(Caller, 1, !OO)                     % and its put in the outer map
    },
    map_put(op(Caller, To), Approved, !Op),         % .put(to, approved): inner map
    emit(approval_for_all).                         % event(new ApprovalForAll(caller(), to, approved))

% ERC721.transferFrom(from, to, tokenId)
transfer_from(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op) :-
    transfer_from_(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op).

% ERC721 core (the work of the inherited methods follows the
% Takamaka library io.takamaka.code.tokens).
% State: TO = tokenOwners, tree map kv(TokenId, Owner);
%        NB = ownedTokensCount, tree map kv(Owner, Count);
%        Ap = tokenApprovals, tree map kv(TokenId, Approved);
%        OO = the OUTER map of operatorApprovals (owner -> inner map), a tree set kv(Owner, 1);
%        Op = the INNER maps of operatorApprovals, flattened in one tree map kv(op(Owner, Operator), Approved)
%        (CiaoPP cannot see the length of a map stored in a term: the descent in an inner map is
%        priced on the total number of pairs).
% Each UnsignedBigInteger add/subtract creates a new storage object (its gas is in ubi_add/ubi_sub);
% the tree Node of a new key is part of the cost of map_put.

% _mint(to, tokenId)
mint_(To, TokenId, !TO, !NB) :-
    E = ~map_get(TokenId, TO, none),                % _exists(tokenId): tokenOwners.get
    require(E == none),                             % require(!_exists(tokenId))
    map_put(TokenId, To, !TO),                      % tokenOwners.put(tokenId, to)
    C = ~map_get(To, NB, 0),                        % ownedTokensCount.getOrDefault(to, ZERO)
    C1 = ~ubi_add(C, 1),                            % .add(ONE)
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
    require(approved_or_owner(Caller, O, TokenId, Ap, OO, Op)),  % require(_isApprovedOrOwner(caller(), tokenId))
    O2 = ~map_get(TokenId, TO, none),               % ownerOf(tokenId) in _transferFrom
    require(O2 == From),                            % require(ownerOf(tokenId) == from)
    map_remove(TokenId, !Ap),                       % _clearApproval(tokenId)
    C1 = ~map_get(From, NB, 0),                     % ownedTokensCount.get(from)
    C1n = ~ubi_sub(C1, 1),                          % .subtract(ONE)
    map_put(From, C1n, !NB),                        % ownedTokensCount.put(from, ...)
    C2 = ~map_get(To, NB, 0),                       % ownedTokensCount.getOrDefault(to, ZERO)
    C2n = ~ubi_add(C2, 1),                          % .add(ONE)
    map_put(To, C2n, !NB),                          % ownedTokensCount.put(to, ...)
    map_put(TokenId, To, !TO),                      % tokenOwners.put(tokenId, to)
    emit(transfer).                                 % event(new Transfer(from, to, tokenId))

% --- Test: owner mints token 1 to alice; alice approves bob; bob transfers it to carol ---
% Expected: owner of token 1 = carol; counts alice 0, carol 1.
goal([Ow, A, C]) :-
    mint(owner, owner, alice, 1, [], TO1, [], NB1),
    TO1b = [kv(1, alice)], NB1b = [kv(alice, 1)],   % (literals keep the call types of the analysis typed)
    TO1 == TO1b, NB1 == NB1b,
    approve(alice, bob, 1, TO1b, [], Ap1, [], []),
    Ap1 == [kv(1, bob)],
    Ap1b = [kv(1, bob)],
    transfer_from(bob, alice, carol, 1, TO1b, TO2, NB1b, NB2, Ap1b, _, [], []),
    map_get(1, TO2, none, Ow),
    map_get(alice, NB2, none, A),
    map_get(carol, NB2, none, C).
