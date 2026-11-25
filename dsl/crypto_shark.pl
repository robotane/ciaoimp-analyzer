% CryptoShark (Java: io.hotmoka.tutorial.examples.erc721.CryptoShark, an ERC721).
% The owner mints tokens; token owners approve and transfer.

:- module(_, [mint/8, approve/8, set_approval_for_all/7, transfer_from/12, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- storage(TO, map(object, none)).
:- storage(NB, map(amount, 0)).
:- storage(Ap, map(object, none)).
:- storage(OO, map(int, none)).  % outer map: set of owners
:- storage(Op, map(int, 0)).  % inner maps, flattened
:- amount(ubi).

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
    require(Caller == Owner),
    mint_(To, TokenId, !TO, !NB).

% ERC721.approve(to, tokenId)
approve(Caller, To, TokenId, TO, !Ap, OO, Op) :-
    O = TO[TokenId],
    O \== none,
    require(To \== O),
    require((Caller == O
            ; _ = OO[O],  % isApprovedForAll
              Op[op(O, Caller)] =:= 1)),
    Ap[TokenId] := To,
    emit(approval).

% ERC721.setApprovalForAll(to, approved)
set_approval_for_all(Caller, To, Approved, !OO, !Op) :-
    require(To \== Caller),
    O1 = OO[Caller],
    if (O1 == none) {
        new_obj(inner_map),  % new owner: new inner map
        OO[Caller] := 1
    },
    Op[op(Caller, To)] := Approved,
    emit(approval_for_all).

% ERC721.transferFrom(from, to, tokenId)
transfer_from(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op) :-
    transfer_from_(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op).

% ERC721 core, following io.takamaka.code.tokens.
% TO: tokenOwners kv(TokenId, Owner); NB: ownedTokensCount kv(Owner, Count); Ap: tokenApprovals kv(TokenId, Approved);
% OO: outer map of operatorApprovals, tree set kv(Owner, 1); Op: inner maps flattened, kv(op(Owner, Operator), Approved)
% (CiaoPP cannot see the length of a map stored in a term).

% _mint(to, tokenId)
mint_(To, TokenId, !TO, !NB) :-
    require(TO[TokenId] == none),
    TO[TokenId] := To,
    NB[To] += 1,
    emit(transfer).

% _isApprovedOrOwner(spender, tokenId), Owner = ownerOf(tokenId) already read
approved_or_owner(Spender, Owner, TokenId, Ap, OO, Op) :-
    if (Spender == Owner) { true }
    else if (Ap[TokenId] == Spender) { true }
    else {
        _ = OO[Owner],  % isApprovedForAll
        Op[op(Owner, Spender)] =:= 1
    }.

% transferFrom(from, to, tokenId)
transfer_from_(Caller, From, To, TokenId, !TO, !NB, !Ap, OO, Op) :-
    O = TO[TokenId],
    O \== none,
    require(approved_or_owner(Caller, O, TokenId, Ap, OO, Op)),
    O2 = TO[TokenId],  % second get, as in Java
    require(O2 == From),
    map_remove(TokenId, !Ap),  % _clearApproval
    NB[From] -= 1,
    NB[To] += 1,
    TO[TokenId] := To,
    emit(transfer).

% Test: owner mints token 1 to alice; alice approves bob; bob transfers it to carol. Expected [carol, 0, 1].
goal([Ow, A, C]) :-
    mint(owner, owner, alice, 1, [], TO1, [], NB1),
    TO1b = [kv(1, alice)], NB1b = [kv(alice, 1)],  % literal copy: keeps the call types
    TO1 == TO1b, NB1 == NB1b,
    approve(alice, bob, 1, TO1b, [], Ap1, [], []),
    Ap1 == [kv(1, bob)],
    Ap1b = [kv(1, bob)],
    transfer_from(bob, alice, carol, 1, TO1b, TO2, NB1b, NB2, Ap1b, _, [], []),
    map_get(1, TO2, none, Ow),
    map_get(alice, NB2, none, A),
    map_get(carol, NB2, none, C).
