% Hotmoka primitives used by the contracts of data/contracts_hotmoka.
%
% Each primitive stands for one operation of the Takamaka runtime that the Java
% contract performs. Their gas is trusted in the package hotmoka_gas.pl; the code
% below only gives them an executable meaning, so the contracts can be run
% (goal/1) as well as analysed.
%
%   coins        transfer/5 (a payment, or the amount a @Payable call receives)
%                balance/3  (read the balance of an account)
%   tree maps    map_get/4, map_put/4, map_remove/3 (StorageTreeMap, StorageTreeSet)
%   linked lists list_add/3 (StorageLinkedList.add: one new node)
%   arrays       arr_get/3, arr_set/4 (StorageTreeArray of fixed size)
%   objects      load/1   (read a storage object while scanning a collection)
%                new_obj/1 (create a storage object)
%                emit/1   (create and emit an event)
%                store/1  (write a field of the contract or of a storage object)
%
% Maps are lists of kv(Key, Value); an absent key reads as the given default.

:- module(hotmoka, [transfer/5, balance/3,
                    map_get/4, map_put/4, map_remove/3,
                    list_add/3, arr_get/3, arr_set/4,
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

map_remove(_, [], []).
map_remove(K, [kv(K1, V1)|T], M) :-
    ( K == K1 -> M = T ; M = [kv(K1, V1)|M1], map_remove(K, T, M1) ).

% --- Linked lists: the new element goes at the end, as StorageLinkedList.add ---

list_add(X, [], [X]).
list_add(X, [Y|T], [Y|T1]) :-
    list_add(X, T, T1).

% --- Arrays: list of cells, index from 0 ---

arr_get(0, [X|_], X) :- !.
arr_get(I, [_|T], X) :-
    I1 is I - 1,
    arr_get(I1, T, X).

arr_set(0, V, [_|T], [V|T]) :- !.
arr_set(I, V, [X|T], [X|T1]) :-
    I1 is I - 1,
    arr_set(I1, V, T, T1).

% --- Objects and events: no effect on the state of the Prolog model ---

load(_).
new_obj(_).
emit(_).
store(_).
