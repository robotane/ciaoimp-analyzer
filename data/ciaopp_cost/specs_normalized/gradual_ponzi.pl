% CiaoPP cost spec of gradual_ponzi on build/normalized/gradual_ponzi.pl (the
% CasLog input: state(Investors) is the list itself).

:- module(_, [init/3, invest/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% Investors, newest first.
:- regtype investors/1.
investors([]).
investors([X|T]) :- atm(X), investors(T).

% init(Caller, S0, Investors2).
:- entry init(Caller, S0, I2) : (atm(Caller), var(S0), var(I2)).
% invest(Caller, Value, Investors1, Investors2, B1, B2).
:- entry invest(Caller, Value, I1, I2, B1, B2) :
    (atm(Caller), int(Value), investors(I1), var(I2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
