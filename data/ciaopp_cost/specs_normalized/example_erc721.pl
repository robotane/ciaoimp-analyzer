% CiaoPP cost spec of example_erc721 on build/normalized/example_erc721.pl
% (the CasLog input: the fields of state(Name, Symbol, Owners, Bals) are
% arguments).

:- module(_, [init/7, mint/10, transferFrom/12, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% init(Name, Symbol, S0, Name2, Symbol2, Owners2, Bals2).
:- entry init(Name, Symbol, S0, N2, Sy2, O2, B2) :
    (atm(Name), atm(Symbol), var(S0), var(N2), var(Sy2), var(O2), var(B2)).
% mint(To, TokenId, Name, Symbol, Owners, Bals, <4 fields out>).
:- entry mint(To, Tok, Name, Symbol, Owners, Bals, N2, Sy2, O2, B2) :
    (atm(To), nnegint(Tok), atm(Name), atm(Symbol), nft_owners(Owners),
     nft_balances(Bals), var(N2), var(Sy2), var(O2), var(B2)).
% transferFrom(From, To, TokenId, Caller, Name, Symbol, Owners, Bals, <4 fields out>).
:- entry transferFrom(From, To, Tok, Caller, Name, Symbol, Owners, Bals,
                      N2, Sy2, O2, B2) :
    (atm(From), atm(To), nnegint(Tok), atm(Caller), atm(Name), atm(Symbol),
     nft_owners(Owners), nft_balances(Bals), var(N2), var(Sy2), var(O2),
     var(B2)).
:- entry goal(R) : var(R).
