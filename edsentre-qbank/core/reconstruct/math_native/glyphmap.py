"""Glyph and font mapping for Computer Modern / TeX fonts (§8.6).
Maps TeX font encoding and Unicode variants to canonical LaTeX and mathematical tokens.
"""

from __future__ import annotations

import re

# Mapping from Computer Modern / TeX font characters to LaTeX/Unicode
CM_FONT_PREFIXES = ("CMR", "CMMI", "CMSY", "CMEX", "CMBX", "CMTI")

# Mathematical symbols from CMSY / CMMI
SYMBOL_MAP: dict[str, str] = {
    "\u2212": "-",       # LaTeX minus to standard ASCII minus for comparison
    "\u2013": "-",       # En-dash used as minus
    "\u2014": "-",       # Em-dash
    "\u00d7": "\\times", # Multiplication sign
    "\u00f7": "\\div",   # Division sign
    "\u22c5": "\\cdot",  # Dot operator
    "\u2264": "\\le",    # Less than or equal
    "\u2265": "\\ge",    # Greater than or equal
    "\u2260": "\\neq",   # Not equal
    "\u2248": "\\approx",# Approximately equal
    "\u03c0": "\\pi",    # Greek small letter pi
    "\u221a": "\\sqrt",  # Square root
    "\u221e": "\\infty", # Infinity
}


def is_math_font(font_name: str) -> bool:
    """Returns True if the font is a TeX math font (CMMI, CMSY, CMEX)."""
    f_upper = font_name.upper()
    return any(p in f_upper for p in ("CMMI", "CMSY", "CMEX"))


def is_superscript(
    span_size: float,
    base_size: float,
    span_y0: float,
    base_y0: float,
    threshold_ratio: float = 0.75,
) -> bool:
    """Returns True if the span represents a superscript atom (§8.6).
    Size is <= 0.75 * base_size, and baseline is raised (y0 is smaller).
    """
    if span_size > threshold_ratio * base_size + 0.5:
        return False
    # In PDF coordinates, smaller y means higher up on page
    return span_y0 < (base_y0 + 1.0)


def is_subscript(
    span_size: float,
    base_size: float,
    span_y0: float,
    base_y0: float,
    threshold_ratio: float = 0.75,
) -> bool:
    """Returns True if the span represents a subscript atom."""
    if span_size > threshold_ratio * base_size + 0.5:
        return False
    return span_y0 > (base_y0 + 2.0)


def normalize_minus(text: str) -> str:
    """Normalizes all Unicode minus variants (U+2212, en-dash, hyphen) to ASCII '-'."""
    return (
        text.replace("\u2212", "-")
        .replace("\u2013", "-")
        .replace("\u2014", "-")
    )
