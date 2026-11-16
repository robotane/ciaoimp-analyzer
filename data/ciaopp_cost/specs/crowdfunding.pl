% CiaoPP cost spec of crowdfunding (entries and types as in interreg-imdea,
% october2026/crowdfunding.pl, against build/executable/crowdfunding.pl).
% The IMDEA version moves the loops of check_goal_reached/6 into a helper
% with the campaigns as argument; here the clauses are unchanged, so the
% bounds that depend on the campaigns are inf (a list inside the state).

:- module(_, [init/2, new_campaign/5, contribute/7, check_goal_reached/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Campaigns), newest first.
:- regtype crowdstate/1.
crowdstate(state(Cs)) :- campaigns(Cs).

:- regtype campaigns/1.
campaigns([]).
campaigns([C|Cs]) :- campaign(C), campaigns(Cs).

:- regtype campaign/1.
campaign(campaign(Id, Ben, Goal, Amount, Funders)) :-
    nnegint(Id), atm(Ben), nnegint(Goal), int(Amount), funders(Funders).

:- regtype funders/1.
funders([]).
funders([F|Fs]) :- funder(F), funders(Fs).

:- regtype funder/1.
funder(funder(Who, Amount)) :- atm(Who), int(Amount).

:- entry init(Caller, S) : (atm(Caller), var(S)).
:- entry new_campaign(Ben, Goal, Id, S1, S2) :
    (atm(Ben), nnegint(Goal), var(Id), crowdstate(S1), var(S2)).
:- entry contribute(Caller, Amount, CampaignId, S1, S2, B1, B2) :
    (atm(Caller), nnegint(Amount), nnegint(CampaignId), crowdstate(S1),
     var(S2), balances(B1), var(B2)).
:- entry check_goal_reached(CampaignId, Reached, S1, S2, B1, B2) :
    (nnegint(CampaignId), var(Reached), crowdstate(S1), var(S2),
     balances(B1), var(B2)).
:- entry goal(R) : var(R).
