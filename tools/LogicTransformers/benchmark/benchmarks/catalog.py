from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from core.artifacts import scenario_files, xsyntax_scenario_file
from core.caslog import CaslogTarget
from core.project import NORMALIZED_DIR, XSYNTAX_SOURCE_DIR
from core.scenario import (
    read_source_without_goal,
    read_xsyntax_source_without_goal,
)


@dataclass(frozen=True)
class BenchmarkSpec:
    name: str
    contract: str
    predicate: str
    complexity_label: str
    ns: list[int]
    caslog_bindings: dict[int, int]
    build_source: callable
    x_label: str
    # Optionnel : builder xsyntax pour Ciao. Si None, Ciao mesure aussi build_source.
    build_ciao_source: callable | None = None

    @property
    def title(self) -> str:
        return f"{self.contract.upper()} ({self.predicate})"

    @property
    def predicate_label(self) -> str:
        return self.predicate.split("/")[0]

    @property
    def caslog_target(self) -> CaslogTarget:
        return CaslogTarget(self.contract, self.predicate, self.caslog_bindings)


def _base(contract: str) -> str:
    return read_source_without_goal(NORMALIZED_DIR / f"{contract}.pl")


def _write(bench_name: str, n: int, text: str) -> Path:
    scenario_pl, _ = scenario_files(bench_name, n)
    scenario_pl.write_text(text, encoding="utf-8")
    return scenario_pl


def _xsyntax_base(contract: str) -> str:
    """Source xsyntax (data/source) sans :- module(...) ni goal/1 natif."""
    return read_xsyntax_source_without_goal(XSYNTAX_SOURCE_DIR / f"{contract}.pl")


def _write_xsyntax(bench_name: str, n: int, text: str) -> Path:
    out = xsyntax_scenario_file(bench_name, n)
    out.write_text(text, encoding="utf-8")
    return out


