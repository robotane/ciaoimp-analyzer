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

% Inner entries (the operations above keep their bound: the tables sit
% inside the state).
% transferFrom/6: aux_cond_1 is what follows the two scans; it exposes the
% token table (get_tok_bal of the recipient) and the allowances.
:- entry aux_cond_1(Allow, Amount, Bal, From, Caller, Al, TB, To, S2, Name, S1) :
    (nnegint(Allow), nnegint(Amount), nnegint(Bal), atm(From), atm(Caller),
     allowances(Al), tok_balances(TB), atm(To), var(S2), atm(Name),
     buddystate(S1)).
% token_transfer/5: aux_cond_2 exposes the token table.
:- entry aux_cond_2(Bal, Amount, Caller, TB, To, S2, Name, Al, S1) :
    (nnegint(Bal), nnegint(Amount), atm(Caller), tok_balances(TB), atm(To),
     var(S2), atm(Name), allowances(Al), buddystate(S1)).
