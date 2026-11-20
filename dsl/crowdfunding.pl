% Crowdfunding (Java: io.hotmoka.examples.crowdfunding.CrowdFunding).
% Campaigns collect contributions; when the goal is reached the beneficiary is paid.
% State: Cs = campaigns, StorageLinkedList<Campaign>, list of
%             campaign(Beneficiary, Goal, Amount, Funders)
%        (Funders = list of funder(Who, Amount), the StorageLinkedList of the campaign);
%        the identifier of a campaign is its index in the list (campaigns.get(id)).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/1, new_campaign/5, contribute/7, check_goal_reached/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- fun_eval(arith(true)).                       % arithmetic is computed, as in Java

:- class(campaign(beneficiary, goal, amount, funders)).

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
    N = ~list_size(Cs),                             % campaigns.size()
    new_obj(campaign),                              % new Campaign(beneficiary, goal)
    new_obj(funders),                               % its field funders = new StorageLinkedList<>()
    list_add(campaign(Ben, Goal, 0, []), !Cs),      % campaigns.add(campaign): one new list node
    Id = N.                                         % return campaigns.size() - 1

:- payable(contribute).                             % @Payable: the amount sent is received first

% @FromContract contribute(amount, campaignID)
contribute(Caller, Amount, Id, !Cs, !B) :-
    Camp = ~list_get(Id, Cs),                       % campaigns.get(campaignID): walk
    Funders = Camp[funders],                        % campaign.funders: loads the campaign
    Ben = Camp[beneficiary], Goal = Camp[goal], Amt = Camp[amount],
    new_obj(funder),                                % new Funder(caller(), amount)
    list_add(funder(Caller, Amount), Funders, _),   % campaign.funders.add(funder): one new list node
    Camp := campaign(Ben, Goal, Amt, [funder(Caller, Amount)|Funders]),  % (the list is mutated in place: no field write)
    Amt1 = Amt + Amount,
    Camp[amount] := Amt1,                           % campaign.amount = campaign.amount + amount
    list_set(Id, Camp, !Cs).                        % (the campaign is mutated in place in Java)

% checkGoalReached(campaignID)
check_goal_reached(Id, !Cs, !B, Reached) :-
    Camp = ~list_get(Id, Cs),                       % campaigns.get(campaignID): walk
    Amt = Camp[amount],                             % campaign.amount: loads the campaign
    Goal = Camp[goal],
    Ben = Camp[beneficiary],
    if (Amt < Goal) {                               % compareTo(campaign.amount, campaign.fundingGoal) < 0
        Reached = 0                                 % return false
    } else {
        Camp[amount] := 0,                          % campaign.amount = BigInteger.ZERO
        list_set(Id, Camp, !Cs),                    % (the campaign is mutated in place in Java)
        transfer(this, Ben, Amt, !B),               % campaign.beneficiary.receive(amount)
        Reached = 1                                 % return true
    }.

% --- Test: bene creates a campaign (goal 300); alice contributes 200, bob 150;
% the goal is reached and bene is paid. ---
% Expected: [alice, bob, bene, this] = [800, 850, 350, 0] and Reached = 1.
goal([A, Bo, Be, T, R]) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
    init(Cs0),
    new_campaign(bene, 300, Cs0, Cs1, 0),
    Cs1 == [campaign(bene, 300, 0, [])],            % (the literal below keeps the call types of the analysis typed)
    Cs1b = [campaign(bene, 300, 0, [])],
    contribute(alice, 200, 0, Cs1b, Cs2, B0, B1),
    contribute(bob, 150, 0, Cs2, Cs3, B1, B2),
    check_goal_reached(0, Cs3, _, B2, B3, R),
    balance(alice, B3, A),
    balance(bob, B3, Bo),
    balance(bene, B3, Be),
    balance(this, B3, T).
