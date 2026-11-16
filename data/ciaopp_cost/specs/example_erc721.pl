% CiaoPP cost spec of example_erc721 (NFT with owners and balances tables;
% token model of example_coin: one gas per table entry read). The clauses are
% unchanged, so the bounds that depend on a table inside the state are inf.

:- module(_, [init/4, mint/4, transferFrom/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Name, Symbol, Owners, Balances); Owners is a list of
% t_o(TokenId, Owner), Balances a list of n_b(Owner, Count), newest first.
:- regtype nftstate/1.
nftstate(state(Name, Symbol, Owners, Bals)) :-
    atm(Name), atm(Symbol), nft_owners(Owners), nft_balances(Bals).


:- entry init(Name, Symbol, S0, S) : (atm(Name), atm(Symbol), var(S0), var(S)).
:- entry mint(To, TokenId, S1, S2) : (atm(To), nnegint(TokenId), nftstate(S1), var(S2)).
:- entry transferFrom(From, To, TokenId, Caller, S1, S2) :
    (atm(From), atm(To), nnegint(TokenId), atm(Caller), nftstate(S1), var(S2)).
:- entry goal(R) : var(R).

% Inner entries (the operations above keep their bound: the tables are
% inside the state).
% mint/4: aux_cond_1 exposes the table of balances (get_nft_bal).
:- entry aux_cond_1(Owner, TokenId, To, Owners, Bals, S2, Name, Symbol, S1) :
    (atm(Owner), nnegint(TokenId), atm(To), nft_owners(Owners),
     nft_balances(Bals), var(S2), atm(Name), atm(Symbol), nftstate(S1)).
% transferFrom/6: aux_cond_2 exposes the table of balances (Owner = From =
% Caller).
:- entry aux_cond_2(Owner, From, Caller, Bals, To, TokenId, Owners, S2, Name,
                    Symbol, S1) :
    (atm(Owner), atm(From), atm(Caller), nft_balances(Bals), atm(To),
     nnegint(TokenId), nft_owners(Owners), var(S2), atm(Name), atm(Symbol),
     nftstate(S1)).
