"""Sandboxed AI formalization solver and answer conflict resolution (§8.8, §11.1).

Enforces hard invariants:
1. AI formalization output is ALWAYS 'ai_proposed' with 'ai_formalization' source.
2. Sandboxed execution with zero network access and restricted builtins.
3. Conflict hierarchy:
   - key == solver => 'source_and_solver_agree'
   - key != solver => 'ANSWER_CONFLICT' (B-041 blocker)
   - AI vs key => key wins
   - deterministic solver only => 'solver_verified'
   - neither => 'unknown' (B-040 blocker)
"""

from __future__ import annotations

import ast
from dataclasses import dataclass, field
import math
from typing import Any, Literal

import sympy as sp

AnswerStatus = Literal[
    "unknown",
    "ai_proposed",
    "source_extracted",
    "solver_verified",
    "source_and_solver_agree",
    "teacher_confirmed",
    "conflict",
]


class SandboxedExecutionError(Exception):
    """Raised when sandbox code violates safety rules or fails execution."""


class SandboxedCodeRunner:
    """Safe runner for AI-generated SymPy code snippets (§11.1)."""

    FORBIDDEN_AST_NODES = (
        ast.Import,
        ast.ImportFrom,
        ast.Global,
        ast.Nonlocal,
    )
    FORBIDDEN_CALL_NAMES = frozenset({
        "open",
        "eval",
        "exec",
        "__import__",
        "globals",
        "locals",
        "getattr",
        "setattr",
        "delattr",
        "input",
        "compile",
        "exit",
        "quit",
    })

    @classmethod
    def validate_ast(cls, code_str: str) -> None:
        """Inspects AST to ensure no imports, OS calls, or malicious operations."""
        tree = ast.parse(code_str)
        for node in ast.walk(tree):
            if isinstance(node, cls.FORBIDDEN_AST_NODES):
                raise SandboxedExecutionError(f"Forbidden AST node in sandbox: {type(node).__name__}")
            if isinstance(node, ast.Call):
                func = node.func
                if isinstance(func, ast.Name) and func.id in cls.FORBIDDEN_CALL_NAMES:
                    raise SandboxedExecutionError(f"Forbidden function call in sandbox: {func.id}")
                if isinstance(func, ast.Attribute) and func.attr.startswith("__"):
                    raise SandboxedExecutionError(f"Forbidden dunder attribute access: {func.attr}")

    @classmethod
    def execute_sympy_program(cls, code_str: str) -> Any:
        """Executes pure SymPy code in an isolated dictionary namespace."""
        cls.validate_ast(code_str)

        safe_builtins: dict[str, Any] = {
            "abs": abs,
            "round": round,
            "min": min,
            "max": max,
            "sum": sum,
            "len": len,
            "float": float,
            "int": int,
            "range": range,
            "True": True,
            "False": False,
            "None": None,
        }

        sandbox_namespace: dict[str, Any] = {
            "__builtins__": safe_builtins,
            "sp": sp,
            "sympy": sp,
            "math": math,
            "Rational": sp.Rational,
            "Symbol": sp.Symbol,
            "symbols": sp.symbols,
            "Eq": sp.Eq,
            "solve": sp.solve,
            "pi": sp.pi,
            "sqrt": sp.sqrt,
            "simplify": sp.simplify,
        }

        compiled = compile(code_str, "<sandbox>", "exec")
        local_vars: dict[str, Any] = {}
        exec(compiled, sandbox_namespace, local_vars)

        # Check for expected output variables: 'result', 'answer', 'ans', 'sol'
        for out_key in ("result", "answer", "ans", "sol", "solution"):
            if out_key in local_vars:
                return local_vars[out_key]

        raise SandboxedExecutionError("Sandbox program executed successfully but did not set 'result' or 'answer'")


@dataclass
class AnswerCandidate:
    value: Any
    reader: str  # "ai_formalization" | "deterministic_solver" | "examview_key"
    confidence: float
    status: AnswerStatus
    code_evidence: str | None = None


@dataclass
class AnswerResolution:
    status: AnswerStatus
    raw_key: str | None
    normalized_value: Any
    accepted_equivalents: list[str] = field(default_factory=list)
    candidates: list[AnswerCandidate] = field(default_factory=list)
    conflict: bool = False
    conflict_details: str | None = None


