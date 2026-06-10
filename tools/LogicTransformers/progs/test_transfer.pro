get_balance(_, [], 0).
get_balance(User, [bal(User, B)|_], B) :- !.
get_balance(User, [_|T], B) :- get_balance(User, T, B).

set_balance(User, Amount, [], [bal(User, Amount)]).
set_balance(User, Amount, [bal(User, _)|T], [bal(User, Amount)|T]) :- !.
set_balance(User, Amount, [bal(U, B)|T], [bal(U, B)|T2]) :-
    set_balance(User, Amount, T, T2).

transfer_bal(From, To, Amount, BalsIn, BalsOut) :-
    get_balance(From, BalsIn, FB),
    NewFB is FB - Amount,
    set_balance(From, NewFB, BalsIn, BalsMid),
    get_balance(To, BalsMid, TB),
    NewTB is TB + Amount,
    set_balance(To, NewTB, BalsMid, BalsOut).

goal(BalsOut) :-
    B0 = [bal(alice, 1000), bal(bob, 1000), bal(this, 0)],
    transfer_bal(alice, this, 100, B0, BalsOut).
