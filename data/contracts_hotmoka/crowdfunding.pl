% Crowdfunding (Java: io.hotmoka.examples.crowdfunding.CrowdFunding).
% Campaigns collect contributions; when the goal is reached the beneficiary is paid.
% State: Cs = campaigns, StorageLinkedList<Campaign>, list of
%             campaign(Id, Beneficiary, Goal, Amount, Funders)
%        (Id = the index of the campaign in the list; it only serves to stop the walk
%        of campaigns.get(id) without a numeric counter, it is not a field of Campaign)
%        (Funders = list of funder(Who, Amount), the StorageLinkedList of the campaign);
%        N = the size field of the list of campaigns.
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/2, new_campaign/7, contribute/7, check_goal_reached/6, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, .(hotmoka_gas)]).

:- regtype campaigns/1.
campaigns([]).
campaigns([C|T]) :- campaign(C), campaigns(T).
:- regtype campaign/1.
campaign(campaign(Id, Ben, Goal, Amount, Funders)) :- int(Id), atm(Ben), int(Goal), int(Amount), funders(Funders).
:- regtype funders/1.
funders([]).
funders([funder(W, A)|T]) :- atm(W), int(A), funders(T).

:- entry new_campaign(Ben, Goal, Cs0, Cs, N0, N, Id) :
    (atm(Ben), int(Goal), campaigns(Cs0), var(Cs), int(N0), var(N), var(Id)).
:- entry contribute(Caller, Amount, Id, Cs0, Cs, B0, B) :
    (atm(Caller), int(Amount), int(Id), campaigns(Cs0), var(Cs), balances(B0), var(B)).
:- entry check_goal_reached(Id, Cs0, Cs, B0, B, Reached) :
    (int(Id), campaigns(Cs0), var(Cs), balances(B0), var(B), var(Reached)).

init([], 0).

% newCampaign(beneficiary, goal)
new_campaign(Ben, Goal, !Cs, !N, Id) :-
    new_obj(campaign),                              % new Campaign(beneficiary, goal)
    new_obj(funders),                               % its field funders = new StorageLinkedList<>()
    list_add(campaign(N, Ben, Goal, 0, []), !Cs),   % campaigns.add(campaign): one new list node
    Id = N,                                         % return campaigns.size() - 1
    N := N + 1.

% @Payable @FromContract contribute(amount, campaignID)
contribute(Caller, Amount, Id, !Cs, !B) :-
    transfer(Caller, this, Amount, !B),             % the amount sent with the call
    nth_campaign(Id, Cs, Camp),  % campaigns.get(campaignID): walk
    Camp = campaign(_, Ben, Goal, Amt, Funders),
    new_obj(funder),                                % new Funder(caller(), amount)
    list_add(funder(Caller, Amount), Funders, _),             % campaign.funders.add(funder): one new list node
    Funders1 = [funder(Caller, Amount)|Funders],              % (its content in the state: the order is not observable)
    Amt1 is Amt + Amount,                           % campaign.amount = campaign.amount + amount
    replace_nth(Id, campaign(Id, Ben, Goal, Amt1, Funders1), !Cs).   % (the campaign is mutated in place in Java)

% checkGoalReached(campaignID)
check_goal_reached(Id, !Cs, !B, Reached) :-
    nth_campaign(Id, Cs, Camp),  % campaigns.get(campaignID): walk
    Camp = campaign(_, Ben, Goal, Amt, Funders),
    ( Amt < Goal ->                                 % compareTo(campaign.amount, campaign.fundingGoal) < 0
        Reached = 0                                 % return false
    ;
        replace_nth(Id, campaign(Id, Ben, Goal, 0, Funders), !Cs),   % campaign.amount = ZERO
        transfer(this, Ben, Amt, !B),               % campaign.beneficiary.receive(amount)
        Reached = 1                                 % return true
    ).

% StorageLinkedList.get(i): the walk loads one node per step, up to the index.
nth_campaign(Id0, [C|_], X) :-
    C = campaign(Id, _, _, _, _),
    Id =:= Id0,
    load(C),
    X = C.
nth_campaign(Id0, [C|T], X) :-
    C = campaign(Id, _, _, _, _),
    Id =\= Id0,
    load(C),
    nth_campaign(Id0, T, X).

% The functional update of the campaign Id0 (no cost of its own besides the steps).
replace_nth(Id0, V, [C|T], [V|T]) :-
    C = campaign(Id, _, _, _, _),
    Id =:= Id0.
replace_nth(Id0, V, [C|T], [C|T1]) :-
    C = campaign(Id, _, _, _, _),
    Id =\= Id0,
    replace_nth(Id0, V, T, T1).

% --- Test: bene creates a campaign (goal 300); alice contributes 200, bob 150;
% the goal is reached and bene is paid. ---
% Expected: [alice, bob, bene, this] = [800, 850, 350, 0] and Reached = 1.
goal([A, Bo, Be, T, R]) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
    init(Cs0, N0),
    new_campaign(bene, 300, Cs0, Cs1, N0, _, 0),
    Cs1 == [campaign(0, bene, 300, 0, [])],         % (the literal below keeps the call types of the analysis typed)
    Cs1b = [campaign(0, bene, 300, 0, [])],
    contribute(alice, 200, 0, Cs1b, Cs2, B0, B1),
    contribute(bob, 150, 0, Cs2, Cs3, B1, B2),
    check_goal_reached(0, Cs3, _, B2, B3, R),
    balance(alice, B3, A),
    balance(bob, B3, Bo),
    balance(bene, B3, Be),
    balance(this, B3, T).
