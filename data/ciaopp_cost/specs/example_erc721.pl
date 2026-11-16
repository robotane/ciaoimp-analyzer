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
