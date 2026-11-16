% CiaoPP cost spec of example_coin (entries and types as in interreg-imdea,
% october2026/example_coin.pl, against build/executable/example_coin.pl).
% The IMDEA version adds helpers (token_transfer_/9...) so that the cost
% depends on a list given as an argument; the clauses here are unchanged,
% so the bounds of token_transfer, mint, burn and goal are inf (the token
% table is a list inside the state, which the analysis measures by term
% size only).

:- module(_, [init/5, token_transfer/5, mint/5, burn/5, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Name, Symbol, Owner, TotalSupply, TB), TB a list of
% tb(Account, Amount), newest first.
:- regtype coinstate/1.
coinstate(state(Name, Symbol, Owner, Supply, TB)) :-
    atm(Name), atm(Symbol), atm(Owner), nnegint(Supply), tok_balances(TB).


:- entry init(Name, Symbol, Caller, S0, S) :
    (atm(Name), atm(Symbol), atm(Caller), var(S0), var(S)).
:- entry token_transfer(To, Amount, Caller, S1, S2) :
    (atm(To), nnegint(Amount), atm(Caller), coinstate(S1), var(S2)).
:- entry mint(Account, Amount, Caller, S1, S2) :
    (atm(Account), nnegint(Amount), atm(Caller), coinstate(S1), var(S2)).
:- entry burn(Account, Amount, Caller, S1, S2) :
    (atm(Account), nnegint(Amount), atm(Caller), coinstate(S1), var(S2)).
:- entry goal(R) : var(R).

% Inner entries (the operations above keep their bound: the token table is
% inside the state).
% token_transfer/5: aux_cond_1 exposes the token table (get_tok_bal of the
% recipient).
:- entry aux_cond_1(Bal, Amount, Caller, TB, To, S2, Name, Symbol, Owner,
                    Supply, S1) :
    (nnegint(Bal), nnegint(Amount), atm(Caller), tok_balances(TB), atm(To),
     var(S2), atm(Name), atm(Symbol), atm(Owner), nnegint(Supply),
     coinstate(S1)).
% mint/5: aux_cond_2 exposes the token table (Caller = Owner).
:- entry aux_cond_2(Caller, Owner, Account, TB, Amount, Supply, S2, Name,
                    Symbol, S1) :
    (atm(Caller), atm(Owner), atm(Account), tok_balances(TB), nnegint(Amount),
     nnegint(Supply), var(S2), atm(Name), atm(Symbol), coinstate(S1)).
% burn/5: no inner entry. The scan of the burn is the get_tok_bal before
% aux_cond_3, in the head clause of burn/5, and aux_cond_3 itself costs 0.