class AISolver:
    """Interface for running AI formalization in sandbox."""

    def __init__(self, runner: type[SandboxedCodeRunner] = SandboxedCodeRunner):
        self.runner = runner

    def propose_solution(
        self,
        sympy_code: str,
        confidence: float = 0.85,
    ) -> AnswerCandidate:
        """Runs the program in the sandbox and ALWAYS produces 'ai_proposed' status."""
        val = self.runner.execute_sympy_program(sympy_code)
        # Convert SymPy expressions to readable numeric/string representations
        normalized = float(val.evalf()) if hasattr(val, "evalf") else val
        return AnswerCandidate(
            value=normalized,
            reader="ai_formalization",
            confidence=confidence,
            status="ai_proposed",  # INVARIANT: never verified without teacher confirmation
            code_evidence=sympy_code,
        )


class AnswerResolutionEngine:
    """
    Deterministic conflict resolver and status machine per §8.8 & §7.3.
    Resolves:
    - printed answer key (ExamView / native)
    - deterministic symbolic solver output (SymPy)
    - AI formalization solver output (Sandboxed)
    """

    @staticmethod
    def resolve(
        printed_key: str | None = None,
        solver_key: str | None = None,
        solver_numeric: float | None = None,
        ai_candidate: AnswerCandidate | None = None,
        options: list[dict[str, Any]] | None = None,
        question_type: str = "multiple_choice",
    ) -> AnswerResolution:
        candidates: list[AnswerCandidate] = []

        # 1. Register candidate from printed key
        if printed_key:
            candidates.append(
                AnswerCandidate(
                    value=printed_key.upper(),
                    reader="examview_key",
                    confidence=1.0,
                    status="source_extracted",
                )
            )

        # 2. Register candidate from deterministic solver
        if solver_key or solver_numeric is not None:
            s_val = solver_key.upper() if solver_key else solver_numeric
            candidates.append(
                AnswerCandidate(
                    value=s_val,
                    reader="deterministic_solver",
                    confidence=1.0,
                    status="solver_verified",
                )
            )

        # 3. Register candidate from AI formalization
        if ai_candidate:
            candidates.append(ai_candidate)

        # CASE A: Key and Deterministic Solver are both present
        if printed_key and solver_key:
            if printed_key.upper() == solver_key.upper():
                return AnswerResolution(
                    status="source_and_solver_agree",
                    raw_key=printed_key.upper(),
                    normalized_value=printed_key.upper(),
                    candidates=candidates,
                    conflict=False,
                )
            else:
                # CONFLICT: Key vs Solver mismatch -> B-041
                return AnswerResolution(
                    status="conflict",
                    raw_key=printed_key.upper(),
                    normalized_value=printed_key.upper(),
                    candidates=candidates,
                    conflict=True,
                    conflict_details=(
                        f"Printed key '{printed_key.upper()}' conflicts with "
                        f"deterministic solver result '{solver_key.upper()}'."
                    ),
                )

        # CASE B: Key present, no deterministic solver
        if printed_key:
            # AI vs Key: Key wins, AI candidate is kept as secondary
            return AnswerResolution(
                status="source_extracted",
                raw_key=printed_key.upper(),
                normalized_value=printed_key.upper(),
                candidates=candidates,
                conflict=False,
            )

        # CASE C: Deterministic solver present, no key (e.g. Trial August)
        if solver_key or solver_numeric is not None:
            norm_val = solver_key.upper() if solver_key else str(solver_numeric)
            raw = solver_key.upper() if solver_key else str(solver_numeric)
            equivalents: list[str] = []
            if solver_numeric is not None:
                # Add fractional or integer equivalents
                if solver_numeric.is_integer():
                    equivalents.append(str(int(solver_numeric)))
                equivalents.append(str(solver_numeric))

            return AnswerResolution(
                status="solver_verified",
                raw_key=raw,
                normalized_value=norm_val,
                accepted_equivalents=equivalents,
                candidates=candidates,
                conflict=False,
            )

        # CASE D: AI formalization only
        if ai_candidate:
            raw_ai = str(ai_candidate.value)
            return AnswerResolution(
                status="ai_proposed",  # INVARIANT: remains ai_proposed
                raw_key=raw_ai,
                normalized_value=ai_candidate.value,
                candidates=candidates,
                conflict=False,
            )

        # CASE E: Neither available
        return AnswerResolution(
            status="unknown",
            raw_key=None,
            normalized_value=None,
            candidates=candidates,
            conflict=False,
        )
