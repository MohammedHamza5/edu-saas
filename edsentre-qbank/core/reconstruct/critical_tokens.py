"""Critical Token Tokenizer and Consensus Diff Engine (§8.5, §9 B-020).
Decomposes expressions into mathematical tokens and computes deterministic consensus diffs.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass
from enum import Enum
from typing import Any

from core.reconstruct.math_native.glyphmap import normalize_minus


class TokenType(str, Enum):
    NUMBER = "number"
    SIGN = "sign"
    OPERATOR = "operator"
    VARIABLE = "variable"
    UNIT = "unit"
    GREEK = "greek"
    DELIMITER = "delimiter"
    EXPONENT = "exponent"
    FRACTION = "fraction"
    TEXT = "text"


@dataclass
class CriticalToken:
    kind: TokenType
    value: str
    raw: str
    position: int


class CriticalTokenEngine:
    """Extracts critical tokens and compares two reader streams."""

    UNITS = {
        "in", "in.", "inch", "inches", "cm", "cm.", "centimeter", "centimeters",
        "yard", "yards", "unit", "units", "in.3", "in^3", "cm^3", "%", "deg", "degrees"
    }

    OPERATORS = {"=", "+", "-", "*", "/", "^", "\\times", "\\cdot", "\\le", "\\ge", "\\approx", "\\neq"}
    DELIMITERS = {"(", ")", "[", "]", "{", "}"}

    def tokenize(self, text: str) -> list[CriticalToken]:
        """Tokenizes text or LaTeX into structured critical tokens."""
        text = unicodedata.normalize("NFKC", text)
        text = normalize_minus(text)

        tokens: list[CriticalToken] = []
        pos = 0

        # Pattern for fractions: \frac{num}{den}
        frac_re = re.compile(r"\\frac\{([^{}]+)\}\{([^{}]+)\}")
        # Pattern for exponents: \^\{([^}]+)\} or \^([0-9a-zA-Z])
        exp_re = re.compile(r"\^(?:\{([^}]+)\}|([0-9a-zA-Z]))")
        # Pattern for numbers: digits with optional decimal point and commas
        num_re = re.compile(r"\b\d+(?:,\d{3})*(?:\.\d+)?\b|\b\d+\.\d+\b|\b\.\d+\b")
        # Pattern for Greek letters / PI
        greek_re = re.compile(r"\\pi\b|\\theta\b|π|\bPI\b", re.IGNORECASE)

        # Regex-based scanning
        i = 0
        n = len(text)
        while i < n:
            # Skip whitespace
            if text[i].isspace():
                i += 1
                continue

            sub = text[i:]

            # 1. Fraction
            m_frac = frac_re.match(sub)
            if m_frac:
                raw = m_frac.group(0)
                num = m_frac.group(1).strip()
                den = m_frac.group(2).strip()
                tokens.append(
                    CriticalToken(
                        kind=TokenType.FRACTION,
                        value=f"{num}/{den}",
                        raw=raw,
                        position=pos,
                    )
                )
                i += len(raw)
                pos += 1
                continue

            # 2. Exponent
            m_exp = exp_re.match(sub)
            if m_exp:
                raw = m_exp.group(0)
                exp_val = m_exp.group(1) or m_exp.group(2)
                tokens.append(
                    CriticalToken(
                        kind=TokenType.EXPONENT,
                        value=exp_val.strip(),
                        raw=raw,
                        position=pos,
                    )
                )
                i += len(raw)
                pos += 1
                continue

            # 3. Greek / PI
            m_greek = greek_re.match(sub)
            if m_greek:
                raw = m_greek.group(0)
                tokens.append(
                    CriticalToken(
                        kind=TokenType.GREEK,
                        value="\\pi",
                        raw=raw,
                        position=pos,
                    )
                )
                i += len(raw)
                pos += 1
                continue

            # 4. Numbers
            m_num = num_re.match(sub)
            if m_num:
                raw = m_num.group(0)
                norm_num = raw.replace(",", "")
                tokens.append(
                    CriticalToken(
                        kind=TokenType.NUMBER,
                        value=norm_num,
                        raw=raw,
                        position=pos,
                    )
                )
                i += len(raw)
                pos += 1
                continue

            # 5. Units (words matching known unit list)
            m_word = re.match(r"\b[a-zA-Z%]+(?:\.[0-9]+)?\b", sub)
            if m_word:
                raw = m_word.group(0)
                if raw.lower() in self.UNITS:
                    tokens.append(
                        CriticalToken(
                            kind=TokenType.UNIT,
                            value=raw.lower(),
                            raw=raw,
                            position=pos,
                        )
                    )
                    i += len(raw)
                    pos += 1
                    continue
                elif len(raw) == 1 and raw.isalpha():
                    # Single variable (e.g. x, y, f, r)
                    tokens.append(
                        CriticalToken(
                            kind=TokenType.VARIABLE,
                            value=raw,
                            raw=raw,
                            position=pos,
                        )
                    )
                    i += len(raw)
                    pos += 1
                    continue
                else:
                    # General word
                    tokens.append(
                        CriticalToken(
                            kind=TokenType.TEXT,
                            value=raw.lower(),
                            raw=raw,
                            position=pos,
                        )
                    )
                    i += len(raw)
                    pos += 1
                    continue

            # 6. Signs and Operators
            ch = text[i]
            if ch in ("+", "-"):
                tokens.append(
                    CriticalToken(
                        kind=TokenType.SIGN,
                        value=ch,
                        raw=ch,
                        position=pos,
                    )
                )
                i += 1
                pos += 1
                continue

            if ch in self.OPERATORS:
                tokens.append(
                    CriticalToken(
                        kind=TokenType.OPERATOR,
                        value=ch,
                        raw=ch,
                        position=pos,
                    )
                )
                i += 1
                pos += 1
                continue

            if ch in self.DELIMITERS:
                tokens.append(
                    CriticalToken(
                        kind=TokenType.DELIMITER,
                        value=ch,
                        raw=ch,
                        position=pos,
                    )
                )
                i += 1
                pos += 1
                continue

            i += 1

        return tokens

    def compare(
        self, tokens1: list[CriticalToken], tokens2: list[CriticalToken]
    ) -> tuple[bool, list[str], float]:
        """Compares two token sequences. Returns (is_match, diff_messages, cter_error_rate)."""
        # Filter to critical tokens only (exclude generic delimiters or neutral text for mathematical consensus)
        crit1 = [t for t in tokens1 if t.kind in (TokenType.NUMBER, TokenType.SIGN, TokenType.VARIABLE, TokenType.EXPONENT, TokenType.FRACTION, TokenType.GREEK, TokenType.UNIT)]
        crit2 = [t for t in tokens2 if t.kind in (TokenType.NUMBER, TokenType.SIGN, TokenType.VARIABLE, TokenType.EXPONENT, TokenType.FRACTION, TokenType.GREEK, TokenType.UNIT)]

        mismatches: list[str] = []
        max_len = max(len(crit1), len(crit2))
        if max_len == 0:
            return True, [], 0.0

        mismatched_count = 0
        min_len = min(len(crit1), len(crit2))

        for k in range(min_len):
            t1 = crit1[k]
            t2 = crit2[k]
            if t1.kind != t2.kind or t1.value != t2.value:
                mismatches.append(
                    f"Position {k}: Reader1 '{t1.raw}' ({t1.kind.value}) != Reader2 '{t2.raw}' ({t2.kind.value})"
                )
                mismatched_count += 1

        # Excess tokens
        if len(crit1) != len(crit2):
            diff = abs(len(crit1) - len(crit2))
            mismatched_count += diff
            mismatches.append(f"Token count mismatch: Reader1 has {len(crit1)}, Reader2 has {len(crit2)}")

        cter_rate = mismatched_count / max_len
        is_match = (mismatched_count == 0)
        return is_match, mismatches, cter_rate
