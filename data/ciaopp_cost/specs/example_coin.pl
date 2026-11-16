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
