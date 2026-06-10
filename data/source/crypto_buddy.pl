% Token ERC20 avec approbations (crypto_buddy).
% Pas de blockchain ETH : les soldes sont des tokens internes (tb/al).
% Etat : state(Symbol, TokenBalances, Allowances)
:- module(_, [goal/1], [fsyntax, statevars, hiord, loops]).
:- fun_eval arith(true).

% --- Helpers tokens ---

get_tok_bal(Addr, TB, Bal) :-
    Bal := 0,
    for (Entry in list(TB)) {
        Entry = tb(A, Amt),
        if (A == Addr, Bal == 0) { Bal := Amt }
    }.

get_allow(Owner, Spender, AL, Amt) :-
    Amt := 0,
    for (Entry in list(AL)) {
        Entry = al(O, Sp, V),
        if (O == Owner, Sp == Spender, Amt == 0) { Amt := V }
    }.

% --- Contrat ---

init(Symbol, Caller, !S) :-
    S := state(Symbol, [tb(Caller, 1000)], []).

approve(Spender, Amount, Caller, !S) :-
    state(Symbol, TB, AL) = S,
    AL1 := [al(Caller, Spender, Amount) | AL],
    S := state(Symbol, TB, AL1).

transferFrom(Owner, To, Amount, Caller, !S) :-
    state(Symbol, TB, AL) = S,
    get_allow(Owner, Caller, AL, Allowed),
    get_tok_bal(Owner, TB, OwnBal),
    if (Allowed >= Amount, OwnBal >= Amount) {
        NewAllowed is Allowed - Amount,
        AL1 := [al(Owner, Caller, NewAllowed) | AL],
        NewOwnBal is OwnBal - Amount,
        TB1 := [tb(Owner, NewOwnBal) | TB],
        get_tok_bal(To, TB1, ToBal),
        NewToBal is ToBal + Amount,
        TB2 := [tb(To, NewToBal) | TB1],
        S := state(Symbol, TB2, AL1)
    }.

token_transfer(To, Amount, Caller, !S) :-
    state(Symbol, TB, AL) = S,
    get_tok_bal(Caller, TB, CallerBal),
    if (CallerBal >= Amount) {
        NewCallerBal is CallerBal - Amount,
        TB1 := [tb(Caller, NewCallerBal) | TB],
        get_tok_bal(To, TB1, ToBal),
        NewToBal is ToBal + Amount,
        TB2 := [tb(To, NewToBal) | TB1],
        S := state(Symbol, TB2, AL)
    }.

% --- Test ---
% Scenario : alice (owner, 1000 tokens) approuve bob pour 300,
%            bob transfere 200 tokens d'alice vers charlie.
%            alice ensuiite transfere directement 100 vers dave.
% Attendu tokens : alice=700, bob=0, charlie=200, dave=100

goal(Results) :-
    init(btk, alice, _, S1),
    approve(bob, 300, alice, S1, S2),
    transferFrom(alice, charlie, 200, bob, S2, S3),
    token_transfer(dave, 100, alice, S3, _S4),
    _S4 = state(_, TB, _),
    get_tok_bal(alice,   TB, A),
    get_tok_bal(bob,     TB, B),
    get_tok_bal(charlie, TB, C),
    get_tok_bal(dave,    TB, D),
    Results = [A, B, C, D].
