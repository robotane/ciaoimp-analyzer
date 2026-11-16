% CiaoPP cost spec of gradual_ponzi (types as in interreg-imdea,
% march2026/gradual_ponzi.pl, against build/executable/gradual_ponzi.pl).

:- module(_, [init/3, invest/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Investors), newest first.
:- regtype investors/1.
investors([]).
investors([X|T]) :- atm(X), investors(T).

:- regtype gradstate/1.
gradstate(state(Investors)) :- investors(Investors).

:- entry init(Caller, S0, S) : (atm(Caller), var(S0), var(S)).
% inf upper bound of invest/6: the cost depends on length(Investors), a list
% inside the state, which the analysis measures by term size only.
:- entry invest(Caller, Value, S1, S2, B1, B2) :
    (atm(Caller), int(Value), gradstate(S1), var(S2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
