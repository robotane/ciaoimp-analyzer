% CiaoPP cost spec of crypto_shark (NFT with approvals and operator
% approvals; token model of example_coin: one gas per table entry read). The
% clauses are unchanged, so the bounds that depend on a table inside the
% state are inf.

:- module(_, [init/4, mint/4, approve/5, setApprovalForAll/5, transferFrom/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Name, Symbol, Owners, Balances, Approvals, Operators):
% t_o(TokenId, Owner), n_b(Owner, Count), app(TokenId, Approved),
% op(Owner, Operator, Flag), newest first.
:- regtype sharkstate/1.
sharkstate(state(Name, Symbol, Owners, Bals, Apprs, Ops)) :-
    atm(Name), atm(Symbol), nft_owners(Owners), nft_balances(Bals), nft_approvals(Apprs), nft_operators(Ops).


:- entry init(Name, Symbol, S0, S) : (atm(Name), atm(Symbol), var(S0), var(S)).
:- entry mint(To, TokenId, S1, S2) : (atm(To), nnegint(TokenId), sharkstate(S1), var(S2)).
:- entry approve(To, TokenId, Caller, S1, S2) :
    (atm(To), nnegint(TokenId), atm(Caller), sharkstate(S1), var(S2)).
:- entry setApprovalForAll(Operator, Flag, Caller, S1, S2) :
    (atm(Operator), int(Flag), atm(Caller), sharkstate(S1), var(S2)).
:- entry transferFrom(From, To, TokenId, Caller, S1, S2) :
    (atm(From), atm(To), nnegint(TokenId), atm(Caller), sharkstate(S1), var(S2)).
:- entry goal(R) : var(R).

% Inner entries (the operations above keep their bound: the tables sit
% inside the state).
% mint/4: aux_cond_1 exposes the table of NFT balances (get_nft_bal).
:- entry aux_cond_1(Owner, TokenId, To, Owners, Bals, S2, Name, Symbol, Apprs,
                    Ops, S1) :
    (atm(Owner), nnegint(TokenId), atm(To), nft_owners(Owners),
     nft_balances(Bals), var(S2), atm(Name), atm(Symbol),
     nft_approvals(Apprs), nft_operators(Ops), sharkstate(S1)).
% transferFrom/6: aux_cond_3 exposes the approvals (get_appr), the operators
% (get_op_appr) and, through aux_cond_4, the NFT balances.
:- entry aux_cond_3(Owner, From, TokenId, Apprs, Caller, Ops, Bals, To, Owners,
                    S2, Name, Symbol, S1) :
    (atm(Owner), atm(From), nnegint(TokenId), nft_approvals(Apprs),
     atm(Caller), nft_operators(Ops), nft_balances(Bals), atm(To),
     nft_owners(Owners), var(S2), atm(Name), atm(Symbol), sharkstate(S1)).
