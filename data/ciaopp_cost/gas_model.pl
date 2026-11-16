% Gas cost model of the contracts: the one file to change to change it.
%
% A Ciao package: every contract analyzed by the pipeline (stage
% ciaopp_cost) loads it in its module declaration,
%     :- module(_, [...], [assertions, nativeprops, regtypes, resdefs, .(gas_model)]).
% It declares the resource gas and the default costs, the types of the
% tables, and imports the primitives (blockchain.pl) with their trusted gas
% costs. Same layout as ciaopp_cost/examples/resources_blockchain/carthage.pl.
%
% Model of the CiaoPP cost tests of the IMDEA (interreg-imdea,
% benchmarks/ciaopp_cost_tests): only the blockchain primitives cost gas,
% one unit per table entry they scan; everything else is free.

:- package(gas_model).
:- use_package(assertions).
:- use_package(nativeprops).
:- use_package(regtypes).
:- use_package(resdefs).

:- use_module(blockchain).

% --- Resource and default costs ---

:- resource gas.

:- head_cost(ub, gas, 0).
:- head_cost(lb, gas, 0).

:- literal_cost(ub, gas, 0).
:- literal_cost(lb, gas, 0).

:- trust_default + cost(ub, gas, 0).

% --- Tables (types of the arguments of the primitives) ---

% Coin balances: bal(Address, Amount).
:- regtype balances/1.
balances([]).
balances([X|T]) :- balpair(X), balances(T).

:- regtype balpair/1.
balpair(bal(A, B)) :- atm(A), int(B).

% Token balances: tb(Address, Amount).
:- regtype tok_balances/1.
tok_balances([]).
tok_balances([X|T]) :- tok_balpair(X), tok_balances(T).

:- regtype tok_balpair/1.
tok_balpair(tb(A, B)) :- atm(A), int(B).

% Token allowances: al(Owner, Spender, Amount).
:- regtype allowances/1.
allowances([]).
allowances([X|T]) :- allowance(X), allowances(T).

:- regtype allowance/1.
allowance(al(A, B, C)) :- atm(A), atm(B), int(C).

% NFT owners: t_o(TokenId, Owner).
:- regtype nft_owners/1.
nft_owners([]).
nft_owners([X|T]) :- nft_owner(X), nft_owners(T).

:- regtype nft_owner/1.
nft_owner(t_o(A, B)) :- gnd(A), atm(B).

% NFT balances: n_b(Owner, Count).
:- regtype nft_balances/1.
nft_balances([]).
nft_balances([X|T]) :- nft_balpair(X), nft_balances(T).

:- regtype nft_balpair/1.
nft_balpair(n_b(A, B)) :- atm(A), int(B).

% NFT approvals: app(TokenId, Approved).
:- regtype nft_approvals/1.
nft_approvals([]).
nft_approvals([X|T]) :- nft_approval(X), nft_approvals(T).

:- regtype nft_approval/1.
nft_approval(app(A, B)) :- gnd(A), atm(B).

% NFT operator approvals: op(Owner, Operator, Flag).
:- regtype nft_operators/1.
nft_operators([]).
nft_operators([X|T]) :- nft_operator(X), nft_operators(T).

:- regtype nft_operator/1.
nft_operator(op(A, B, C)) :- atm(A), atm(B), gnd(C).

% --- Gas of the primitives ---
% set_bal/4 and transfer/5 neither add nor remove entries: their output
% table has the length of their input (stated here: the type domain cannot
% see it).

:- trust pred get_bal(Addr, B, Bal)
   + ( not_fails, is_det, cost(lb, gas, length(B)), cost(ub, gas, length(B)) ).

:- trust pred set_bal(Addr, NewVal, B_in, B_out)
   => ( balances(B_out), size(lb, B_out, length(B_in)), size(ub, B_out, length(B_in)) )
   + ( not_fails, is_det, cost(lb, gas, length(B_in)), cost(ub, gas, length(B_in)) ).

:- trust pred transfer(From, To, Amount, B_in, B_out)
   => ( balances(B_out), size(lb, B_out, length(B_in)), size(ub, B_out, length(B_in)) )
   + ( not_fails, is_det, cost(lb, gas, 4*length(B_in)), cost(ub, gas, 4*length(B_in)) ).

:- trust pred get_tok_bal(Addr, TB, Bal)
   + ( not_fails, is_det, cost(lb, gas, length(TB)), cost(ub, gas, length(TB)) ).

:- trust pred get_allow(Owner, Spender, AL, Amount)
   + ( not_fails, is_det, cost(lb, gas, length(AL)), cost(ub, gas, length(AL)) ).

:- trust pred get_owner(Tok, TO, Owner)
   + ( not_fails, is_det, cost(lb, gas, length(TO)), cost(ub, gas, length(TO)) ).

:- trust pred get_nft_bal(Owner, NB, Count)
   + ( not_fails, is_det, cost(lb, gas, length(NB)), cost(ub, gas, length(NB)) ).

:- trust pred get_appr(Tok, AP, Approved)
   + ( not_fails, is_det, cost(lb, gas, length(AP)), cost(ub, gas, length(AP)) ).

:- trust pred get_op_appr(Owner, Operator, OP, Flag)
   + ( not_fails, is_det, cost(lb, gas, length(OP)), cost(ub, gas, length(OP)) ).

% A paper of ballot, or 0 when the voter has none.
:- regtype paper_or_none/1.
paper_or_none(0).
paper_or_none(paper(A, B, C, D, E)) :- gnd(A), gnd(B), gnd(C), gnd(D), gnd(E).

% Contract state tables: every scan of a table of the state costs one unit
% per entry, like the coin and token primitives.
:- trust pred get_paper(Voter, Papers, Paper)
   => ( paper_or_none(Paper), size(ub, Paper, size(Papers)) )
   + ( not_fails, is_det, cost(lb, gas, length(Papers)), cost(ub, gas, length(Papers)) ).

:- trust pred get_share(Addr, Shares, N)
   + ( not_fails, is_det, cost(lb, gas, length(Shares)), cost(ub, gas, length(Shares)) ).

:- trust pred get_board(Pos, Board, Cell)
   + ( not_fails, is_det, cost(lb, gas, length(Board)), cost(ub, gas, length(Board)) ).
