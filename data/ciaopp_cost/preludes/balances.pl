% Gas cost model shared by the contracts that keep a balance table
% (a list of bal(Address, Amount)) and use get_bal/3, set_bal/4 and
% transfer/5.
%
% Taken from the CiaoPP cost tests of the IMDEA (interreg-imdea,
% benchmarks/ciaopp_cost_tests/october2026/simple_pyramid.pl): only the
% blockchain primitives cost gas, one unit per entry of the balance table
% they scan; everything else is free.

:- resource gas.

:- head_cost(ub, gas, 0).
:- head_cost(lb, gas, 0).

:- literal_cost(ub, gas, 0).
:- literal_cost(lb, gas, 0).

:- trust_default + cost(ub, gas, 0).

:- regtype balances/1.
balances([]).
balances([X|T]) :-
    balpair(X),
    balances(T).

:- regtype balpair/1.
balpair( bal(A, B) ) :-
    atm(A), int(B).

:- trust pred get_bal(Addr, B, Result)
   + ( not_fails, is_det, cost(lb, gas, length(B)), cost(ub, gas, length(B)) ).
:- trust pred set_bal(Addr, NewVal, B_in, B_out)
   => ( balances(B_out), size(lb, B_out, length(B_in)), size(ub, B_out, length(B_in)) )
   + ( not_fails, is_det, cost(lb, gas, length(B_in)), cost(ub, gas, length(B_in)) ).
:- trust pred transfer(From, To, Amount, B_in, B_out)
   => ( balances(B_out), size(lb, B_out, length(B_in)), size(ub, B_out, length(B_in)) )
   + ( not_fails, is_det, cost(lb, gas, 4*length(B_in)), cost(ub, gas, 4*length(B_in)) ).
