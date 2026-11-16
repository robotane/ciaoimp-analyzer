% CiaoPP cost spec of simple_ponzi on build/normalized/simple_ponzi.pl (the
% CasLog input: the fields of state(LastInvestor, LastAmount) are arguments).

:- module(_, [init/3, invest/8, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% init(Caller, Last2, LastAmount2).
:- entry init(Caller, L2, A2) : (atm(Caller), var(L2), var(A2)).
% invest(Caller, Amount, Last, LastAmount, Last2, LastAmount2, B1, B2).
:- entry invest(Caller, Amount, Last, LastA, L2, A2, B1, B2) :
    (atm(Caller), int(Amount), atm(Last), int(LastA), var(L2), var(A2),
     balances(B1), var(B2)).
:- entry goal(R) : var(R).
