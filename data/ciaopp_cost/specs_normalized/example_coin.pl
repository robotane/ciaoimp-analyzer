% CiaoPP cost spec of example_coin on build/normalized/example_coin.pl (the
% CasLog input: the fields of state(Name, Symbol, Owner, Supply, TB) are
% arguments).

:- module(_, [init/9, token_transfer/13, mint/13, burn/13, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% init(Name, Symbol, Caller, S0, Name2, Symbol2, Owner2, Supply2, TB2).
:- entry init(Name, Symbol, Caller, S0, N2, Sy2, O2, Su2, TB2) :
    (atm(Name), atm(Symbol), atm(Caller), var(S0), var(N2), var(Sy2),
     var(O2), var(Su2), var(TB2)).
% token_transfer(To, Amount, Caller, Name, Symbol, Owner, Supply, TB, <5 fields out>).
:- entry token_transfer(To, Amount, Caller, Name, Symbol, Owner, Supply, TB,
                        N2, Sy2, O2, Su2, TB2) :
    (atm(To), nnegint(Amount), atm(Caller), atm(Name), atm(Symbol),
     atm(Owner), nnegint(Supply), tok_balances(TB), var(N2), var(Sy2),
     var(O2), var(Su2), var(TB2)).
% mint(Account, Amount, Caller, Name, Symbol, Owner, Supply, TB, <5 fields out>).
:- entry mint(Account, Amount, Caller, Name, Symbol, Owner, Supply, TB,
              N2, Sy2, O2, Su2, TB2) :
    (atm(Account), nnegint(Amount), atm(Caller), atm(Name), atm(Symbol),
     atm(Owner), nnegint(Supply), tok_balances(TB), var(N2), var(Sy2),
     var(O2), var(Su2), var(TB2)).
% burn(Account, Amount, Caller, Name, Symbol, Owner, Supply, TB, <5 fields out>).
:- entry burn(Account, Amount, Caller, Name, Symbol, Owner, Supply, TB,
              N2, Sy2, O2, Su2, TB2) :
    (atm(Account), nnegint(Amount), atm(Caller), atm(Name), atm(Symbol),
     atm(Owner), nnegint(Supply), tok_balances(TB), var(N2), var(Sy2),
     var(O2), var(Su2), var(TB2)).
:- entry goal(R) : var(R).
