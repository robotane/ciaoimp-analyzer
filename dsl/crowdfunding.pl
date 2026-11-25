% Crowdfunding (Java: io.hotmoka.examples.crowdfunding.CrowdFunding).
% Campaigns collect contributions; when the goal is reached the beneficiary is paid.
% Cs: campaigns, list of campaign(Beneficiary, Goal, Amount, Funders); the id is the list index.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/1, new_campaign/5, contribute/7, check_goal_reached/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).

:- class(campaign(beneficiary, goal, amount, funders)).
:- storage(Cs, list).

% campaigns.get(id) returns a Campaign.
:- trust success list_get(_, _, C) => campaign(C).

:- regtype campaigns/1.
campaigns([]).
campaigns([C|T]) :- campaign(C), campaigns(T).
:- regtype campaign/1.
campaign(campaign(Ben, Goal, Amount, Funders)) :- atm(Ben), int(Goal), int(Amount), funders(Funders).
:- regtype funders/1.
funders([]).
funders([funder(W, A)|T]) :- atm(W), int(A), funders(T).

:- entry new_campaign(Ben, Goal, Cs0, Cs, Id) :
    (atm(Ben), int(Goal), campaigns(Cs0), var(Cs), var(Id)).
:- entry contribute(Caller, Amount, Id, Cs0, Cs, B0, B) :
    (atm(Caller), int(Amount), int(Id), campaigns(Cs0), var(Cs), balances(B0), var(B)).
:- entry check_goal_reached(Id, Cs0, Cs, B0, B, Reached) :
    (int(Id), campaigns(Cs0), var(Cs), balances(B0), var(B), var(Reached)).

init([]).

% newCampaign(beneficiary, goal)
new_campaign(Ben, Goal, !Cs, Id) :-
    N = ~list_size(Cs),
    new_obj(campaign),
    new_obj(funders),
    list_add(campaign(Ben, Goal, 0, []), !Cs),
    Id = N.

:- payable(contribute).

% @FromContract contribute(amount, campaignID)
contribute(Caller, Amount, Id, !Cs, !B) :-
    Camp = Cs[Id],
    Funders = Camp[funders],
    Ben = Camp[beneficiary], Goal = Camp[goal], Amt = Camp[amount],
    new_obj(funder),
    list_add(funder(Caller, Amount), Funders, _),  % cost only
    Camp := campaign(Ben, Goal, Amt, [funder(Caller, Amount)|Funders]),  % list mutated in place: no field write
    Camp[amount] += Amount,
    list_set(Id, Camp, !Cs).  % in place in Java

% checkGoalReached(campaignID)
check_goal_reached(Id, !Cs, !B, Reached) :-
    Camp = Cs[Id],
    Amt = Camp[amount],
    Goal = Camp[goal],
    Ben = Camp[beneficiary],
    if (Amt < Goal) {
        Reached = 0
    } else {
        Camp[amount] := 0,
        list_set(Id, Camp, !Cs),
        transfer(this, Ben, Amt, !B),
        Reached = 1
    }.

% Test: bene creates a campaign (goal 300); alice gives 200, bob 150; goal reached. Expected [800, 850, 350, 0, 1].
goal([A, Bo, Be, T, R]) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
    init(Cs0),
    new_campaign(bene, 300, Cs0, Cs1, 0),
    Cs1 == [campaign(bene, 300, 0, [])],  % literal copy: keeps the call types
    Cs1b = [campaign(bene, 300, 0, [])],
    contribute(alice, 200, 0, Cs1b, Cs2, B0, B1),
    contribute(bob, 150, 0, Cs2, Cs3, B1, B2),
    check_goal_reached(0, Cs3, _, B2, B3, R),
    balance(alice, B3, A),
    balance(bob, B3, Bo),
    balance(bene, B3, Be),
    balance(this, B3, T).