def build_simple_ponzi(n: int, bench_name: str) -> Path:
    base = _base("simple_ponzi")
    bals = ", ".join([f"bal(acc{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    invest(bob, 120, null, 100, _, _, [{bals}bal(alice, 1000), bal(bob, 1000), bal(this, 0)], G).
"""
    return _write(bench_name, n, base + goal)


def build_simple_ponzi_xsyntax(n: int, bench_name: str) -> Path:
    """Version xsyntax (data/source/simple_ponzi.pl) avec goal parametre.

    Signature impérative : invest(Caller, Value, !S, !B)
    où !S et !B donnent à la compilation S_in, S_out, B_in, B_out.
    L'état est un terme state(LastInv, LastAmt).
    """
    base = _xsyntax_base("simple_ponzi")
    bals = ", ".join([f"bal(acc{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    invest(bob, 120, state(null, 100), _, [{bals}bal(alice, 1000), bal(bob, 1000), bal(this, 0)], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_simple_ponzi_init(n: int, bench_name: str) -> Path:
    base = _base("simple_ponzi")
    goal = """
goal([1]) :-
    init(_, D1, D2).
"""
    return _write(bench_name, n, base + goal)


def build_distributor(n: int, bench_name: str) -> Path:
    base = _base("distributor")
    payees = ", ".join([f"p{i}" for i in range(n)])
    bals = ", ".join([f"bal(p{i}, 0)" for i in range(n)])
    if bals:
        bals += ", "
    total = n * 10
    goal = f"""
goal([1]) :-
    distribute(admin, {total}, owner, [{payees}], _, _, [{bals}bal(admin, 1000), bal(this, {total})], H).
"""
    return _write(bench_name, n, base + goal)


def build_distributor_add_as_payee(n: int, bench_name: str) -> Path:
    base = _base("distributor")
    payees = ", ".join([f"p{i}" for i in range(n)])
    goal = f"""
goal([1]) :-
    add_as_payee(new_p, E1, [{payees}], F1, F2).
"""
    return _write(bench_name, n, base + goal)


def build_simple_pyramid(n: int, bench_name: str) -> Path:
    base = _base("simple_pyramid")
    inv_list = ", ".join([f"p{i}" for i in range(n)])
    inv_list = inv_list + ", alice" if inv_list else "alice"
    bals = ", ".join([f"bal(p{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    invest(newinv, 15000, [{inv_list}], 1000, _, _, [{bals}bal(alice, 1000), bal(this, 0), bal(newinv, 20000)], G).
"""
    return _write(bench_name, n, base + goal)


def build_simple_pyramid_init(n: int, bench_name: str) -> Path:
    base = _base("simple_pyramid")
    goal = """
goal([1]) :-
    init(alice, B1, B2, B3).
"""
    return _write(bench_name, n, base + goal)


def build_simple_auction_init(n: int, bench_name: str) -> Path:
    base = _base("simple_auction")
    goal = """
goal([1]) :-
    init(100, bene, 0, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_simple_auction_bid(n: int, bench_name: str) -> Path:
    base = _base("simple_auction")
    bals = ", ".join([f"bal(p{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    init(100, bene, 0, _, E1, E2, E3, E4),
    bid(alice, 100, 10, E1, E2, E3, E4, _, _, _, _, [{bals}bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)], _).
"""
    return _write(bench_name, n, base + goal)


def build_simple_auction_end(n: int, bench_name: str) -> Path:
    base = _base("simple_auction")
    bals = ", ".join([f"bal(p{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    init(100, bene, 0, _, E1, E2, E3, E4),
    bid(alice, 100, 10, E1, E2, E3, E4, F1, F2, F3, F4, [{bals}bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)], G),
    bid(bob, 200, 20, F1, F2, F3, F4, H1, H2, H3, H4, G, I),
    auction_end(200, H1, H2, H3, H4, _, _, _, _, I, _).
"""
    return _write(bench_name, n, base + goal)


def build_auction_init(n: int, bench_name: str) -> Path:
    base = _base("auction")
    goal = """
goal([1]) :-
    init(100, bene, 0, _, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_auction_bid(n: int, bench_name: str) -> Path:
    base = _base("auction")
    bals = ", ".join([f"bal(p{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    init(100, bene, 0, _, E1, E2, E3, E4, E5),
    bid(alice, 100, 10, E1, E2, E3, E4, E5, _, _, _, _, _, [{bals}bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)], _).
"""
    return _write(bench_name, n, base + goal)


def build_auction_end(n: int, bench_name: str) -> Path:
    base = _base("auction")
    bals = ", ".join([f"bal(p{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    init(100, bene, 0, _, E1, E2, E3, E4, E5),
    bid(alice, 100, 10, E1, E2, E3, E4, E5, F1, F2, F3, F4, F5, [{bals}bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)], G),
    bid(bob, 150, 20, F1, F2, F3, F4, F5, H1, H2, H3, H4, H5, G, I),
    end(200, H1, H2, H3, H4, H5, _, _, _, _, _, I, _).
"""
    return _write(bench_name, n, base + goal)


def build_blind_auction_init(n: int, bench_name: str) -> Path:
    base = _base("blind_auction")
    goal = """
goal([1]) :-
    init(100, 100, bene, 0, _, _, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_blind_auction_bid(n: int, bench_name: str) -> Path:
    base = _base("blind_auction")
    bals = ", ".join([f"bal(p{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    init(100, 100, bene, 0, _, E1, E2, E3, E4, E5, E6),
    bid(alice, 200, 10, h_alice, E1, E2, E3, E4, E5, E6, _, _, _, _, _, _, [{bals}bal(alice, 1000), bal(bob, 1000), bal(bene, 0), bal(this, 0)], _).
"""
    return _write(bench_name, n, base + goal)


def build_ballot_init_props(n: int, bench_name: str) -> Path:
    base = _base("ballot")
    props = ", ".join([f"prop_{i}" for i in range(n)])
    goal = f"""
goal([1]) :-
    init_props([{props}], _).
"""
    return _write(bench_name, n, base + goal)


def build_ballot_init(n: int, bench_name: str) -> Path:
    base = _base("ballot")
    props = ", ".join([f"prop_{i}" for i in range(n)])
    goal = f"""
goal([1]) :-
    init([{props}], admin, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_ballot_give_right(n: int, bench_name: str) -> Path:
    base = _base("ballot")
    props = ", ".join([f"prop_{i}" for i in range(max(n, 1))])
    papers = ", ".join([f"paper(p{i}, 1, 0, null, -1)" for i in range(n)])
    goal = f"""
goal([1]) :-
    init([{props}], admin, Admin, Proposals, _),
    give_right(alice, admin, Admin, Proposals, [{papers}], _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_ballot_give_right_xsyntax(n: int, bench_name: str) -> Path:
    """Version xsyntax (data/source/ballot.pl) avec goal parametre.

    Signature impérative : give_right(Voter, Caller, S_in, S_out).
    L'état contient state(Chair, Props, Papers). N controle la taille
    de la liste Papers (parcourue par get_paper -> O(N)).
    """
    base = _xsyntax_base("ballot")
    papers = ", ".join([f"paper(p{i}, 1, 0, 'null', -1)" for i in range(n)])
    goal = f"""
goal([1]) :-
    S_in = state(admin, [proposal(prop_a, 0)], [{papers}]),
    give_right(alice, admin, S_in, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_crowdfunding_init(n: int, bench_name: str) -> Path:
    base = _base("crowdfunding")
    goal = """
goal([1]) :-
    init(_, _).
"""
    return _write(bench_name, n, base + goal)


def build_crowdfunding_len_list(n: int, bench_name: str) -> Path:
    base = _base("crowdfunding")
    elems = ", ".join([f"x{i}" for i in range(n)])
    goal = f"""
goal([1]) :-
    len_list([{elems}], _).
"""
    return _write(bench_name, n, base + goal)


def build_crowdfunding_new_campaign(n: int, bench_name: str) -> Path:
    base = _base("crowdfunding")
    campaigns = ", ".join([f"campaign(owner{i}, 100, {i}, 0, [])" for i in range(n)])
    goal = f"""
goal([1]) :-
    new_campaign(bene, 300, _, [{campaigns}], _).
"""
    return _write(bench_name, n, base + goal)


def build_crowdfunding_contribute(n: int, bench_name: str) -> Path:
    base = _base("crowdfunding")
    funders = ", ".join([f"funder(p{i}, 1)" for i in range(n)])
    campaigns = f"[campaign(0, bene, 300, 0, [{funders}])]"
    bals = ", ".join([f"bal(p{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    contribute(alice, 200, 0, {campaigns}, _, [{bals}bal(alice, 1000), bal(this, 0)], _).
"""
    return _write(bench_name, n, base + goal)


def build_default_stateful(contract: str, n: int, bench_name: str) -> Path:
    base = _base(contract)
    bals = ", ".join([f"bal(p{i}, 100)" for i in range(n)])
    if bals:
        bals += ", "
    text = base.replace("[bal(alice, 1000)", f"[{bals}bal(alice, 1000)")
    return _write(bench_name, n, text)


def build_ballot(n: int, bench_name: str) -> Path:
    base = _base("ballot")
    papers = ", ".join([f"paper(p{i}, 1, 0, null, -1)" for i in range(n)])
    if papers:
        base = base.replace(
            "give_right(alice, admin, B_1, B_2, B_3",
            f"give_right(alice, admin, B_1, B_2, [{papers} | B_3]",
        )
    return _write(bench_name, n, base)


def build_crypto_buddy(n: int, bench_name: str) -> Path:
    base = _base("crypto_buddy")
    tbs = ", ".join([f"tb(p{i}, 100)" for i in range(n)])
    token_list = f"[{tbs}, tb(alice, 1000), tb(dave, 0)]" if tbs else "[tb(alice, 1000), tb(dave, 0)]"
    goal = f"""
goal([1]) :-
    token_transfer(dave, 100, alice, bob, {token_list}, [], _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_crypto_buddy_init(n: int, bench_name: str) -> Path:
    base = _base("crypto_buddy")
    goal = """
goal([1]) :-
    init(btk, alice, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_crypto_buddy_approve(n: int, bench_name: str) -> Path:
    base = _base("crypto_buddy")
    tbs = ", ".join([f"tb(p{i}, 100)" for i in range(n)])
    token_list = f"[{tbs}, tb(alice, 1000)]" if tbs else "[tb(alice, 1000)]"
    goal = f"""
goal([1]) :-
    init(btk, alice, _, E1, _, E3),
    approve(bob, 300, alice, E1, {token_list}, E3, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_crypto_buddy_transfer_from(n: int, bench_name: str) -> Path:
    base = _base("crypto_buddy")
    tbs = ", ".join([f"tb(p{i}, 100)" for i in range(n)])
    token_list = f"[{tbs}, tb(alice, 1000), tb(charlie, 0)]" if tbs else "[tb(alice, 1000), tb(charlie, 0)]"
    goal = f"""
goal([1]) :-
    transferFrom(alice, charlie, 200, bob, alice, {token_list}, [al(alice, bob, 300)], _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_crypto_shark(n: int, bench_name: str) -> Path:
    base = _base("crypto_shark")
    tbs = ", ".join([f"t_o(p{i}, p{i})" for i in range(n)])
    nbs = ", ".join([f"n_b(p{i}, 1)" for i in range(n)])
    owner_list = f"[{tbs}]" if tbs else "[]"
    nb_list = f"[{nbs}]" if nbs else "[]"
    goal = f"""
goal([1]) :-
    mint(alice, 1, shark, s, {owner_list}, {nb_list}, [], [], _, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_crypto_shark_init(n: int, bench_name: str) -> Path:
    base = _base("crypto_shark")
    goal = """
goal([1]) :-
    init(shark, s, _, _, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_crypto_shark_approve(n: int, bench_name: str) -> Path:
    base = _base("crypto_shark")
    owners = ", ".join([f"t_o({i}, alice)" for i in range(2, n + 2)])
    nbs = f"[n_b(alice, {n + 1})]"
    owner_list = f"[t_o(1, alice), {owners}]" if owners else "[t_o(1, alice)]"
    goal = f"""
goal([1]) :-
    approve(bob, 1, alice, shark, s, {owner_list}, {nbs}, [], [], _, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_crypto_shark_set_approval_for_all(n: int, bench_name: str) -> Path:
    base = _base("crypto_shark")
    ops = ", ".join([f"op(alice, bob{i}, 1)" for i in range(n)])
    op_list = f"[{ops}]" if ops else "[]"
    goal = f"""
goal([1]) :-
    setApprovalForAll(1, bob, alice, shark, s, [], [], [], {op_list}, _, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_example_coin(n: int, bench_name: str) -> Path:
    base = _base("example_coin")
    tbs = ", ".join([f"tb(p{i}, 1)" for i in range(n)])
    token_list = f"[{tbs}, tb(alice, 1000), tb(bob, 0)]" if tbs else "[tb(alice, 1000), tb(bob, 0)]"
    goal = f"""
goal([1]) :-
    token_transfer(bob, 500, alice, mycoin, mc, alice, 1000000, {token_list}, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_example_coin_init(n: int, bench_name: str) -> Path:
    base = _base("example_coin")
    goal = """
goal([1]) :-
    init(mycoin, mc, alice, _, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_example_coin_mint(n: int, bench_name: str) -> Path:
    base = _base("example_coin")
    tbs = ", ".join([f"tb(p{i}, 1)" for i in range(n)])
    token_list = f"[{tbs}, tb(alice, 1000000)]" if tbs else "[tb(alice, 1000000)]"
    goal = f"""
goal([1]) :-
    mint(charlie, 200, alice, mycoin, mc, alice, 1000000, {token_list}, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_example_coin_burn(n: int, bench_name: str) -> Path:
    base = _base("example_coin")
    tbs = ", ".join([f"tb(p{i}, 1)" for i in range(n)])
    token_list = f"[{tbs}, tb(alice, 1000000)]" if tbs else "[tb(alice, 1000000)]"
    goal = f"""
goal([1]) :-
    burn(alice, 100, alice, mycoin, mc, alice, 1000000, {token_list}, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_example_erc721(n: int, bench_name: str) -> Path:
    base = _base("example_erc721")
    tbs = ", ".join([f"t_o(p{i}, p{i})" for i in range(n)])
    nbs = ", ".join([f"n_b(p{i}, 1)" for i in range(n)])
    owner_list = f"[{tbs}, t_o(1, alice)]" if tbs else "[t_o(1, alice)]"
    nb_list = f"[{nbs}, n_b(alice, 1)]" if nbs else "[n_b(alice, 1)]"
    goal = f"""
goal([1]) :-
    transferFrom(alice, bob, 1, alice, nft, n, {owner_list}, {nb_list}, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_example_erc721_init(n: int, bench_name: str) -> Path:
    base = _base("example_erc721")
    goal = """
goal([1]) :-
    init(nft, n, _, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_example_erc721_mint(n: int, bench_name: str) -> Path:
    base = _base("example_erc721")
    owners = ", ".join([f"t_o({i}, alice)" for i in range(2, n + 2)])
    nbs = f"[n_b(alice, {n})]"
    owner_list = f"[{owners}]" if owners else "[]"
    goal = f"""
goal([1]) :-
    mint(alice, 1, nft, n, {owner_list}, {nbs}, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_gradual_ponzi(n: int, bench_name: str) -> Path:
    base = _base("gradual_ponzi")
    inv_list = ", ".join([f"p{i}" for i in range(n)])
    inv_list = inv_list + ", alice" if inv_list else "alice"
    bals = ", ".join([f"bal(p{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    invest(newinv, 15000, [{inv_list}], _, [{bals}bal(alice, 1000), bal(this, 0), bal(newinv, 20000)], G).
"""
    return _write(bench_name, n, base + goal)


def build_gradual_ponzi_init(n: int, bench_name: str) -> Path:
    base = _base("gradual_ponzi")
    goal = """
goal([1]) :-
    init(alice, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_shared_entity(contract: str, n: int, bench_name: str) -> Path:
    base = _base(contract)
    shares = ", ".join([f"sh(p{i}, 1)" for i in range(n)])
    share_list = f"[{shares}, sh(alice, 60), sh(bob, 40)]" if shares else "[sh(alice, 60), sh(bob, 40)]"
    goal = f"""
goal([1]) :-
    init([sh(alice, 60), sh(bob, 40)], _, _, E2, E3),
    place_offer(500, 20, alice, {share_list}, E2, E3, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_shared_entity_init(contract: str, n: int, bench_name: str) -> Path:
    base = _base(contract)
    shares = ", ".join([f"sh(p{i}, 1)" for i in range(n)])
    share_list = f"[{shares}]" if shares else "[]"
    goal = f"""
goal([1]) :-
    init({share_list}, _, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_distributor_init(n: int, bench_name: str) -> Path:
    base = _base("distributor")
    goal = """
goal([1]) :-
    init(owner, _, _, _).
"""
    return _write(bench_name, n, base + goal)


def build_distributor_len_list(n: int, bench_name: str) -> Path:
    base = _base("distributor")
    payees = ", ".join([f"p{i}" for i in range(n)])
    goal = f"""
goal([1]) :-
    len_list([{payees}], _).
"""
    return _write(bench_name, n, base + goal)


def build_tictactoe_init(n: int, bench_name: str) -> Path:
    base = _base("tictactoe")
    bals = ", ".join([f"bal(p{i}, 1000)" for i in range(n)])
    if bals:
        bals += ", "
    goal = f"""
goal([1]) :-
    init(alice, bob, 100, _, _, _, _, _, [], [{bals}bal(alice, 1000), bal(bob, 1000), bal(this, 0)], _).
"""
    return _write(bench_name, n, base + goal)


def build_tictactoe_check_winner(n: int, bench_name: str) -> Path:
    base = _base("tictactoe")
    cells = ", ".join([f"cell({i}, {1 if i % 2 else 2})" for i in range(1, n + 1)])
    goal = f"""
goal([1]) :-
    check_winner([{cells}], _).
"""
    return _write(bench_name, n, base + goal)


# ─────────────────────────────────────────────────────────────────────────────
# Builders xsyntax (data/source/*.pl) avec goals paramétrés sur N.
# Chaque builder appelle un prédicat impératif (signature !S, !B, ~, for...in)
# tel que défini dans la source ciaoimp originale.
# ─────────────────────────────────────────────────────────────────────────────

def _bals_n(n: int, *extra: str) -> str:
    """Construit une liste de N balances acc0..accN-1 + balances additionnelles."""
    parts = [f"bal(acc{i}, 1000)" for i in range(n)] + list(extra)
    return ", ".join(parts)


# --- auction --------------------------------------------------------------
def build_auction_init_xsyntax(n, bench_name):
    base = _xsyntax_base("auction")
    goal = """
goal([1]) :-
    init(100, bene, 0, _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_auction_bid_xsyntax(n, bench_name):
    base = _xsyntax_base("auction")
    bals = _bals_n(n, "bal(alice, 1000)", "bal(bene, 0)", "bal(this, 0)")
    goal = f"""
goal([1]) :-
    bid(alice, 100, 10, state(bene, 100, 'null', 0, 0), _, [{bals}], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_auction_end_xsyntax(n, bench_name):
    base = _xsyntax_base("auction")
    bals = _bals_n(n, "bal(alice, 1000)", "bal(bene, 0)", "bal(this, 100)")
    goal = f"""
goal([1]) :-
    end(200, state(bene, 100, alice, 100, 0), _, [{bals}], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- ballot ---------------------------------------------------------------
def build_ballot_init_props_xsyntax(n, bench_name):
    base = _xsyntax_base("ballot")
    props = ", ".join([f"prop_{i}" for i in range(n)])
    goal = f"""
goal([1]) :-
    init_props([{props}], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_ballot_init_xsyntax(n, bench_name):
    base = _xsyntax_base("ballot")
    props = ", ".join([f"prop_{i}" for i in range(n)])
    goal = f"""
goal([1]) :-
    init([{props}], admin, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- blind_auction --------------------------------------------------------
def build_blind_auction_init_xsyntax(n, bench_name):
    base = _xsyntax_base("blind_auction")
    goal = """
goal([1]) :-
    init(100, 100, bene, 0, _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_blind_auction_bid_xsyntax(n, bench_name):
    base = _xsyntax_base("blind_auction")
    bals = _bals_n(n, "bal(alice, 1000)", "bal(this, 0)")
    goal = f"""
goal([1]) :-
    bid(alice, 200, 10, h_alice, state(bene, 100, 200, 'null', 0, []), _, [{bals}], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- crowdfunding ---------------------------------------------------------
def build_crowdfunding_init_xsyntax(n, bench_name):
    base = _xsyntax_base("crowdfunding")
    goal = """
goal([1]) :-
    init(_, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_crowdfunding_len_list_xsyntax(n, bench_name):
    """Le prédicat len_list/2 n'existe pas en xsyntax (helper généré par la
    normalisation). On émule le comportement avec length/2 de library(lists)."""
    base = _xsyntax_base("crowdfunding")
    items = ", ".join([str(i) for i in range(n)])
    goal = f"""
goal([Len]) :-
    length([{items}], Len).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_crowdfunding_new_campaign_xsyntax(n, bench_name):
    base = _xsyntax_base("crowdfunding")
    camps = ", ".join([f"campaign({i}, bene, 100, 0, [])" for i in range(n)])
    goal = f"""
goal([1]) :-
    new_campaign(bene, 300, _, state([{camps}]), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_crowdfunding_contribute_xsyntax(n, bench_name):
    base = _xsyntax_base("crowdfunding")
    camps = ", ".join([f"campaign({i}, bene, 100, 0, [])" for i in range(n)])
    goal = f"""
goal([1]) :-
    contribute(alice, 50, 0, state([{camps}]), _, [bal(alice, 1000), bal(this, 0)], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- crypto_buddy ---------------------------------------------------------
def build_crypto_buddy_init_xsyntax(n, bench_name):
    base = _xsyntax_base("crypto_buddy")
    goal = """
goal([1]) :-
    init(btk, alice, _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_crypto_buddy_approve_xsyntax(n, bench_name):
    base = _xsyntax_base("crypto_buddy")
    goal = """
goal([1]) :-
    approve(bob, 300, alice, state(btk, [tb(alice, 1000)], []), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_crypto_buddy_transferFrom_xsyntax(n, bench_name):
    base = _xsyntax_base("crypto_buddy")
    tbs = ", ".join([f"tb(acc{i}, 100)" for i in range(n)])
    if tbs:
        tbs = tbs + ", "
    goal = f"""
goal([1]) :-
    transferFrom(alice, charlie, 200, bob,
        state(btk, [{tbs}tb(alice, 1000), tb(charlie, 0)],
              [al(alice, bob, 300)]), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_crypto_buddy_token_transfer_xsyntax(n, bench_name):
    base = _xsyntax_base("crypto_buddy")
    tbs = ", ".join([f"tb(acc{i}, 100)" for i in range(n)])
    if tbs:
        tbs = tbs + ", "
    goal = f"""
goal([1]) :-
    token_transfer(bob, 100, alice,
        state(btk, [{tbs}tb(alice, 1000), tb(bob, 0)], []), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- crypto_shark ---------------------------------------------------------
def build_crypto_shark_init_xsyntax(n, bench_name):
    base = _xsyntax_base("crypto_shark")
    goal = """
goal([1]) :-
    init(shark, s, _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_crypto_shark_mint_xsyntax(n, bench_name):
    base = _xsyntax_base("crypto_shark")
    tos = ", ".join([f"t_o({i+100}, alice)" for i in range(n)])
    nbs = ", ".join([f"n_b(acc{i}, 1)" for i in range(n)])
    goal = f"""
goal([1]) :-
    mint(alice, 1, state(shark, s, [{tos}], [{nbs}], [], []), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_crypto_shark_approve_xsyntax(n, bench_name):
    base = _xsyntax_base("crypto_shark")
    extra_tos = ", ".join([f"t_o({i+100}, acc{i})" for i in range(n)])
    if extra_tos:
        extra_tos = extra_tos + ", "
    goal = f"""
goal([1]) :-
    approve(bob, 1, alice,
        state(shark, s, [{extra_tos}t_o(1, alice)], [], [], []), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_crypto_shark_setApprovalForAll_xsyntax(n, bench_name):
    base = _xsyntax_base("crypto_shark")
    goal = """
goal([1]) :-
    setApprovalForAll(bob, 1, alice,
        state(shark, s, [], [], [], []), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- distributor ----------------------------------------------------------
def build_distributor_init_xsyntax(n, bench_name):
    base = _xsyntax_base("distributor")
    goal = """
goal([1]) :-
    init(owner, _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_distributor_add_as_payee_xsyntax(n, bench_name):
    base = _xsyntax_base("distributor")
    payees = ", ".join([f"p{i}" for i in range(n)])
    goal = f"""
goal([1]) :-
    add_as_payee(new_p, state(owner, [{payees}]), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_distributor_len_list_xsyntax(n, bench_name):
    """Le prédicat len_list/2 n'existe pas en xsyntax. On utilise length/2."""
    base = _xsyntax_base("distributor")
    payees = ", ".join([f"p{i}" for i in range(n)])
    goal = f"""
goal([Len]) :-
    length([{payees}], Len).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_distributor_distribute_xsyntax(n, bench_name):
    base = _xsyntax_base("distributor")
    payees = ", ".join([f"p{i}" for i in range(n)])
    bals = ", ".join([f"bal(p{i}, 0)" for i in range(n)])
    if bals:
        bals = bals + ", "
    total = n * 10
    goal = f"""
goal([1]) :-
    distribute(admin, {total},
        state(owner, [{payees}]), _,
        [{bals}bal(admin, 1000), bal(this, {total})], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- example_coin ---------------------------------------------------------
def build_example_coin_init_xsyntax(n, bench_name):
    base = _xsyntax_base("example_coin")
    goal = """
goal([1]) :-
    init(mycoin, mc, alice, _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_example_coin_token_transfer_xsyntax(n, bench_name):
    base = _xsyntax_base("example_coin")
    tbs = ", ".join([f"tb(acc{i}, 100)" for i in range(n)])
    if tbs:
        tbs = tbs + ", "
    goal = f"""
goal([1]) :-
    token_transfer(bob, 500, alice,
        state(mycoin, mc, alice, 1000000, [{tbs}tb(alice, 1000000), tb(bob, 0)]), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_example_coin_mint_xsyntax(n, bench_name):
    base = _xsyntax_base("example_coin")
    tbs = ", ".join([f"tb(acc{i}, 100)" for i in range(n)])
    if tbs:
        tbs = tbs + ", "
    goal = f"""
goal([1]) :-
    mint(charlie, 200, alice,
        state(mycoin, mc, alice, 1000000, [{tbs}tb(alice, 1000000), tb(charlie, 0)]), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_example_coin_burn_xsyntax(n, bench_name):
    base = _xsyntax_base("example_coin")
    tbs = ", ".join([f"tb(acc{i}, 100)" for i in range(n)])
    if tbs:
        tbs = tbs + ", "
    goal = f"""
goal([1]) :-
    burn(bob, 100, alice,
        state(mycoin, mc, alice, 1000000, [{tbs}tb(alice, 1000000), tb(bob, 1000)]), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- example_erc721 -------------------------------------------------------
def build_example_erc721_init_xsyntax(n, bench_name):
    base = _xsyntax_base("example_erc721")
    goal = """
goal([1]) :-
    init(nft, n, _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_example_erc721_mint_xsyntax(n, bench_name):
    base = _xsyntax_base("example_erc721")
    tos = ", ".join([f"t_o({i+100}, alice)" for i in range(n)])
    nbs = ", ".join([f"n_b(acc{i}, 1)" for i in range(n)])
    goal = f"""
goal([1]) :-
    mint(alice, 1, state(nft, n, [{tos}], [{nbs}]), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_example_erc721_transferFrom_xsyntax(n, bench_name):
    base = _xsyntax_base("example_erc721")
    extra_tos = ", ".join([f"t_o({i+100}, acc{i})" for i in range(n)])
    if extra_tos:
        extra_tos = extra_tos + ", "
    extra_nbs = ", ".join([f"n_b(acc{i}, 1)" for i in range(n)])
    if extra_nbs:
        extra_nbs = extra_nbs + ", "
    goal = f"""
goal([1]) :-
    transferFrom(alice, bob, 1, alice,
        state(nft, n, [{extra_tos}t_o(1, alice)],
                       [{extra_nbs}n_b(alice, 1), n_b(bob, 0)]), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- gradual_ponzi --------------------------------------------------------
def build_gradual_ponzi_init_xsyntax(n, bench_name):
    base = _xsyntax_base("gradual_ponzi")
    goal = """
goal([1]) :-
    init(alice, _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_gradual_ponzi_invest_xsyntax(n, bench_name):
    base = _xsyntax_base("gradual_ponzi")
    investors = ", ".join([f"acc{i}" for i in range(n)])
    bals = _bals_n(n, "bal(alice, 1000)", "bal(this, 0)")
    goal = f"""
goal([1]) :-
    invest(alice, 1000, state([{investors}]), _, [{bals}], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- shared_entity / simple_shared_entity ---------------------------------
def _build_shared_entity_init_xsyntax(contract, n, bench_name):
    base = _xsyntax_base(contract)
    shares = ", ".join([f"sh(acc{i}, 100)" for i in range(n)])
    # signature `init(Shares, !S)` donne init(Shares, S_in, S_out) -> 3 args
    goal = f"""
goal([1]) :-
    init([{shares}], _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def _build_shared_entity_place_offer_xsyntax(contract, n, bench_name):
    base = _xsyntax_base(contract)
    shares = ", ".join([f"sh(acc{i}, 100)" for i in range(n)])
    if shares:
        shares = shares + ", "
    goal = f"""
goal([1]) :-
    place_offer(500, 20, alice, state([{shares}sh(alice, 60)], [], 0), _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_shared_entity_init_xsyntax(n, bench_name):
    return _build_shared_entity_init_xsyntax("shared_entity", n, bench_name)


def build_shared_entity_place_offer_xsyntax(n, bench_name):
    return _build_shared_entity_place_offer_xsyntax("shared_entity", n, bench_name)


def build_simple_shared_entity_init_xsyntax(n, bench_name):
    return _build_shared_entity_init_xsyntax("simple_shared_entity", n, bench_name)


def build_simple_shared_entity_place_offer_xsyntax(n, bench_name):
    return _build_shared_entity_place_offer_xsyntax("simple_shared_entity", n, bench_name)


# --- simple_auction -------------------------------------------------------
def build_simple_auction_init_xsyntax(n, bench_name):
    base = _xsyntax_base("simple_auction")
    goal = """
goal([1]) :-
    init(100, bene, 0, _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_simple_auction_bid_xsyntax(n, bench_name):
    base = _xsyntax_base("simple_auction")
    bals = _bals_n(n, "bal(alice, 1000)", "bal(bene, 0)", "bal(this, 0)")
    goal = f"""
goal([1]) :-
    bid(alice, 100, 10, state(bene, 100, 0, 'null'), _, [{bals}], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_simple_auction_end_xsyntax(n, bench_name):
    base = _xsyntax_base("simple_auction")
    bals = _bals_n(n, "bal(alice, 1000)", "bal(bene, 0)", "bal(this, 100)")
    goal = f"""
goal([1]) :-
    auction_end(200, state(bene, 100, 100, alice), _, [{bals}], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- simple_ponzi (init) --------------------------------------------------
def build_simple_ponzi_init_xsyntax(n, bench_name):
    base = _xsyntax_base("simple_ponzi")
    goal = """
goal([1]) :-
    init(_, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- simple_pyramid -------------------------------------------------------
def build_simple_pyramid_init_xsyntax(n, bench_name):
    base = _xsyntax_base("simple_pyramid")
    goal = """
goal([1]) :-
    init(alice, _, _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_simple_pyramid_invest_xsyntax(n, bench_name):
    base = _xsyntax_base("simple_pyramid")
    investors = ", ".join([f"acc{i}" for i in range(n)])
    bals = _bals_n(n, "bal(alice, 5000)", "bal(this, 0)")
    goal = f"""
goal([1]) :-
    invest(alice, 1100, state([{investors}], 1000), _, [{bals}], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


# --- tictactoe ------------------------------------------------------------
def build_tictactoe_init_xsyntax(n, bench_name):
    base = _xsyntax_base("tictactoe")
    bals = _bals_n(n, "bal(alice, 1000)", "bal(bob, 1000)", "bal(this, 0)")
    goal = f"""
goal([1]) :-
    init(alice, bob, 100, _, _, [{bals}], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


def build_tictactoe_check_winner_xsyntax(n, bench_name):
    base = _xsyntax_base("tictactoe")
    cells = ", ".join([f"cell({i}, {1 if i % 2 else 2})" for i in range(1, n + 1)])
    goal = f"""
goal([1]) :-
    check_winner([{cells}], _).
"""
    return _write_xsyntax(bench_name, n, base + goal)


ALL_BENCHMARKS = [
    BenchmarkSpec("auction_init", "auction", "init/9", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_auction_init, "N (Taille de l'état)", build_ciao_source=build_auction_init_xsyntax),
    BenchmarkSpec("auction_bid", "auction", "bid/15", "O(N)", [5, 10, 20, 30, 40, 50], {14: 0}, build_auction_bid, "N (Taille de l'état)", build_ciao_source=build_auction_bid_xsyntax),
    BenchmarkSpec("auction_end", "auction", "end/13", "O(N)", [5, 10, 20, 30, 40, 50], {12: 0}, build_auction_end, "N (Taille de l'état)", build_ciao_source=build_auction_end_xsyntax),
    BenchmarkSpec("ballot_init_props", "ballot", "init_props/2", "O(N)", [10, 100, 200, 400, 600, 800, 1000], {1: 0}, build_ballot_init_props, "N (Nombre de propositions)", build_ciao_source=build_ballot_init_props_xsyntax),
    BenchmarkSpec("ballot_init", "ballot", "init/5", "O(N)", [10, 100, 200, 400, 600, 800, 1000], {1: 0}, build_ballot_init, "N (Nombre de propositions)", build_ciao_source=build_ballot_init_xsyntax),
    BenchmarkSpec("ballot_give_right", "ballot", "give_right/8", "O(N)", [5, 10, 20, 30, 40, 50], {5: 0}, build_ballot_give_right, "N (Nombre de papiers)", build_ciao_source=build_ballot_give_right_xsyntax),
    BenchmarkSpec("blind_auction_init", "blind_auction", "init/11", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_blind_auction_init, "N (Taille de l'état)", build_ciao_source=build_blind_auction_init_xsyntax),
    BenchmarkSpec("blind_auction_bid", "blind_auction", "bid/18", "O(N)", [5, 10, 20, 30, 40, 50], {17: 0}, build_blind_auction_bid, "N (Taille de l'état)", build_ciao_source=build_blind_auction_bid_xsyntax),
    BenchmarkSpec("crowdfunding_init", "crowdfunding", "init/2", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_crowdfunding_init, "N (Nombre de campagnes)", build_ciao_source=build_crowdfunding_init_xsyntax),
    BenchmarkSpec("crowdfunding_len_list", "crowdfunding", "len_list/2", "O(N)", [10, 100, 200, 400, 600, 800, 1000], {1: 0}, build_crowdfunding_len_list, "N (Longueur de liste)", build_ciao_source=build_crowdfunding_len_list_xsyntax),
    BenchmarkSpec("crowdfunding_new_campaign", "crowdfunding", "new_campaign/5", "O(N)", [10, 30, 50, 80, 110, 130, 150], {4: 0}, build_crowdfunding_new_campaign, "N (Nombre de campagnes)", build_ciao_source=build_crowdfunding_new_campaign_xsyntax),
    BenchmarkSpec("crowdfunding_contribute", "crowdfunding", "contribute/7", "O(N)", [5, 10, 20, 30, 40, 50], {4: 0, 6: 0}, build_crowdfunding_contribute, "N (Taille de l'état)", build_ciao_source=build_crowdfunding_contribute_xsyntax),
    BenchmarkSpec("crypto_buddy_init", "crypto_buddy", "init/6", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_crypto_buddy_init, "N (Taille des tokens)", build_ciao_source=build_crypto_buddy_init_xsyntax),
    BenchmarkSpec("crypto_buddy_approve", "crypto_buddy", "approve/9", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_crypto_buddy_approve, "N (Taille des tokens)", build_ciao_source=build_crypto_buddy_approve_xsyntax),
    # Fallback normalisé : helpers get_tok_bal/get_allow buggés en xsyntax natif.
    BenchmarkSpec("crypto_buddy_transferFrom", "crypto_buddy", "transferFrom/10", "O(N)", [5, 10, 20, 30, 40, 50], {6: 0, 7: 0}, build_crypto_buddy_transfer_from, "N (Taille de l'état)"),
    BenchmarkSpec("crypto_buddy_token_transfer", "crypto_buddy", "token_transfer/9", "O(N)", [5, 10, 20, 30, 40, 50], {5: 0}, build_crypto_buddy, "N (Taille de l'état)"),
    BenchmarkSpec("crypto_shark_init", "crypto_shark", "init/9", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_crypto_shark_init, "N (Taille des NFTs)", build_ciao_source=build_crypto_shark_init_xsyntax),
    BenchmarkSpec("crypto_shark_mint", "crypto_shark", "mint/14", "O(N)", [5, 10, 20, 30, 40, 50], {5: 0, 6: 0}, build_crypto_shark, "N (Taille de l'état)", build_ciao_source=build_crypto_shark_mint_xsyntax),
    BenchmarkSpec("crypto_shark_approve", "crypto_shark", "approve/15", "O(N)", [5, 10, 20, 30, 40, 50], {6: 0}, build_crypto_shark_approve, "N (Taille de l'état)", build_ciao_source=build_crypto_shark_approve_xsyntax),
    BenchmarkSpec("crypto_shark_setApprovalForAll", "crypto_shark", "setApprovalForAll/15", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_crypto_shark_set_approval_for_all, "N (Taille de l'état)", build_ciao_source=build_crypto_shark_setApprovalForAll_xsyntax),
    BenchmarkSpec("distributor_init", "distributor", "init/4", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_distributor_init, "N (Nombre de bénéficiaires)", build_ciao_source=build_distributor_init_xsyntax),
    BenchmarkSpec("distributor_add_as_payee", "distributor", "add_as_payee/5", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_distributor_add_as_payee, "N (Nombre de bénéficiaires)", build_ciao_source=build_distributor_add_as_payee_xsyntax),
    BenchmarkSpec("distributor_len_list", "distributor", "len_list/2", "O(N)", [10, 100, 200, 400, 600, 800, 1000], {1: 0}, build_distributor_len_list, "N (Nombre de bénéficiaires)", build_ciao_source=build_distributor_len_list_xsyntax),
    BenchmarkSpec("distributor_distribute", "distributor", "distribute/8", "O(N²)", [5, 10, 20, 30, 40, 50], {4: 0, 7: 0}, build_distributor, "N (Nombre de bénéficiaires)", build_ciao_source=build_distributor_distribute_xsyntax),
    BenchmarkSpec("example_coin_init", "example_coin", "init/9", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_example_coin_init, "N (Taille des tokens)", build_ciao_source=build_example_coin_init_xsyntax),
    # Fallback normalisé : helper get_tok_bal buggé en xsyntax natif.
    BenchmarkSpec("example_coin_token_transfer", "example_coin", "token_transfer/13", "O(N)", [5, 10, 20, 30, 40, 50], {8: 0}, build_example_coin, "N (Taille de l'état)"),
    BenchmarkSpec("example_coin_mint", "example_coin", "mint/13", "O(N)", [10, 50, 100, 150, 200, 250], {8: 0}, build_example_coin_mint, "N (Taille de l'état)"),
    BenchmarkSpec("example_coin_burn", "example_coin", "burn/13", "O(N)", [10, 50, 100, 150, 200, 250], {8: 0}, build_example_coin_burn, "N (Taille de l'état)"),
    BenchmarkSpec("example_erc721_init", "example_erc721", "init/7", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_example_erc721_init, "N (Taille des NFTs)", build_ciao_source=build_example_erc721_init_xsyntax),
    BenchmarkSpec("example_erc721_mint", "example_erc721", "mint/10", "O(N)", [10, 50, 100, 150, 200, 250], {5: 0, 6: 0}, build_example_erc721_mint, "N (Taille de l'état)", build_ciao_source=build_example_erc721_mint_xsyntax),
    BenchmarkSpec("example_erc721_transferFrom", "example_erc721", "transferFrom/12", "O(N)", [5, 10, 20, 30, 40, 50], {7: 0, 8: 0}, build_example_erc721, "N (Taille de l'état)", build_ciao_source=build_example_erc721_transferFrom_xsyntax),
    BenchmarkSpec("gradual_ponzi_init", "gradual_ponzi", "init/3", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_gradual_ponzi_init, "N (Nombre d'investisseurs)", build_ciao_source=build_gradual_ponzi_init_xsyntax),
    BenchmarkSpec("gradual_ponzi_invest", "gradual_ponzi", "invest/6", "O(N²)", [5, 10, 15, 20], {3: 0, 5: 0}, build_gradual_ponzi, "N (Nombre d'investisseurs)", build_ciao_source=build_gradual_ponzi_invest_xsyntax),
    BenchmarkSpec("shared_entity_init", "shared_entity", "init/5", "O(1)", [5, 10, 20, 30, 40, 50], {}, lambda n, b: build_shared_entity_init("shared_entity", n, b), "N (Nombre de parts)", build_ciao_source=build_shared_entity_init_xsyntax),
    # Fallback normalisé : helper get_share buggé en xsyntax natif.
    BenchmarkSpec("shared_entity_place_offer", "shared_entity", "place_offer/9", "O(N)", [10, 50, 100, 150, 200, 250], {4: 0}, lambda n, b: build_shared_entity("shared_entity", n, b), "N (Taille de l'état)"),
    BenchmarkSpec("simple_auction_init", "simple_auction", "init/8", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_simple_auction_init, "N (Taille de l'état)", build_ciao_source=build_simple_auction_init_xsyntax),
    BenchmarkSpec("simple_auction_bid", "simple_auction", "bid/13", "O(N)", [5, 10, 20, 30, 40, 50], {12: 0}, build_simple_auction_bid, "N (Taille de l'état)", build_ciao_source=build_simple_auction_bid_xsyntax),
    BenchmarkSpec("simple_auction_auction_end", "simple_auction", "auction_end/11", "O(N)", [5, 10, 20, 30, 40, 50], {10: 0}, build_simple_auction_end, "N (Taille de l'état)", build_ciao_source=build_simple_auction_end_xsyntax),
    BenchmarkSpec("simple_ponzi_init", "simple_ponzi", "init/3", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_simple_ponzi_init, "N (Taille de l'état)", build_ciao_source=build_simple_ponzi_init_xsyntax),
    BenchmarkSpec("simple_ponzi_invest", "simple_ponzi", "invest/8", "O(N)", [5, 10, 20, 30, 40, 50], {7: 0}, build_simple_ponzi, "N (Taille de l'état)", build_ciao_source=build_simple_ponzi_xsyntax),
    BenchmarkSpec("simple_pyramid_init", "simple_pyramid", "init/4", "O(1)", [5, 10, 20, 30, 40, 50], {}, build_simple_pyramid_init, "N (Nombre d'investisseurs)", build_ciao_source=build_simple_pyramid_init_xsyntax),
    BenchmarkSpec("simple_pyramid_invest", "simple_pyramid", "invest/8", "O(N²)", [5, 10, 20, 30, 40, 50], {3: 0, 7: 0}, build_simple_pyramid, "N (Nombre d'investisseurs)", build_ciao_source=build_simple_pyramid_invest_xsyntax),
    BenchmarkSpec("simple_shared_entity_init", "simple_shared_entity", "init/5", "O(1)", [5, 10, 20, 30, 40, 50], {}, lambda n, b: build_shared_entity_init("simple_shared_entity", n, b), "N (Nombre de parts)", build_ciao_source=build_simple_shared_entity_init_xsyntax),
    # Fallback normalisé : helper get_share buggé en xsyntax natif.
    BenchmarkSpec("simple_shared_entity_place_offer", "simple_shared_entity", "place_offer/9", "O(N)", [10, 50, 100, 150, 200, 250], {4: 0}, lambda n, b: build_shared_entity("simple_shared_entity", n, b), "N (Taille de l'état)"),
    # Fallback normalisé : helper get_board buggé en xsyntax natif.
    BenchmarkSpec("tictactoe_check_winner", "tictactoe", "check_winner/2", "O(N)", [5, 10, 20, 30, 40, 50], {1: 0}, build_tictactoe_check_winner, "N (Taille du plateau)"),
    BenchmarkSpec("tictactoe_init", "tictactoe", "init/11", "O(N)", [5, 10, 20, 30, 40, 50], {10: 0}, build_tictactoe_init, "N (Taille de l'état)", build_ciao_source=build_tictactoe_init_xsyntax),
]


FOCUSED_BENCHMARK_NAMES = {
    "distributor_distribute",
    "simple_pyramid_invest"
}


FOCUSED_BENCHMARKS = [spec for spec in ALL_BENCHMARKS if spec.name in FOCUSED_BENCHMARK_NAMES]
