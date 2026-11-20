
% primitives (hotmoka.pl) in the form accepted by CasLog: cuts instead of ->,
% hand-written mode/measure.
:- mode(balance/3, [+, +, -]).
:- measure(balance/3, [void, length, int]).
:- mode(set_balance/4, [+, +, +, -]).
:- measure(set_balance/4, [void, int, length, length]).
:- mode(transfer/5, [+, +, +, +, -]).
:- measure(transfer/5, [void, void, int, length, length]).
:- mode(map_get/4, [+, +, +, -]).
:- measure(map_get/4, [void, length, void, void]).
:- mode(map_put/4, [+, +, +, -]).
:- measure(map_put/4, [void, void, length, length]).
:- mode(map_set/4, [+, +, +, -]).
:- measure(map_set/4, [void, void, length, length]).
:- mode(map_remove/3, [+, +, -]).
:- measure(map_remove/3, [void, length, length]).
:- mode(tmp_get/4, [+, +, +, -]).
:- measure(tmp_get/4, [void, length, void, void]).
:- mode(tmp_put/4, [+, +, +, -]).
:- measure(tmp_put/4, [void, void, length, length]).
:- mode(list_add/3, [+, +, -]).
:- measure(list_add/3, [void, length, length]).
:- mode(list_size/2, [+, -]).
:- measure(list_size/2, [length, int]).
:- mode(list_remove_first/3, [-, +, -]).
:- measure(list_remove_first/3, [void, length, length]).
:- mode(list_get/3, [+, +, -]).
:- measure(list_get/3, [void, length, void]).
:- mode(list_set/4, [+, +, +, -]).
:- measure(list_set/4, [void, void, length, length]).
:- mode(ubi_add/3, [+, +, -]).
:- measure(ubi_add/3, [int, int, int]).
:- mode(ubi_sub/3, [+, +, -]).
:- measure(ubi_sub/3, [int, int, int]).
:- mode(big_add/3, [+, +, -]).
:- measure(big_add/3, [int, int, int]).
:- mode(big_sub/3, [+, +, -]).
:- measure(big_sub/3, [int, int, int]).
:- mode(big_mul/3, [+, +, -]).
:- measure(big_mul/3, [int, int, int]).
:- mode(big_div/3, [+, +, -]).
:- measure(big_div/3, [int, int, int]).
:- mode(big_mod/3, [+, +, -]).
:- measure(big_mod/3, [int, int, int]).
:- mode(big_gt/2, [+, +]).
:- measure(big_gt/2, [int, int]).
:- mode(big_ge/2, [+, +]).
:- measure(big_ge/2, [int, int]).
:- mode(big_pay/2, [+, +]).
:- measure(big_pay/2, [int, int]).
:- mode(snapshot/2, [+, -]).
:- measure(snapshot/2, [void, void]).
:- mode(to_array/2, [+, -]).
:- measure(to_array/2, [void, void]).
:- mode(arr_get/3, [+, +, -]).
:- measure(arr_get/3, [void, length, void]).
:- mode(arr_set/4, [+, +, +, -]).
:- measure(arr_set/4, [void, void, length, length]).
:- mode(load/1, [+]).
:- measure(load/1, [void]).
:- mode(new_obj/1, [+]).
:- measure(new_obj/1, [void]).
:- mode(emit/1, [+]).
:- measure(emit/1, [void]).
:- mode(store/1, [+]).
:- measure(store/1, [void]).
:- mode(atom/1, [+]).
:- measure(atom/1, [void]).
:- mode(integer/1, [+]).
:- measure(integer/1, [void]).

balance(_, [], 0).
balance(A, [bal(A1, V)|_], V) :- A == A1, !.
balance(A, [_|T], R) :- balance(A, T, R).
set_balance(_, _, [], []).
set_balance(A, V, [bal(A1, _)|T], [bal(A1, V)|T2]) :- A == A1, !, set_balance(A, V, T, T2).
set_balance(A, V, [X|T], [X|T2]) :- set_balance(A, V, T, T2).
transfer(From, To, Amount, B0, B) :-
    balance(From, B0, F), F1 is F - Amount, set_balance(From, F1, B0, B1),
    balance(To, B1, T), T1 is T + Amount, set_balance(To, T1, B1, B).
map_get(_, [], D, D).
map_get(K, [kv(K1, V)|_], _, V) :- K == K1, !.
map_get(K, [_|T], D, R) :- map_get(K, T, D, R).
map_put(K, V, [], [kv(K, V)]).
map_put(K, V, [kv(K1, _)|T], [kv(K, V)|T]) :- K == K1, !.
map_put(K, V, [X|T], [X|M1]) :- map_put(K, V, T, M1).
map_set(K, V, [kv(K1, _)|T], [kv(K, V)|T]) :- K == K1, !.
map_set(K, V, [X|T], [X|M1]) :- map_set(K, V, T, M1).
map_remove(_, [], []).
map_remove(K, [kv(K1, _)|T], T) :- K == K1, !.
map_remove(K, [X|T], [X|M1]) :- map_remove(K, T, M1).
tmp_get(K, M, D, V) :- map_get(K, M, D, V).
tmp_put(K, V, M0, M) :- map_put(K, V, M0, M).
list_add(X, [], [X]).
list_add(X, [Y|T], [Y|T1]) :- list_add(X, T, T1).
list_size([], 0).
list_size([_|T], N) :- list_size(T, N0), N is N0 + 1.
list_remove_first(X, [X|T], T).
list_get(I, [X|_], X) :- I =:= 0, !.
list_get(I, [_|T], X) :- I1 is I - 1, list_get(I1, T, X).
list_set(I, V, [_|T], [V|T]) :- I =:= 0, !.
list_set(I, V, [X|T], [X|T1]) :- I1 is I - 1, list_set(I1, V, T, T1).
ubi_add(A, B, C) :- C is A + B.
ubi_sub(A, B, C) :- C is A - B.
% BigIntegerSupport (opt-in primitives big_*): the arithmetic itself, one step like `is` and the
% comparisons. CasLog cannot count the bit length of the operands (log2 of their value): its size
% analysis has no model of N//2 (a halving loop `bl(N) :- N > 1, N1 is N//2, bl(N1)` gets [inf]),
% so the log(amount) term of hotmoka_gas.pl.in does not appear in the CasLog function: the
% class is that of the constant-cost model.
big_add(A, B, C) :- C is A + B.
big_sub(A, B, C) :- C is A - B.
big_mul(A, B, C) :- C is A * B.
% (a quotient by a variable crashes the size analysis of CasLog, [$ evaluable in >/2]: the
% quotient is bounded by the dividend A, the remainder by the divisor B)
big_div(A, _, C) :- C is A.
big_mod(_, B, C) :- C is B.
big_gt(A, B) :- A > B.
big_ge(A, B) :- A >= B.
big_pay(_, _).
snapshot(_, snapshot).
to_array(X, X).
arr_get(I, [X|_], X) :- I =:= 0, !.
arr_get(I, [_|T], X) :- I1 is I - 1, arr_get(I1, T, X).
arr_set(I, V, [_|T], [V|T]) :- I =:= 0, !.
arr_set(I, V, [X|T], [X|T1]) :- I1 is I - 1, arr_set(I1, V, T, T1).
load(_).
new_obj(_).
emit(_).
store(_).
% (arrays, list_get/list_set: the test I =:= 0 instead of the constant 0, so that CasLog measures the list)
% type tests of the helpers (paper_fields...): one step each
atom(_).
integer(_).

