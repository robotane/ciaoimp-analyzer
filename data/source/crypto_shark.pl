% ERC721 avec approbations par token et par opérateur (crypto_shark).
% Pas de blockchain ETH : les NFT sont gérés en interne.
% Etat : state(Name, Symbol, TokenOwners, NFTBalances, Approvals, OpApprovals)
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

get_appr(Id, App, Spender) :-
    Spender := 'null',
    for (Entry in list(App)) {
        Entry = app(I, S),
        if (I == Id, Spender == 'null') { Spender := S }
    }.

get_op_appr(Owner, Operator, Op, Approved) :-
    Approved := 0,
    for (Entry in list(Op)) {
        Entry = op(O, OpAddr, V),
        if (O == Owner, OpAddr == Operator, Approved == 0) { Approved := V }
    }.

% --- Contrat ---

init(Name, Symbol, !S) :-
    S := state(Name, Symbol, [], [], [], []).

mint(To, TokenId, !S) :-
    state(Name, Symbol, TO, NB, App, Op) = S,
    get_owner(TokenId, TO, Owner),
    if (Owner == 'null') {
        TO1 := [t_o(TokenId, To) | TO],
        get_nft_bal(To, NB, ToBal),
        NewToBal is ToBal + 1,
        NB1 := [n_b(To, NewToBal) | NB],
        S := state(Name, Symbol, TO1, NB1, App, Op)
    }.

approve(To, TokenId, Caller, !S) :-
    state(Name, Symbol, TO, NB, App, Op) = S,
    get_owner(TokenId, TO, Owner),
    if (Caller == Owner) {
        App1 := [app(TokenId, To) | App],
        S := state(Name, Symbol, TO, NB, App1, Op)
    }.

setApprovalForAll(Operator, Approved, Caller, !S) :-
    state(Name, Symbol, TO, NB, App, Op) = S,
    Op1 := [op(Caller, Operator, Approved) | Op],
    S := state(Name, Symbol, TO, NB, App, Op1).

transferFrom(From, To, TokenId, Caller, !S) :-
    state(Name, Symbol, TO, NB, App, Op) = S,
    get_owner(TokenId, TO, Owner),
    if (Owner == From) {
        get_appr(TokenId, App, Spender),
        get_op_appr(Owner, Caller, Op, OpApproved),
        if (Caller == Owner ; Spender == Caller ; OpApproved == 1) {
            App1 := [app(TokenId, 'null') | App],
            get_nft_bal(From, NB, FromBal),
            NewFromBal is FromBal - 1,
            NB1 := [n_b(From, NewFromBal) | NB],
            get_nft_bal(To, NB1, ToBal),
            NewToBal is ToBal + 1,
            NB2 := [n_b(To, NewToBal) | NB1],
            TO1 := [t_o(TokenId, To) | TO],
            S := state(Name, Symbol, TO1, NB2, App1, Op)
        }
    }.

% --- Test ---
% Scenario : mint token 1 pour alice, alice approuve bob pour token 1,
%            bob transfère token 1 vers charlie.
% Attendu : alice=0 NFT, charlie=1 NFT, owner(1)=charlie

goal(Results) :-
    init(shark, s, _, S1),
    mint(alice, 1, S1, S2),
    approve(bob, 1, alice, S2, S3),
    transferFrom(alice, charlie, 1, bob, S3, S4),
    S4 = state(_, _, TO, NB, _, _),
    get_owner(1, TO, OwnerToken1),
    get_nft_bal(alice,   NB, AliceNFT),
    get_nft_bal(charlie, NB, CharlieNFT),
    Results = [OwnerToken1, AliceNFT, CharlieNFT].
