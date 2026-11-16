% CiaoPP cost spec of simple_pyramid on build/normalized/simple_pyramid.pl
% (the CasLog input: the fields of state(Investors, Previous) are arguments).

:- module(_, [init/4, invest/8, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% Investors, newest first, never empty.
:- regtype investors/1.
investors([X|T]) :- atm(X), investors_(T).
:- regtype investors_/1.
investors_([]).
investors_([X|T]) :- atm(X), investors_(T).

% init(Caller, _, Investors, Previous).
:- entry init(Caller, X, Inv, Prev) : (atm(Caller), var(X), var(Inv), var(Prev)).
% invest(Caller, Amount, Inv1, Prev1, Inv2, Prev2, B1, B2).
:- entry invest(Caller, Amount, Inv1, Prev1, Inv2, Prev2, B1, B2) :
    ( atm(Caller), nnegint(Amount), investors(Inv1), nnegint(Prev1),
      var(Inv2), var(Prev2), balances(B1), var(B2) ).
:- entry goal(R) : var(R).
