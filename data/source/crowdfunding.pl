% Crowdfunding : les contributeurs envoient des ETH à des campagnes.
% Quand l'objectif est atteint, le bénéficiaire reçoit les fonds.
% Etat : state(Campaigns)
:- module(_, [goal/1], [fsyntax, statevars, hiord, loops]).
:- use_module(library(lists), [length/2]).
:- fun_eval arith(true).

% --- Infrastructure Blockchain ---

:- fun_eval get_bal/2.
get_bal(Addr, B) := Result :-
    Result := 0,
    for (Entry in list(B)) {
        Entry = bal(A, Val),
        if (A == Addr) { Result := Val }
    }.

set_bal(Addr, NewVal, !B) :-
    Acc := [],
    for (Entry in list(B)) {
        Entry = bal(A, V),
        if (A == Addr) {
            Acc := [bal(Addr, NewVal) | Acc]
        } else {
            Acc := [bal(A, V) | Acc]
        }
    },
    B := Acc.

transfer(From, To, Amount, !B) :-
    FB is ~get_bal(From, B),
    NewFB is FB - Amount,
    set_bal(From, NewFB, !B),
    TB is ~get_bal(To, B),
    NewTB is TB + Amount,
    set_bal(To, NewTB, !B).

% --- Contrat ---

init(!S) :-
    S := state([]).

new_campaign(Beneficiary, Goal, Id, !S) :-
    state(Campaigns) = S,
    length(Campaigns, Id),
    NewCampaigns := [campaign(Id, Beneficiary, Goal, 0, []) | Campaigns],
    S := state(NewCampaigns).

contribute(Caller, Amount, CampaignId, !S, !B) :-
    state(Campaigns) = S,
    transfer(Caller, this, Amount, !B),
    NewCampaigns := [],
    for (C in list(Campaigns)) {
        C = campaign(Id, Ben, Goal, CurrentAmt, Funders),
        if (Id == CampaignId) {
            NewAmt is CurrentAmt + Amount,
            NewCampaigns := [campaign(Id, Ben, Goal, NewAmt, [funder(Caller, Amount) | Funders]) | NewCampaigns]
        } else {
            NewCampaigns := [C | NewCampaigns]
        }
    },
    S := state(NewCampaigns).

check_goal_reached(CampaignId, Reached, !S, !B) :-
    state(Campaigns) = S,
    NewCampaigns := [],
    Reached := 0,
    for (C in list(Campaigns)) {
        C = campaign(Id, Ben, Goal, CurrentAmt, Funders),
        if (Id == CampaignId) {
            if (CurrentAmt >= Goal) {
                transfer(this, Ben, CurrentAmt, !B),
                NewCampaigns := [campaign(Id, Ben, Goal, 0, Funders) | NewCampaigns],
                Reached := 1
            } else {
                NewCampaigns := [C | NewCampaigns]
            }
        } else {
            NewCampaigns := [C | NewCampaigns]
        }
    },
    S := state(NewCampaigns).

% --- Test ---
% Scenario : bene cree une campagne (objectif=300).
%   alice contribue 200, bob contribue 150 -> objectif atteint.
%   check_goal_reached : bene recoit 350.
% Attendu : alice=800, bob=850, bene=350, this=0

goal(Results) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)],
    init(_, S1),
    new_campaign(bene, 300, _, S1, S2),
    contribute(alice, 200, 0, S2, S3, B0, B1),
    contribute(bob,   150, 0, S3, S4, B1, B2),
    check_goal_reached(0, _, S4, _, B2, B3),
    AliceBal is ~get_bal(alice, B3),
    BobBal   is ~get_bal(bob,   B3),
    BeneBal  is ~get_bal(bene,  B3),
    ThisBal  is ~get_bal(this,  B3),
    Results = [AliceBal, BobBal, BeneBal, ThisBal].
