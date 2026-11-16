"""Unit tests of src/ciaopp_cost (no ciaosh needed).

Run from the repository root:  python3 -m unittest tests.test_ciaopp_cost
"""
import tempfile
import unittest
from pathlib import Path

from src import ciaopp_cost as c

ROOT = Path(__file__).resolve().parent.parent


class CostExpression(unittest.TestCase):
    def test_nested_parentheses(self):
        a = ":- true pred p(A,B)\n   + cost(ub,gas,4*(length(A)+1)*length(B))."
        self.assertEqual(c._cost(a, "ub"), "4*(length(A)+1)*length(B)")

    def test_missing_kind(self):
        a = ":- true pred p(A)\n   + cost(ub,gas,length(A))."
        self.assertIsNone(c._cost(a, "lb"))

    def test_multiline_expression_is_joined(self):
        a = ":- true pred p(A)\n   + cost(ub,gas,length(A)\n      +2)."
        self.assertEqual(c._cost(a, "ub"), "length(A) +2")


class StripPrimitives(unittest.TestCase):
    PROGRAM = "\n".join([
        "get_bal(A,B,R) :-",
        "    loop_aux_1(B,A,0,R).",
        "loop_aux_1([],_,R,R).",
        "loop_aux_1([X|Xs],A,R0,R) :-",
        "    aux_cond_2(X,A,R0,R1),",
        "    loop_aux_1(Xs,A,R1,R).",
        "aux_cond_2(bal(A,V),A,_,V).",
        "aux_cond_2(_,_,R,R).",
        "bid(A,B,R) :-",
        "    get_bal(A,B,X),",
        "    aux_cond_3(X,R).",
        "aux_cond_3(X,X).",
    ])

    def test_removes_primitive_and_its_private_loops(self):
        body, removed = c.strip_primitives(self.PROGRAM, {"get_bal"})
        self.assertEqual(removed, ["aux_cond_2", "get_bal", "loop_aux_1"])
        self.assertIn("bid(A,B,R)", body)
        self.assertIn("aux_cond_3(X,X).", body)
        self.assertNotIn("loop_aux_1", body)

    def test_keeps_helper_shared_with_contract_code(self):
        program = self.PROGRAM + "\nwinner(B,R) :-\n    loop_aux_1(B,x,0,R)."
        body, removed = c.strip_primitives(program, {"get_bal"})
        self.assertEqual(removed, ["get_bal"])
        self.assertIn("loop_aux_1([],_,R,R).", body)


class Primitives(unittest.TestCase):
    def test_model_exports(self):
        names = c.primitives_of(ROOT / "data" / "ciaopp_cost" / "blockchain.pl")
        self.assertIn("transfer", names)
        self.assertIn("get_bal", names)

    def test_empty_export_list_is_an_error(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "blockchain.pl"
            f.write_text(":- module(blockchain, [], []).\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                c.primitives_of(f)


OUTPUT = """\
:- true pred bid(A,B)
   : ( atm(A), balances(B) )
   => ( atm(A), balances(B) )
   + cost(lb,gas,0).

:- true pred bid(A,B)
   : ( atm(A), balances(B) )
   => ( atm(A), balances(B) )
   + cost(ub,gas,8*length(B)+8).

:- true pred helper(A)
   : atm(A)
   => atm(A)
   + cost(ub,gas,1).
"""


class ExtractBounds(unittest.TestCase):
    def write(self, text):
        d = tempfile.TemporaryDirectory()
        self.addCleanup(d.cleanup)
        f = Path(d.name) / "x_co.pl"
        f.write_text(text, encoding="utf-8")
        return f

    def test_merges_lb_and_ub_of_one_call_pattern(self):
        bounds = c.extract_bounds(self.write(OUTPUT), ["bid"])
        self.assertEqual(len(bounds), 1)
        self.assertEqual((bounds[0].lb, bounds[0].ub), ("0", "8*length(B)+8"))
        self.assertEqual(bounds[0].call, "atm(A), balances(B)")

    def test_ignores_non_entry_predicates(self):
        bounds = c.extract_bounds(self.write(OUTPUT), ["bid"])
        self.assertEqual([b.pred for b in bounds], ["bid"])

    def test_conflicting_bounds_are_an_error(self):
        text = OUTPUT + OUTPUT.split("\n\n")[1].replace("8*length(B)+8", "inf") + "\n"
        with self.assertRaises(ValueError):
            c.extract_bounds(self.write(text), ["bid"])


class Status(unittest.TestCase):
    def test_status(self):
        self.assertEqual(c.status_of(c.CostResult("a", ok=True)), "OK")
        self.assertEqual(c.status_of(c.CostResult("a", ok=True, errors=["ERROR: x"])), "ERRORS")
        self.assertEqual(c.status_of(c.CostResult("a", ok=False)), "FAILED")

    def test_results_file_does_not_say_ok_with_errors(self):
        r = c.CostResult("a", ok=True, errors=["ERROR: x"])
        self.assertIn("=== a (ERRORS,", c.format_results([r], []))


if __name__ == "__main__":
    unittest.main()
