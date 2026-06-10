% ERC20 avec mint et burn (example_coin).
% Pas de blockchain ETH : les soldes sont des tokens internes (tb).
% Etat : state(Name, Symbol, Owner, TotalSupply, TokenBalances)
:- module(_, [goal/1], [fsyntax, statevars, hiord, loops]).
:- fun_eval arith(true).

% --- Helpers ---

get_tok_bal(Addr, TB, Bal) :-
    Bal := 0,
    for (Entry in list(TB)) {
        Entry = tb(A, Amt),
        if (A == Addr, Bal == 0) { Bal := Amt }
    }.

% --- Contrat ---

init(Name, Symbol, Caller, !S) :-
    S := state(Name, Symbol, Caller, 1000000, [tb(Caller, 1000000)]).

token_transfer(To, Amount, Caller, !S) :-
    state(Name, Symbol, Owner, TotalSupply, TB) = S,
    get_tok_bal(Caller, TB, CallerBal),
    if (CallerBal >= Amount) {
        NewCallerBal is CallerBal - Amount,
        TB1 := [tb(Caller, NewCallerBal) | TB],
        get_tok_bal(To, TB1, ToBal),
        NewToBal is ToBal + Amount,
        TB2 := [tb(To, NewToBal) | TB1],
        S := state(Name, Symbol, Owner, TotalSupply, TB2)
    }.

mint(Account, Amount, Caller, !S) :-
    state(Name, Symbol, Owner, TotalSupply, TB) = S,
    if (Caller == Owner) {
        get_tok_bal(Account, TB, AccBal),
        NewAccBal is AccBal + Amount,
        TB1 := [tb(Account, NewAccBal) | TB],
        NewSupply is TotalSupply + Amount,
        S := state(Name, Symbol, Owner, NewSupply, TB1)
    }.

burn(Account, Amount, Caller, !S) :-
    state(Name, Symbol, Owner, TotalSupply, TB) = S,
    get_tok_bal(Account, TB, AccBal),
    if (Caller == Owner, AccBal >= Amount) {
        NewAccBal is AccBal - Amount,
        TB1 := [tb(Account, NewAccBal) | TB],
        NewSupply is TotalSupply - Amount,
        S := state(Name, Symbol, Owner, NewSupply, TB1)
    }.

% --- Test ---
% Scenario : alice est owner (1_000_000 tokens).
%   alice transfere 500 vers bob.
%   alice mint 200 pour charlie.
%   alice burn 100 de bob.
% Attendu : alice=999300, bob=400, charlie=200, total=1000100

goal(Results) :-
    init(mycoin, mc, alice, _, S1),
    token_transfer(bob, 500, alice, S1, S2),
    mint(charlie, 200, alice, S2, S3),
    burn(bob, 100, alice, S3, S4),
    S4 = state(_, _, _, Total, TB),
    get_tok_bal(alice,   TB, A),
    get_tok_bal(bob,     TB, B),
    get_tok_bal(charlie, TB, C),
    Results = [A, B, C, Total].
