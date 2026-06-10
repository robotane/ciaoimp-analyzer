% Scrutin (vote) : un président crée un scrutin avec des propositions.
% Accord du droit de vote, délégation, vote direct. Le gagnant est la
% proposition avec le plus de votes.
% Etat : state(President, ListePropositions, Bulletins)
:- module(_, [goal/1], [fsyntax, statevars, hiord, loops]).
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



% --- Helpers ---

:- fun_eval get_paper/2.
get_paper(V, Papers) := P :-
    P := 0,
    for (Entry in list(Papers)) {
        Entry = paper(Voter, W, HV, Del, Prop),
        if (Voter == V) {
            P := paper(Voter, W, HV, Del, Prop)
        }
    }.

:- fun_eval set_paper/3.
set_paper(V, NewP, Papers) := Res :-
    Found := 0,
    Acc := [],
    for (Entry in list(Papers)) {
        Entry = paper(Voter, _, _, _, _),
        if (Voter == V) {
            Acc := [NewP | Acc],
            Found := 1
        } else {
            Acc := [Entry | Acc]
        }
    },
    if (Found == 0) { Acc := [NewP | Acc] },
    Res = Acc.

% --- Contrat ---

init(ProposalNames, Caller, S_out) :-
    Papers = [paper(Caller, 1, 0, 'null', -1)],
    init_props(ProposalNames, Props),
    S_out = state(Caller, Props, Papers).

init_props([], []).
init_props([N|T], [proposal(N, 0) | RT]) :- init_props(T, RT).

give_right(Voter, Caller, S_in, S_out) :-
    state(Chair, Props, Papers) = S_in,
    if (Caller == Chair) {
        Paper := ~get_paper(Voter, Papers),
        if (Paper == 0) {
            Papers1 := ~set_paper(Voter, paper(Voter, 1, 0, 'null', -1), Papers),
            S_out = state(Chair, Props, Papers1)
        } else { S_out = S_in }
    } else { S_out = S_in }.

delegate(To, Caller, S_in, S_out) :-
    state(Chair, Props, Papers) = S_in,
    Paper := ~get_paper(Caller, Papers),
    if (Paper \== 0) {
        Paper = paper(Caller, W, 0, _, _),
        if (To \== Caller) {
            find_final_delegate(To, Caller, Papers, FinalTo),
            PaperTo := ~get_paper(FinalTo, Papers),
            if (PaperTo \== 0) {
                Papers1 := ~set_paper(Caller, paper(Caller, W, 1, FinalTo, -1), Papers),
                PaperTo = paper(FinalTo, WTo, HVTo, DTo, PropTo),
                if (HVTo == 1) {
                    if (PropTo \== -1) {
                        add_votes_to_prop(PropTo, W, 1, Props, NewProps),
                        S_out = state(Chair, NewProps, Papers1)
                    } else { S_out = state(Chair, Props, Papers1) }
                } else {
                    NewWTo is WTo + W,
                    Papers2 := ~set_paper(FinalTo, paper(FinalTo, NewWTo, 0, DTo, -1), Papers1),
                    S_out = state(Chair, Props, Papers2)
                }
            } else { S_out = S_in }
        } else { S_out = S_in }
    } else { S_out = S_in }.

find_final_delegate(Current, Payer, Papers, Final) :-
    Paper := ~get_paper(Current, Papers),
    if (Paper \== 0) {
        Paper = paper(_, _, _, Del, _),
        if (Del \== 'null', Del \== Payer) { find_final_delegate(Del, Payer, Papers, Final) }
        else { Final = Current }
    } else { Final = Current }.

vote(PropId, Caller, S_in, S_out) :-
    state(Chair, Props, Papers) = S_in,
    Paper := ~get_paper(Caller, Papers),
    if (Paper \== 0) {
        Paper = paper(Caller, W, 0, _, _),
        Papers1 := ~set_paper(Caller, paper(Caller, W, 1, 'null', PropId), Papers),
        add_votes_to_prop(PropId, W, 1, Props, NewProps),
        S_out = state(Chair, NewProps, Papers1)
    } else { S_out = S_in }.

add_votes_to_prop(_, _, _, [], []).
add_votes_to_prop(PropId, Weight, Idx, [proposal(N, C) | Rest], Res) :-
    if (Idx == PropId) {
        add_votes_to_prop(PropId, Weight, Idx + 1, Rest, RestOut),
        NewC is C + Weight,
        Res = [proposal(N, NewC) | RestOut]
    } else {
        add_votes_to_prop(PropId, Weight, Idx + 1, Rest, RestOut),
        Res = [proposal(N, C) | RestOut]
    }.

best_proposal([], BestName, _, BestName).
best_proposal([proposal(N, Cnt) | Rest], BestName, BestCount, Res) :-
    if (Cnt > BestCount) { best_proposal(Rest, N, Cnt, Res) }
    else { best_proposal(Rest, BestName, BestCount, Res) }.

winner(WinnerName, S) :-
    state(_, Props, _) = S,
    best_proposal(Props, 'aucun', -1, WinnerName).

% --- Test ---
% Scenario : admin cree [prop_a, prop_b, prop_c].
%   alice, bob, charlie recoivent le droit de vote.
%   alice vote prop_a (1).
%   bob delegue a alice (alice=poids 2).
%   charlie vote prop_b (2).
%   admin vote prop_a (1) -> prop_a=3 votes, prop_b=1.
% Attendu : gagnant = prop_a

goal(Results) :-
    init([prop_a, prop_b, prop_c], admin, S1),
    give_right(alice,   admin, S1, S2),
    give_right(bob,     admin, S2, S3),
    give_right(charlie, admin, S3, S4),
    vote(1, alice, S4, S5),
    delegate(alice, bob, S5, S6),
    vote(2, charlie, S6, S7),
    vote(1, admin, S7, S8),
    winner(W, S8),
    Results = [W].
