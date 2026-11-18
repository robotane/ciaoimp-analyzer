% Gas cost model "hotmoka": costs in Hotmoka gas units, calibrated on the
% Hotmoka 1.12.3 benchmark (hotmoka-bench/costmodel/calibrate_model.py, four
% calibration operations; every other operation is kept for validation).
% Select it with CIAOPP_COST_MODEL=hotmoka.
%
% - every resolution of contract code costs c_step = 30 (head_cost);
% - a coin payment (transfer/5, set_bal/4) costs c_transfer = 3135;
%   reading a coin balance costs 2*c_step (on Hotmoka a balance is a field);
% - reading a table entry before updating it (tokens, allowances, NFTs,
%   papers, shares) costs c_tree0 + c_tree1*log2(n+1) =
%   17149 + 9073*log2(n+1): the Java tables are StorageTreeMaps;
% - reading a cell of the tic-tac-toe board costs 2*c_step (a Java array read);
% - the fixed cost of a transaction, c_tx = 55572, is added to the bound
%   outside CiaoPP.

:- package(gas_model).
:- use_package(assertions).
:- use_package(nativeprops).
:- use_package(regtypes).
:- use_package(resdefs).

:- use_module(blockchain).

% --- Resource and default costs ---

:- resource gas.

:- head_cost(ub, gas, 30).
:- head_cost(lb, gas, 30).

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
   + ( not_fails, is_det, cost(lb, gas, 60), cost(ub, gas, 60) ).

:- trust pred set_bal(Addr, NewVal, B_in, B_out)
   => ( balances(B_out), size(lb, B_out, length(B_in)), size(ub, B_out, length(B_in)) )
   + ( not_fails, is_det, cost(lb, gas, 3135), cost(ub, gas, 3135) ).

:- trust pred transfer(From, To, Amount, B_in, B_out)
   => ( balances(B_out), size(lb, B_out, length(B_in)), size(ub, B_out, length(B_in)) )
   + ( not_fails, is_det, cost(lb, gas, 3135), cost(ub, gas, 3135) ).

:- trust pred get_tok_bal(Addr, TB, Bal)
   + ( not_fails, is_det, cost(lb, gas, 17149+9073*log2(length(TB)+1)), cost(ub, gas, 17149+9073*log2(length(TB)+1)) ).

:- trust pred get_allow(Owner, Spender, AL, Amount)
   + ( not_fails, is_det, cost(lb, gas, 17149+9073*log2(length(AL)+1)), cost(ub, gas, 17149+9073*log2(length(AL)+1)) ).

:- trust pred get_owner(Tok, TO, Owner)
   + ( not_fails, is_det, cost(lb, gas, 17149+9073*log2(length(TO)+1)), cost(ub, gas, 17149+9073*log2(length(TO)+1)) ).

:- trust pred get_nft_bal(Owner, NB, Count)
   + ( not_fails, is_det, cost(lb, gas, 17149+9073*log2(length(NB)+1)), cost(ub, gas, 17149+9073*log2(length(NB)+1)) ).

:- trust pred get_appr(Tok, AP, Approved)
   + ( not_fails, is_det, cost(lb, gas, 17149+9073*log2(length(AP)+1)), cost(ub, gas, 17149+9073*log2(length(AP)+1)) ).

:- trust pred get_op_appr(Owner, Operator, OP, Flag)
   + ( not_fails, is_det, cost(lb, gas, 17149+9073*log2(length(OP)+1)), cost(ub, gas, 17149+9073*log2(length(OP)+1)) ).

% A paper of ballot, or 0 when the voter has none.
:- regtype paper_or_none/1.
paper_or_none(0).
paper_or_none(paper(A, B, C, D, E)) :- gnd(A), gnd(B), gnd(C), gnd(D), gnd(E).

% Contract state tables: every scan of a table of the state costs one unit
% per entry, like the coin and token primitives.
:- trust pred get_paper(Voter, Papers, Paper)
   => ( paper_or_none(Paper), size(ub, Paper, size(Papers)) )
   + ( not_fails, is_det, cost(lb, gas, 17149+9073*log2(length(Papers)+1)), cost(ub, gas, 17149+9073*log2(length(Papers)+1)) ).

:- trust pred get_share(Addr, Shares, N)
   + ( not_fails, is_det, cost(lb, gas, 17149+9073*log2(length(Shares)+1)), cost(ub, gas, 17149+9073*log2(length(Shares)+1)) ).

:- trust pred get_board(Pos, Board, Cell)
   + ( not_fails, is_det, cost(lb, gas, 60), cost(ub, gas, 60) ).
