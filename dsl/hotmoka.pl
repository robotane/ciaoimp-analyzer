% Hotmoka primitives used by the contracts of dsl/.
%
% Each primitive stands for one operation of the Takamaka runtime that the Java
% contract performs. Their gas is trusted in the package hotmoka_gas.pl; the code
% below only gives them an executable meaning, so the contracts can be run
% (goal/1) as well as analysed.
%
%   coins        transfer/5 (a payment, or the amount a @Payable call receives)
%                balance/3  (read the balance of an account)
%   tree maps    map_get/4, map_put/4, map_remove/3 (StorageTreeMap, StorageTreeSet)
%                map_set/4 (the value of a key already in the map is an object
%                mutated in place by the Java: no tree access, no gas; the Prolog
%                map is rebuilt)
%   linked lists list_add/3 (StorageLinkedList.add: one new node)
%                list_size/2 (StorageLinkedList.size: reads its size field)
%                list_remove_first/3 (StorageLinkedList.removeFirst: reads the
%                head node, writes the fields first, last, size of the list;
%                fails on an empty list)
%                list_get/3 (StorageLinkedList.get(i): reads the size field, then
%                one node per step up to i; index from 0; fails out of range)
%                list_set/4 (the element i is an object mutated in place by the
%                Java: no gas; the Prolog list is rebuilt)
%   arrays       arr_get/3, arr_set/4 (StorageTreeArray of fixed size)
%   big integers ubi_add/3, ubi_sub/3 (UnsignedBigInteger.add/subtract: the
%                result is a new storage object)
%   big integers (cost by size, opt-in) big_add/3, big_sub/3, big_mul/3, big_div/3,
%                big_mod/3, big_gt/2, big_ge/2, big_pay/2: the BigIntegerSupport operations
%                of the Takamaka runtime, whose gas depends on the bit length of the
%                operands (see hotmoka_gas.pl.in). The contracts that do not use them
%                keep the constant cost of the arithmetic.
%   snapshots    snapshot/2 (snapshot() of a Snapshottable map/set: a new view object)
%   bytes        to_array/2 (Bytes32Snapshot.toArray: reads the storage object)
%   objects      load/1   (read a storage object; added by hotmoka_tr.pl: one per
%                         node of a for loop, one per object read with Obj[f])
%                new_obj/1 (create a storage object: the Java new X(...))
%                emit/1   (create and emit an event)
%                store/1  (write a field of the contract or of a storage object;
%                         added by hotmoka_tr.pl)
%
% Maps are lists of kv(Key, Value); an absent key reads as the given default.

:- module(hotmoka, [transfer/5, balance/3,
                    map_get/4, map_put/4, map_remove/3, map_set/4, tmp_get/4, tmp_put/4,
                    list_add/3, list_size/2, list_remove_first/3, list_get/3, list_set/4,
                    arr_get/3, arr_set/4,
                    ubi_add/3, ubi_sub/3,
                    big_add/3, big_sub/3, big_mul/3, big_div/3, big_mod/3, big_gt/2, big_ge/2, big_pay/2,
                    snapshot/2, to_array/2,
                    load/1, new_obj/1, emit/1, store/1], []).

% --- Coins: list of bal(Address, Amount) ---

balance(_, [], 0).
balance(A, [bal(A1, V)|T], R) :-
    ( A == A1 -> R = V ; balance(A, T, R) ).

set_balance(_, _, [], []).
set_balance(A, V, [bal(A1, V1)|T], [bal(A1, V2)|T2]) :-
    ( A == A1 -> V2 = V ; V2 = V1 ),
    set_balance(A, V, T, T2).

transfer(From, To, Amount, B0, B) :-
    balance(From, B0, F),
    F1 is F - Amount,
    set_balance(From, F1, B0, B1),
    balance(To, B1, T),
    T1 is T + Amount,
    set_balance(To, T1, B1, B).

% --- Tree maps: list of kv(Key, Value) ---

map_get(_, [], D, D).
map_get(K, [kv(K1, V)|T], D, R) :-
    ( K == K1 -> R = V ; map_get(K, T, D, R) ).

map_put(K, V, [], [kv(K, V)]).
map_put(K, V, [kv(K1, V1)|T], M) :-
    ( K == K1 -> M = [kv(K, V)|T] ; M = [kv(K1, V1)|M1], map_put(K, V, T, M1) ).

% The key is in the map (the Java mutates its value in place).
map_set(K, V, [kv(K1, V1)|T], M) :-
    ( K == K1 -> M = [kv(K, V)|T] ; M = [kv(K1, V1)|M1], map_set(K, V, T, M1) ).

map_remove(_, [], []).
map_remove(K, [kv(K1, V1)|T], M) :-
    ( K == K1 -> M = T ; M = [kv(K1, V1)|M1], map_remove(K, T, M1) ).

% Temporary maps (never stored): same meaning, other cost.
tmp_get(K, M, D, V) :- map_get(K, M, D, V).
tmp_put(K, V, M0, M) :- map_put(K, V, M0, M).

% --- Linked lists: the new element goes at the end, as StorageLinkedList.add ---

list_add(X, [], [X]).
list_add(X, [Y|T], [Y|T1]) :-
    list_add(X, T, T1).

list_size([], 0).
list_size([_|T], N) :- list_size(T, N0), N is N0 + 1.

list_remove_first(X, [X|T], T).

list_get(0, [X|_], X) :- !.
list_get(I, [_|T], X) :-
    I > 0,
    I1 is I - 1,
    list_get(I1, T, X).

list_set(0, V, [_|T], [V|T]) :- !.
list_set(I, V, [X|T], [X|T1]) :-
    I > 0,
    I1 is I - 1,
    list_set(I1, V, T, T1).

% --- Arrays: list of cells, index from 0 ---

arr_get(0, [X|_], X) :- !.
arr_get(I, [_|T], X) :-
    I1 is I - 1,
    arr_get(I1, T, X).

arr_set(0, V, [_|T], [V|T]) :- !.
arr_set(I, V, [X|T], [X|T1]) :-
    I1 is I - 1,
    arr_set(I1, V, T, T1).

% --- UnsignedBigInteger: integers ---

ubi_add(A, B, C) :- C is A + B.
ubi_sub(A, B, C) :- C is A - B.

% --- BigIntegerSupport: integers, gas by bit length ---
% The result of the operation is the arithmetic itself; big_gt/big_ge are the comparisons
% (they fail when false); big_pay(Paid, Held) is the gas of the three BigInteger operations of
% Contract.pay (compareTo, subtract, add) and has no effect on the Prolog state (the money moves
% with transfer/5).

big_add(A, B, C) :- C is A + B.
big_sub(A, B, C) :- C is A - B.
big_mul(A, B, C) :- C is A * B.
big_div(A, B, C) :- C is A // B.
big_mod(A, B, C) :- C is A mod B.
big_gt(A, B) :- A > B.
big_ge(A, B) :- A >= B.
big_pay(_, _).

% --- Snapshot (the view is not modelled) and bytes (the term itself) ---

snapshot(_, snapshot).
to_array(X, X).

% --- Objects and events: no effect on the state of the Prolog model ---

load(_).
new_obj(_).
emit(_).
store(_).
