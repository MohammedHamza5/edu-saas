"""Symbolic math solver using SymPy for verification and equivalence checks (§8.8)."""

from __future__ import annotations

import re
from typing import Any

import sympy as sp


class SymbolicSolver:
    """Deterministic math solver and equivalence verifier."""

    @staticmethod
    def check_grid_in_equivalence(expr_a: str, expr_b: str) -> bool:
        """Verifies if two numeric/fractional answers are mathematically equivalent."""
        try:
            val_a = sp.sympify(expr_a.strip().replace(" ", ""))
            val_b = sp.sympify(expr_b.strip().replace(" ", ""))
            return bool(sp.simplify(val_a - val_b) == 0)
        except Exception:
            # Fallback to float comparison with tiny epsilon
            try:
                fa = float(eval(expr_a))
                fb = float(eval(expr_b))
                return abs(fa - fb) < 1e-6
            except Exception:
                return False

    @staticmethod
    def solve_solid_q20_verification() -> dict[str, Any]:
        """Verifies S-15: Solid Shapes Q20 calculation using SymPy.
        Statement context:
        A hemisphere with radius 29 inches. Find the volume.
        Volume of hemisphere = 2/3 * pi * r^3
        Options: a. 16259  b. 16260  c. 16261  d. 16262 (Printed Answer Key says A = 16259).
        """
        r = 29
        v_exact = sp.Rational(2, 3) * sp.pi * r**3
        v_val = float(v_exact)
        v_coeff = float(sp.Rational(2, 3) * r**3)

        key_value = 16259.0
        conflict = abs(v_val - key_value) > 1.0

        return {
            "r": r,
            "v_exact": str(v_exact),
            "v_numeric_approx": round(v_val, 4),
            "v_coefficient_of_pi": round(v_coeff, 4),
            "printed_key": "A",
            "printed_key_value": key_value,
            "has_solver_key_conflict": conflict,
            "discrepancy": round(v_val - key_value, 2),
            "conclusion": (
                f"Hemisphere volume is approximately {round(v_val, 1)} while printed key A is {key_value}. "
                "Printed options represent the pi-coefficient (16259.33) rather than actual volume. "
                "Flagged as ANSWER_CONFLICT (B-041)."
            ),
        }

    @staticmethod
    def solve_solid_q21_verification() -> dict[str, Any]:
        """Verifies S-16: Solid Shapes Q21 calculation using SymPy.
        Statement context:
        Sphere B has volume V_B = 20034 * pi.
        Volume of sphere = 4/3 * pi * r^3
        Surface area of sphere = 4 * pi * r^2
        """
        r = sp.symbols("r", positive=True, real=True)
        # 4/3 * pi * r^3 = 20034 * pi  =>  4/3 * r^3 = 20034  =>  r^3 = 20034 * 3 / 4 = 15025.5
        v_eq = sp.Eq(sp.Rational(4, 3) * r**3, 20034)
        r_sol = sp.solve(v_eq, r)[0]
        r_val = float(r_sol)

        # Surface Area = 4 * pi * r^2
        sa_exact = 4 * sp.pi * r_sol**2
        sa_val = float(sa_exact)
        sa_coeff = float(4 * r_sol**2)

        # Printed options in Q21:
        # a. 7666.6  b. 7555.5  c. 7444.4  d. 7333.3 (Answer Key says A = 7666.6)
        key_value = 7666.6

        conflict = abs(sa_val - key_value) > 1.0

        return {
            "r_exact": str(r_sol),
            "r_approx": round(r_val, 4),
            "sa_exact_with_pi": str(sa_exact),
            "sa_numeric_approx": round(sa_val, 4),
            "sa_coefficient_of_pi": round(sa_coeff, 4),
            "printed_key": "A",
            "printed_key_value": key_value,
            "has_solver_key_conflict": conflict,
            "discrepancy": round(sa_val - key_value, 2),
            "conclusion": (
                f"SA is approximately {round(sa_val, 1)} while printed key A is {key_value}. "
                "Synthetic ExamView options mismatch true geometric SA. Flagged as ANSWER_CONFLICT (B-041)."
            ),
        }

    @staticmethod
    def solve_quadratic_sum_of_solutions(a: float, b: float, c: float) -> float:
        """Computes sum of roots for a*x^2 + b*x + c = 0 via Vieta's formula: -b/a."""
        if a == 0:
            raise ValueError("Leading coefficient a cannot be zero in quadratic equation")
        return -b / a

    @staticmethod
    def solve_equation_for_variable(
        equation_str: str,
        var_name: str = "x",
        positive_only: bool = False,
    ) -> list[float]:
        """Solves a single-variable equation string (e.g. '7*(x - 4)**2 = 700' or '18*p - 19*p = 17')."""
        var = sp.Symbol(var_name)
        if "=" in equation_str:
            lhs_str, rhs_str = equation_str.split("=", 1)
        else:
            lhs_str, rhs_str = equation_str, "0"

        lhs = sp.sympify(lhs_str.strip())
        rhs = sp.sympify(rhs_str.strip())
        eq = sp.Eq(lhs, rhs)
        sols = sp.solve(eq, var)
        numeric_sols: list[float] = []
        for s in sols:
            try:
                val = float(s.evalf())
                if positive_only and val <= 0:
                    continue
                numeric_sols.append(val)
            except (TypeError, ValueError):
                continue
        return numeric_sols

    @staticmethod
    def evaluate_function(expr_str: str, var_name: str, val: float) -> float:
        """Evaluates an algebraic expression at a specified variable value (e.g. f(x)=16 - x/27 at x=270)."""
        var = sp.Symbol(var_name)
        expr = sp.sympify(expr_str.strip())
        result = expr.subs(var, val)
        return float(result.evalf())

    @staticmethod
    def solve_linear_system_2x2(
        eq1_str: str,
        eq2_str: str,
        var1: str = "x",
        var2: str = "y",
    ) -> dict[str, float]:
        """Solves a 2x2 linear system."""
        v1 = sp.Symbol(var1)
        v2 = sp.Symbol(var2)

        def to_eq(s: str) -> sp.Equality:
            if "=" in s:
                l, r = s.split("=", 1)
            else:
                l, r = s, "0"
            return sp.Eq(sp.sympify(l.strip()), sp.sympify(r.strip()))

        sol = sp.solve((to_eq(eq1_str), to_eq(eq2_str)), (v1, v2))
        if isinstance(sol, dict):
            return {str(k): float(v.evalf()) for k, v in sol.items()}
        elif isinstance(sol, list) and sol:
            first_sol = sol[0]
            if isinstance(first_sol, tuple):
                return {var1: float(first_sol[0].evalf()), var2: float(first_sol[1].evalf())}
        return {}

    @staticmethod
    def convert_units(amount: float, factor: float, multiply: bool = True) -> float:
        """Unit conversion helper (e.g. pedes to leugas, yards/hr to miles/hr)."""
        return amount * factor if multiply else amount / factor

    @staticmethod
    def match_numeric_to_mcq(
        target_val: float,
        options: dict[str, str],
        tolerance: float = 1e-2,
    ) -> str | None:
        """Finds which MCQ option matches the numeric target within tolerance."""
        for key, opt_text in options.items():
            # Extract numbers from option text
            clean = opt_text.replace(",", "").strip()
            # If option text is simple number
            try:
                val = float(clean)
                if abs(val - target_val) <= tolerance:
                    return key
            except ValueError:
                # Check for fractions e.g. "7/2"
                if "/" in clean:
                    try:
                        n, d = clean.split("/", 1)
                        if abs(float(n) / float(d) - target_val) <= tolerance:
                            return key
                    except ValueError:
                        pass
                # Check for tuples e.g. "(-1, 6)"
                t_match = re.findall(r"[-+]?\d*\.?\d+", clean)
                if len(t_match) == 1:
                    try:
                        val = float(t_match[0])
                        if abs(val - target_val) <= tolerance:
                            return key
                    except ValueError:
                        pass
        return None


class DeterministicSolver:
    """Deterministic question solver wrapping SymbolicSolver and question answer extraction."""

    def __init__(self, revision_content: Any) -> None:
        self.content = revision_content

    def solve(self) -> dict[str, Any]:
        """Attempts to resolve the question answer state."""
        if hasattr(self.content, "answer") and self.content.answer:
            if hasattr(self.content.answer, "model_dump"):
                ans = self.content.answer.model_dump()
                if ans.get("status") and ans["status"] != "unknown":
                    return ans
            elif isinstance(self.content.answer, dict):
                if self.content.answer.get("status") and self.content.answer["status"] != "unknown":
                    return self.content.answer

        return {
            "status": "unknown",
            "raw": None,
            "normalized": None,
            "accepted_equivalents": [],
            "candidates": [],
            "source_ref": None,
        }

