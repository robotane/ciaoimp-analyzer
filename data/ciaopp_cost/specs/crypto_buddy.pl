% CiaoPP cost spec of crypto_buddy (ERC20 with allowances; the token model of
% example_coin extended with get_allow/4). The clauses are unchanged, so the
% bounds that depend on a table inside the state are inf (the analysis
% measures a list inside a structure by term size only).

:- module(_, [init/4, approve/5, transferFrom/6, token_transfer/5, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Name, TB, Allowances); Allowances is a list of
% al(Owner, Spender, Amount), newest first.
:- regtype buddystate/1.
buddystate(state(Name, TB, Al)) :- atm(Name), tok_balances(TB), allowances(Al).


:- entry init(Name, Caller, S0, S) : (atm(Name), atm(Caller), var(S0), var(S)).
:- entry approve(Spender, Amount, Caller, S1, S2) :
    (atm(Spender), nnegint(Amount), atm(Caller), buddystate(S1), var(S2)).
:- entry transferFrom(From, To, Amount, Caller, S1, S2) :
    (atm(From), atm(To), nnegint(Amount), atm(Caller), buddystate(S1), var(S2)).
:- entry token_transfer(To, Amount, Caller, S1, S2) :
    (atm(To), nnegint(Amount), atm(Caller), buddystate(S1), var(S2)).
:- entry goal(R) : var(R).
