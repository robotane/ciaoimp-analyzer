% CiaoPP cost spec of crypto_buddy on build/normalized/crypto_buddy.pl (the
% CasLog input: the fields of state(Name, TB, Allowances) are arguments).

:- module(_, [init/6, approve/9, transferFrom/10, token_transfer/9, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% init(Name, Caller, S0, Name2, TB2, Al2).
:- entry init(Name, Caller, S0, N2, TB2, Al2) :
    (atm(Name), atm(Caller), var(S0), var(N2), var(TB2), var(Al2)).
% approve(Spender, Amount, Caller, Name, TB, Al, Name2, TB2, Al2).
:- entry approve(Spender, Amount, Caller, Name, TB, Al, N2, TB2, Al2) :
    (atm(Spender), nnegint(Amount), atm(Caller), atm(Name), tok_balances(TB),
     allowances(Al), var(N2), var(TB2), var(Al2)).
% transferFrom(From, To, Amount, Caller, Name, TB, Al, Name2, TB2, Al2).
:- entry transferFrom(From, To, Amount, Caller, Name, TB, Al, N2, TB2, Al2) :
    (atm(From), atm(To), nnegint(Amount), atm(Caller), atm(Name),
     tok_balances(TB), allowances(Al), var(N2), var(TB2), var(Al2)).
% token_transfer(To, Amount, Caller, Name, TB, Al, Name2, TB2, Al2).
:- entry token_transfer(To, Amount, Caller, Name, TB, Al, N2, TB2, Al2) :
    (atm(To), nnegint(Amount), atm(Caller), atm(Name), tok_balances(TB),
     allowances(Al), var(N2), var(TB2), var(Al2)).
:- entry goal(R) : var(R).
