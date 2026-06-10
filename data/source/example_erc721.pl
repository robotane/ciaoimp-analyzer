% ERC721 simple (example_erc721).
% Pas de blockchain ETH : les NFT sont gérés en interne.
% Etat : state(Name, Symbol, TokenOwners, NFTBalances)
:- module(_, [goal/1], [fsyntax, statevars, hiord, loops]).
:- fun_eval arith(true).

% --- Helpers ---

get_owner(Id, TO, Owner) :-
    Owner := 'null',
    for (Entry in list(TO)) {
        Entry = t_o(I, O),
        if (I == Id, Owner == 'null') { Owner := O }
    }.

get_nft_bal(Addr, NB, Bal) :-
    Bal := 0,
    for (Entry in list(NB)) {
        Entry = n_b(A, Amt),
        if (A == Addr, Bal == 0) { Bal := Amt }
    }.

% --- Contrat ---

init(Name, Symbol, !S) :-
    S := state(Name, Symbol, [], []).

mint(To, TokenId, !S) :-
    state(Name, Symbol, TO, NB) = S,
    get_owner(TokenId, TO, Owner),
    if (Owner == 'null') {
        TO1 := [t_o(TokenId, To) | TO],
        get_nft_bal(To, NB, ToBal),
        NewToBal is ToBal + 1,
        NB1 := [n_b(To, NewToBal) | NB],
        S := state(Name, Symbol, TO1, NB1)
    }.

transferFrom(From, To, TokenId, Caller, !S) :-
    state(Name, Symbol, TO, NB) = S,
    get_owner(TokenId, TO, Owner),
    if (Owner == From, Caller == Owner) {
        get_nft_bal(From, NB, FromBal),
        NewFromBal is FromBal - 1,
        NB1 := [n_b(From, NewFromBal) | NB],
        get_nft_bal(To, NB1, ToBal),
        NewToBal is ToBal + 1,
        NB2 := [n_b(To, NewToBal) | NB1],
        TO1 := [t_o(TokenId, To) | TO],
        S := state(Name, Symbol, TO1, NB2)
    }.

% --- Test ---
% Scenario : mint token 1 pour alice, mint token 2 pour alice,
%            alice transfère token 1 vers bob.
% Attendu : owner(1)=bob, owner(2)=alice, alice_nft=1, bob_nft=1

goal(Results) :-
    init(nft, n, _, S1),
    mint(alice, 1, S1, S2),
    mint(alice, 2, S2, S3),
    transferFrom(alice, bob, 1, alice, S3, S4),
    S4 = state(_, _, TO, NB),
    get_owner(1, TO, O1),
    get_owner(2, TO, O2),
    get_nft_bal(alice, NB, AliceNFT),
    get_nft_bal(bob,   NB, BobNFT),
    Results = [O1, O2, AliceNFT, BobNFT].
