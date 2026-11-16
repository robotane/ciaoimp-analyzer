% CiaoPP cost spec of simple_shared_entity (build/executable/simple_shared_entity.pl): shares of an
% entity, offers to sell shares, with get_share/3 as a table lookup.

:- module(_, [init/3, place_offer/5, accept/7, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% State: state(Shares, Offers, NextId); Shares is a list of sh(Address,
% Number), Offers a list of offer(Id, Seller, Price, Shares, Active).
:- regtype shares/1.
shares([]).
shares([X|T]) :- share(X), shares(T).

:- regtype share/1.
share(sh(A, N)) :- atm(A), nnegint(N).

:- regtype offers/1.
offers([]).
offers([X|T]) :- offer(X), offers(T).

:- regtype offer/1.
offer(offer(Id, Seller, Price, N, Active)) :-
    nnegint(Id), atm(Seller), nnegint(Price), nnegint(N), nnegint(Active).

:- regtype entstate/1.
entstate(state(Shares, Offers, Next)) :- shares(Shares), offers(Offers), nnegint(Next).

% get_share/3 reads one entry per element of the share table (its loop does
% not stop at the first match): cost length(Shares), as get_bal/3.
:- trust pred get_share(Addr, Shares, N)
   + ( not_fails, is_det, cost(lb, gas, length(Shares)), cost(ub, gas, length(Shares)) ).

:- entry init(Shares, S0, S) : (shares(Shares), var(S0), var(S)).
% inf upper bound of the operations that scan the offers: the offer list is
% inside the state, which the analysis measures by term size only.
:- entry place_offer(Price, N, Caller, S1, S2) :
    (nnegint(Price), nnegint(N), atm(Caller), entstate(S1), var(S2)).
:- entry accept(OfferId, Caller, Amount, S1, S2, B1, B2) :
    (nnegint(OfferId), atm(Caller), nnegint(Amount), entstate(S1), var(S2),
     balances(B1), var(B2)).
:- entry goal(R) : var(R).
