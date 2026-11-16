% CiaoPP cost spec of crypto_shark on build/normalized/crypto_shark.pl (the
% CasLog input: the fields of the 6-field state are arguments).

:- module(_, [init/9, mint/14, approve/15, setApprovalForAll/15, transferFrom/16, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State fields: Name, Symbol, Owners, Bals, Apprs, Ops (NFT tables).
% init(Name, Symbol, S0, Name2, Symbol2, Owners2, Bals2, Apprs2, Ops2).
:- entry init(Name, Symbol, S0, N2, Sy2, O2, B2, A2, Op2) :
    (atm(Name), atm(Symbol), var(S0), var(N2), var(Sy2), var(O2), var(B2),
     var(A2), var(Op2)).
% mint(To, TokenId, Name, Symbol, Owners, Bals, Apprs, Ops, <6 fields out>).
:- entry mint(To, Tok, Name, Symbol, Owners, Bals, Apprs, Ops,
              N2, Sy2, O2, B2, A2, Op2) :
    (atm(To), nnegint(Tok), atm(Name), atm(Symbol), nft_owners(Owners),
     nft_balances(Bals), nft_approvals(Apprs), nft_operators(Ops), var(N2),
     var(Sy2), var(O2), var(B2), var(A2), var(Op2)).
% approve(To, TokenId, Caller, <6 fields in>, <6 fields out>).
:- entry approve(To, Tok, Caller, Name, Symbol, Owners, Bals, Apprs, Ops,
                 N2, Sy2, O2, B2, A2, Op2) :
    (atm(To), nnegint(Tok), atm(Caller), atm(Name), atm(Symbol),
     nft_owners(Owners), nft_balances(Bals), nft_approvals(Apprs),
     nft_operators(Ops), var(N2), var(Sy2), var(O2), var(B2), var(A2),
     var(Op2)).
% setApprovalForAll(Operator, Flag, Caller, <6 fields in>, <6 fields out>).
:- entry setApprovalForAll(Operator, Flag, Caller, Name, Symbol, Owners, Bals,
                           Apprs, Ops, N2, Sy2, O2, B2, A2, Op2) :
    (atm(Operator), int(Flag), atm(Caller), atm(Name), atm(Symbol),
     nft_owners(Owners), nft_balances(Bals), nft_approvals(Apprs),
     nft_operators(Ops), var(N2), var(Sy2), var(O2), var(B2), var(A2),
     var(Op2)).
% transferFrom(From, To, TokenId, Caller, <6 fields in>, <6 fields out>).
:- entry transferFrom(From, To, Tok, Caller, Name, Symbol, Owners, Bals, Apprs,
                      Ops, N2, Sy2, O2, B2, A2, Op2) :
    (atm(From), atm(To), nnegint(Tok), atm(Caller), atm(Name), atm(Symbol),
     nft_owners(Owners), nft_balances(Bals), nft_approvals(Apprs),
     nft_operators(Ops), var(N2), var(Sy2), var(O2), var(B2), var(A2),
     var(Op2)).
:- entry goal(R) : var(R).
