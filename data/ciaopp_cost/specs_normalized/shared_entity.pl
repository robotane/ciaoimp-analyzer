% CiaoPP cost spec of shared_entity on build/normalized/shared_entity.pl (the CasLog
% input: the fields of state(Shares, Offers, NextId) are arguments).

:- module(_, [init/5, place_offer/9, accept_offer/11, goal/1],
          [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).

% Shares: list of sh(Address, Number). Offers: list of offer(Id, Seller,
% Price, Shares, Active).
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

% init(Shares, S0, Shares2, Offers2, Next2).
:- entry init(Shares, S0, Sh2, Of2, Nx2) :
    (shares(Shares), var(S0), var(Sh2), var(Of2), var(Nx2)).
% place_offer(Price, N, Caller, Shares, Offers, Next, Shares2, Offers2, Next2).
:- entry place_offer(Price, N, Caller, Sh, Of, Nx, Sh2, Of2, Nx2) :
    (nnegint(Price), nnegint(N), atm(Caller), shares(Sh), offers(Of),
     nnegint(Nx), var(Sh2), var(Of2), var(Nx2)).
% accept_offer(OfferId, Caller, Amount, Shares, Offers, Next, Shares2, Offers2, Next2, B1, B2).
:- entry accept_offer(Id, Caller, Amount, Sh, Of, Nx, Sh2, Of2, Nx2, B1, B2) :
    (nnegint(Id), atm(Caller), nnegint(Amount), shares(Sh), offers(Of),
     nnegint(Nx), var(Sh2), var(Of2), var(Nx2), balances(B1), var(B2)).
:- entry goal(R) : var(R).
