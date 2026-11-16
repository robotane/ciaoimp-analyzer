% CiaoPP cost spec of simple_pyramid (types as in interreg-imdea,
% october2026/simple_pyramid.pl, against build/executable/simple_pyramid.pl).

:- module(_, [init/3, invest/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Investors, PreviousAmount), Investors newest first and never
% empty (init/3 puts the creator, invest/6 only adds).
:- regtype investors/1.
investors([X|T]) :- atm(X), investors_(T).
:- regtype investors_/1.
investors_([]).
investors_([X|T]) :- atm(X), investors_(T).

:- regtype pyrstate/1.
pyrstate(state(Investors, Prev)) :- investors(Investors), nnegint(Prev).

:- entry init(Caller, S0, S) : (atm(Caller), var(S0), var(S)).
% inf upper bound of invest/6: the cost depends on length(Investors), a list
% inside the state, which the analysis measures by term size only.
:- entry invest(Caller, Amount, S1, S2, B1, B2) :
    (atm(Caller), nnegint(Amount), pyrstate(S1), var(S2), balances(B1), var(B2)).
:- entry goal(R) : var(R).

% Inner entry (as in interreg-imdea): aux_cond_1/8 is the body of invest/6
% with the investors as an argument of its own, so its bound is finite in
% length(Investors).
:- entry aux_cond_1(Amount, Threshold, Caller, B1, Investors, B2, S2, S1) :
    ( nnegint(Amount), nnegint(Threshold), atm(Caller), balances(B1),
      investors(Investors), var(B2), var(S2), pyrstate(S1) ).
