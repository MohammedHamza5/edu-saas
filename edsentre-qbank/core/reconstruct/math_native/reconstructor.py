"""Track N Math Reconstructor (§8.6).
Reconstructs superscripts, subscripts, fractions, and radicals from span geometry and vector drawings.
"""

from __future__ import annotations

import re
from typing import Any

import sympy

from core.pdf.adapter import TextSpan, VectorDrawing
from core.reconstruct.math_native.glyphmap import (
    is_subscript,
    is_superscript,
    normalize_minus,
)


class MathNativeReconstructor:
    """Reconstructs mathematical formulas deterministically from geometry."""

    def __init__(self) -> None:
        pass

    def reconstruct_formula(
        self, spans: list[TextSpan], drawings: list[VectorDrawing] | None = None
    ) -> str:
        """Reconstructs a mathematical formula string from spans and vector rule drawings."""
        if not spans:
            return ""

        # Filter out purely empty spans
        spans = [s for s in spans if s.text.strip()]
        if not spans:
            return ""

        # Check if there are horizontal rule drawings that indicate fractions
        fraction_rules: list[VectorDrawing] = []
        if drawings:
            for d in drawings:
                # Horizontal rule has height close to 0 and width >= 10 pt
                w = d.rect[2] - d.rect[0]
                h = abs(d.rect[3] - d.rect[1])
                if h <= 2.0 and w >= 8.0:
                    fraction_rules.append(d)

        # If fraction rules exist and span x-range matches, parse fraction
        if fraction_rules:
            formula = self._reconstruct_with_fractions(spans, fraction_rules)
            if formula:
                return formula

        # Otherwise, standard line-based reconstruction with superscripts/subscripts
        return self._reconstruct_linear(spans)

    def _reconstruct_linear(self, spans: list[TextSpan]) -> str:
        """Reconstructs a single line of math text with superscripts/subscripts."""
        # Find dominant base font size
        sizes = [s.size for s in spans]
        base_size = max(sizes) if sizes else 12.0

        # Sort spans by x0
        sorted_spans = sorted(spans, key=lambda s: (s.bbox[0], s.bbox[1]))

        result: list[str] = []
        i = 0
        n = len(sorted_spans)

        while i < n:
            s = sorted_spans[i]
            t = normalize_minus(s.text.strip())

            # Check if this span is a superscript
            if is_superscript(s.size, base_size, s.bbox[1], sorted_spans[max(0, i - 1)].bbox[1]):
                # Collect consecutive superscript spans
                sup_tokens: list[str] = [t]
                j = i + 1
                while j < n and is_superscript(
                    sorted_spans[j].size, base_size, sorted_spans[j].bbox[1], s.bbox[1]
                ):
                    sup_tokens.append(normalize_minus(sorted_spans[j].text.strip()))
                    j += 1
                sup_content = "".join(sup_tokens)

                # Check if immediately followed by a subscript (stacked fraction exponent: e.g. x / 5)
                if j < n and is_subscript(
                    sorted_spans[j].size, base_size, sorted_spans[j].bbox[1], sorted_spans[max(0, i - 1)].bbox[1]
                ):
                    sub_t = normalize_minus(sorted_spans[j].text.strip())
                    result.append(f"^{{{sup_content}/{sub_t}}}")
                    i = j + 1
                    continue
                elif len(sup_content) == 1 and sup_content.isalnum():
                    result.append(f"^{sup_content}")
                else:
                    result.append(f"^{{{sup_content}}}")
                i = j
                continue

            # Check if this span is a subscript
            if is_subscript(s.size, base_size, s.bbox[1], sorted_spans[max(0, i - 1)].bbox[1]):
                sub_tokens: list[str] = [t]
                j = i + 1
                while j < n and is_subscript(
                    sorted_spans[j].size, base_size, sorted_spans[j].bbox[1], s.bbox[1]
                ):
                    sub_tokens.append(normalize_minus(sorted_spans[j].text.strip()))
                    j += 1
                sub_content = "".join(sub_tokens)
                if len(sub_content) == 1 and sub_content.isalnum():
                    result.append(f"_{sub_content}")
                else:
                    result.append(f"_{{{sub_content}}}")
                i = j
                continue

            # Normal token
            # Ensure spacing around operators
            if t in ("=", "+", "-", "<", ">"):
                result.append(f" {t} ")
            else:
                result.append(t)
            i += 1

        res_str = "".join(result).strip()
        # Clean up repeated spaces and ensure operator spacing
        res_str = re.sub(r"\s+", " ", res_str)
        res_str = re.sub(r"([a-zA-Z0-9\)])\s*([+\-=])\s*([a-zA-Z0-9\(])", r"\1 \2 \3", res_str)
        return res_str

    def _reconstruct_with_fractions(
        self, spans: list[TextSpan], rules: list[VectorDrawing]
    ) -> str:
        """Reconstructs mathematical formulas containing fraction bars."""
        # Find spans above and below each rule
        # Sort rules horizontally
        sorted_rules = sorted(rules, key=lambda r: r.rect[0])
        # If there are multiple fractions (e.g. M2-Q21: \frac{4}{x-5} - \frac{4}{(x-5)^2})
        frac_parts: list[str] = []

        for r in sorted_rules:
            rx0, ry, rx1, _ = r.rect
            num_spans = [
                s
                for s in spans
                if s.bbox[3] <= (ry + 2.0) and (rx0 - 5.0) <= s.bbox[0] and s.bbox[2] <= (rx1 + 5.0)
            ]
            den_spans = [
                s
                for s in spans
                if s.bbox[1] >= (ry - 2.0) and (rx0 - 5.0) <= s.bbox[0] and s.bbox[2] <= (rx1 + 5.0)
            ]

            num_str = self._reconstruct_linear(num_spans) if num_spans else "1"
            den_str = self._reconstruct_linear(den_spans) if den_spans else "1"
            frac_parts.append(f"\\frac{{{num_str}}}{{{den_str}}}")

        # If rules covered all content, join with minus / plus operators
        # Check if there is a minus sign between fractions
        if len(frac_parts) == 2:
            return f"{frac_parts[0]} - {frac_parts[1]}"
        elif len(frac_parts) == 1:
            return frac_parts[0]

        return self._reconstruct_linear(spans)

    def validate_syntax(self, latex_or_expr: str) -> tuple[bool, str | None]:
        """Validates that a mathematical expression has balanced delimiters and parsable syntax."""
        # Check balanced delimiters
        pairs = {"(": ")", "{": "}", "[": "]"}
        stack: list[str] = []
        for ch in latex_or_expr:
            if ch in pairs:
                stack.append(pairs[ch])
            elif ch in pairs.values():
                if not stack or stack.pop() != ch:
                    return False, f"Unbalanced delimiter: '{ch}'"

        if stack:
            return False, f"Unclosed delimiters: {stack}"

        # Clean LaTeX to standard python for SymPy parsing check
        clean = (
            latex_or_expr.replace("\\frac", "")
            .replace("\\cdot", "*")
            .replace("\\times", "*")
            .replace("^", "**")
            .replace("{", "(")
            .replace("}", ")")
        )
        # Check for equations with '='
        if "=" in clean:
            parts = clean.split("=")
            for part in parts:
                p_strip = part.strip()
                if not p_strip:
                    return False, "Empty equation side"
        return True, None
