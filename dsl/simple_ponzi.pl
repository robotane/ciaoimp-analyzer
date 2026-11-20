% Simple Ponzi (Java: io.hotmoka.examples.ponzi.SimplePonzi).
% Each new investor must invest more than 110% of the current investment; the
% whole amount goes to the previous investor.
% State: Last (current investor, or null), Amt (current investment).
% B: coin balances, list of bal(Address, Amount).

:- module(_, [init/2, invest/8, goal/1],
          [assertions, nativeprops, regtypes, resdefs, fsyntax, statevars, loops, .(hotmoka_gas)]).

:- entry invest(Caller, Value, Last0, Last, Amt0, Amt, B0, B) :
    (atm(Caller), int(Value), atm(Last0), var(Last), int(Amt0), var(Amt),
     balances(B0), var(B)).

init(null, 0).

:- bigint_cost.                                  % gas of the BigInteger operations by bit length

:- payable(invest).                             % @Payable: the amount sent is received first

% @FromContract invest(amount)
invest(Caller, Value, !Last, !Amt, !B) :-
    big_mul(Amt, 11, Prod),                     % multiply(currentInvestment, _11)
    big_div(Prod, 10, Min),                     % divide(., _10) = minimumInvestment
    require(big_gt(Value, Min)),                % require(compareTo(amount, minimumInvestment) > 0)
    if (Last \== null) {
        Held is Value + Amt,                    % the contract holds the first investment (<= Amt) and Value
        transfer(this, Last, Value, !B),        % currentInvestor.receive(amount)
        big_pay(Value, Held)                    % its BigInteger operations (compareTo, subtract, add)
    },
    Last := Caller,                             % currentInvestor = caller()
    Amt := Value.                               % currentInvestment = amount

% --- Test: alice invests 100, then bob 120 ---
% Expected: alice = 1020, bob = 880, this = 100 (alice's amount stays: no previous investor).
goal([A, Bo, T]) :-
    init(L0, A0),
    invest(alice, 100, L0, L1, A0, A1, [bal(alice, 1000), bal(bob, 1000), bal(this, 0)], B1),
    invest(bob, 120, L1, _, A1, _, B1, B2),
    balance(alice, B2, A),
    balance(bob, B2, Bo),
    balance(this, B2, T).
