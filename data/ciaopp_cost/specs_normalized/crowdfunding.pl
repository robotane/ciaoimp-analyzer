% CiaoPP cost spec of crowdfunding on build/normalized/crowdfunding.pl (the
% CasLog input: state(Campaigns) is the list itself).

:- module(_, [init/2, new_campaign/5, contribute/7, check_goal_reached/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

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

% init(Caller, Campaigns2).
:- entry init(Caller, Cs) : (atm(Caller), var(Cs)).
% new_campaign(Beneficiary, Goal, Id, Campaigns1, Campaigns2).
:- entry new_campaign(Ben, Goal, Id, Cs1, Cs2) :
    (atm(Ben), nnegint(Goal), var(Id), campaigns(Cs1), var(Cs2)).
% contribute(Caller, Amount, CampaignId, Campaigns1, Campaigns2, B1, B2).
:- entry contribute(Caller, Amount, Id, Cs1, Cs2, B1, B2) :
    (atm(Caller), nnegint(Amount), nnegint(Id), campaigns(Cs1), var(Cs2),
     balances(B1), var(B2)).
% check_goal_reached(CampaignId, Reached, Campaigns1, Campaigns2, B1, B2).
:- entry check_goal_reached(Id, Reached, Cs1, Cs2, B1, B2) :
    (nnegint(Id), var(Reached), campaigns(Cs1), var(Cs2), balances(B1),
     var(B2)).
:- entry goal(R) : var(R).
