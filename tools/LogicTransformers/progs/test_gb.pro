get_balance(_, [], 0).
get_balance(User, [bal(User, B)|_], B).
get_balance(User, [_|T], B) :- get_balance(User, T, B).

goal(B) :-
    Bals = [bal(alice, 1000), bal(bob, 1000)],
    get_balance(alice, Bals, B).
