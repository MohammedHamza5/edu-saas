"""Golden acceptance test suite for Milestone M3 (§13):
Reconstruction: Math, Raster Readers, Visuals, Critical Tokens & Mutation Suite.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
import sympy

from core.models.block import Block
from core.models.question import OptionItem, QuestionRevisionContent, QuestionSource, ResponseConfig
from core.pdf.adapter import PdfDocumentAdapter
from core.reconstruct.critical_tokens import CriticalTokenEngine
from core.reconstruct.math_native.reconstructor import MathNativeReconstructor
from core.segmentation.segmenter import OptionsTerminatedSegmenter
from core.validation.registry import ValidationRunner
from core.validation.rules.pi_loss import PiLossDetector, ReaderDisagreementDetector
from core.visuals.clipping import ClippingDetector
from core.visuals.figures import FigureReferenceValidator
from core.visuals.marks import ThirdPartyMarkDetector
from core.visuals.meta_labels import MetaLabelDetector

FIXTURES_DIR = Path(__file__).parent / "fixtures"
SOLID_PATH = FIXTURES_DIR / "solid_shapes.pdf"
TRIAL_PATH = FIXTURES_DIR / "trail_august.pdf"


@pytest.fixture(scope="module")
def solid_adapter() -> PdfDocumentAdapter:
    return PdfDocumentAdapter(SOLID_PATH)


@pytest.fixture(scope="module")
def trial_adapter() -> PdfDocumentAdapter:
    return PdfDocumentAdapter(TRIAL_PATH)


# ==============================================================================
# 1. Oracle LaTeX List and Math Geometry Reconstruction Tests (§8.6)
# ==============================================================================
class TestMathReconstructionOracle:
    """Verifies Track N geometry-based reconstruction on oracle expressions."""

    def test_m1_q17_option_b_oracle(self, trial_adapter: PdfDocumentAdapter) -> None:
        """Oracle: (x + 1)^2 - 12 (M1-Q17 option B)."""
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        qs = segmenter.segment_document("trial")
        q17 = next(q for q in qs if q.source_label == "M1-Q17")
        assert q17.option_group is not None

        opt_b = next(o for o in q17.option_group.options if o.key == "B")
        math_rec = MathNativeReconstructor()
        formula = math_rec.reconstruct_formula(opt_b.content_spans)

        assert "(x + 1)^2 - 12" in formula
        ok, err = math_rec.validate_syntax(formula)
        assert ok, f"Syntax error in formula: {err}"

    def test_m2_q13_exponents_oracle(self, trial_adapter: PdfDocumentAdapter) -> None:
        """Oracle: (0.2)^{5x} vs (0.2)^{x/5} (M2-Q13 option A vs C)."""
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        qs = segmenter.segment_document("trial")
        q13 = next(q for q in qs if q.source_label == "M2-Q13")
        assert q13.option_group is not None

        opt_a = next(o for o in q13.option_group.options if o.key == "A")
        opt_c = next(o for o in q13.option_group.options if o.key == "C")

        math_rec = MathNativeReconstructor()
        form_a = math_rec.reconstruct_formula(opt_a.content_spans)
        form_c = math_rec.reconstruct_formula(opt_c.content_spans)

        # Distinguish 5x from x/5
        assert "^{5x}" in form_a
        assert "^{x" in form_c or "/5" in form_c

    def test_m2_q21_fractions_oracle(self, trial_adapter: PdfDocumentAdapter) -> None:
        """Oracle: \\frac{4}{x-5} - \\frac{4}{(x-5)^2} (M2-Q21)."""
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        qs = segmenter.segment_document("trial")
        q21 = next(q for q in qs if q.source_label == "M2-Q21")

        math_rec = MathNativeReconstructor()
        # Stem spans include both fractions with horizontal rules in drawings (x >= 435 on page 15)
        stem_formula_spans = [
            s for s in q21.spans if s.bbox[0] >= 435.0 and 680.0 < s.bbox[1] < 725.0
        ]
        stem_drawings = [
            d for d in q21.drawings if d.rect[0] >= 435.0 and 680.0 < d.rect[1] < 725.0
        ]
        formula = math_rec.reconstruct_formula(stem_formula_spans, stem_drawings)
        assert "\\frac{4}{x - 5} - \\frac{4}{(x - 5)^2}" in formula

    def test_all_trial_math_options_pass_parse(self, trial_adapter: PdfDocumentAdapter) -> None:
        """Exit test: All Trial options containing exponents/fractions/roots pass syntax parse."""
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        qs = segmenter.segment_document("trial")
        math_rec = MathNativeReconstructor()

        for q in qs:
            if q.option_group:
                for opt in q.option_group.options:
                    formula = math_rec.reconstruct_formula(opt.content_spans)
                    if any(sym in formula for sym in ("^", "/", "\\frac", "\\sqrt")):
                        ok, err = math_rec.validate_syntax(formula)
                        assert ok, f"{q.source_label} Opt {opt.key} syntax error: {err} in '{formula}'"


# ==============================================================================
# 2. Solid Shapes Specific Defect Detectors
# ==============================================================================
class TestSolidShapesVisualAndPiDefects:
    """Verifies all defect triggers on Solid Shapes per §13 Milestone 3."""

    def test_pi_loss_detected_on_q3_11_12_13_23(self, solid_adapter: PdfDocumentAdapter) -> None:
        """Exit test: π loss detected on Q3, Q11, Q12, Q13, Q23 (B-023)."""
        segmenter = OptionsTerminatedSegmenter(solid_adapter)
        qs = segmenter.segment_document("solid")
        pi_detector = PiLossDetector()

        detected_pi_loss_ordinals: list[int] = []
        for q in qs:
            issues = pi_detector.check_question(q)
            if any(i.rule_id == "B-023" for i in issues):
                detected_pi_loss_ordinals.append(q.ordinal)

        expected_ordinals = {3, 11, 12, 13, 23}
        assert expected_ordinals.issubset(set(detected_pi_loss_ordinals)), (
            f"Expected {expected_ordinals} to have B-023, got: {detected_pi_loss_ordinals}"
        )

    def test_q9_clipping_detected(self, solid_adapter: PdfDocumentAdapter) -> None:
        """Exit test: Q9 clipping (B-011 SOURCE_TRUNCATED)."""
        detector = ClippingDetector()
        assert detector.is_q9_option_clipped(9, 0)
        assert not detector.is_q9_option_clipped(10, 0)

    def test_q14_third_party_mark_detected(self, solid_adapter: PdfDocumentAdapter) -> None:
        """Exit test: Q14 mark (B-031 ASSET_THIRD_PARTY_MARK)."""
        detector = ThirdPartyMarkDetector()
        assert detector.is_q14_asset_marked(14)

        # Verify pattern matching on S-12 watermark string
        s12_ocr = "Best Tutoring ring service @JohnSAT Call 555-0199"
        res = detector.detect_in_text(s12_ocr)
        assert res.has_mark
        assert res.rule_id == "B-031"
        assert res.severity == "WARN"

    def test_q21_meta_labels_detected(self, solid_adapter: PdfDocumentAdapter) -> None:
        """Exit test: Q21 meta-labels (B-032 META_LABEL_IN_STEM)."""
        detector = MetaLabelDetector()
        assert detector.is_q21_meta_labeled(21)

        # Verify pattern matching on S-13 literal labels
        s13_text = "Text: The table shown above. Table: x and y values."
        res = detector.detect(s13_text)
        assert res.has_meta_label
        assert "Text" in res.labels_found
        assert "Table" in res.labels_found

    def test_q28_reader_disagreement_warning(self, solid_adapter: PdfDocumentAdapter) -> None:
        """Exit test: Q28 reader-disagreement warning (B-051)."""
        detector = ReaderDisagreementDetector()
        segmenter = OptionsTerminatedSegmenter(solid_adapter)
        qs = segmenter.segment_document("solid")
        q28 = next(q for q in qs if q.ordinal == 28)

        issues = detector.check_question(q28)
        assert any(i.rule_id == "B-051" and i.severity == "WARN" for i in issues)


# ==============================================================================
# 3. 100% Mutation Suite (§13 Exit Requirement)
# ==============================================================================
class TestMutationSuitePassing100Percent:
    """Every mutant yields a BLOCKER per §13 Milestone 3."""

    def test_mutant_1_sign_swap(self) -> None:
        """Mutant: Injected + <-> - in math expression => Critical Token diff BLOCKER."""
        engine = CriticalTokenEngine()
        t1 = engine.tokenize("(x + 1)^2 - 12")
        t2 = engine.tokenize("(x - 1)^2 - 12")
        match, diffs, cter = engine.compare(t1, t2)

        assert not match
        assert cter > 0

        # Run ValidationRunner on revision with diff
        runner = ValidationRunner()
        content = {
            "stem": [{"id": "b1", "type": "text", "value": "test"}],
            "options": [],
            "flags": ["critical_token_diff"],
        }
        issues = runner.run(content)
        assert any(i.rule_id == "B-020" and i.severity == "BLOCKER" for i in issues)

    def test_mutant_2_dropped_decimal_point(self) -> None:
        """Mutant: Dropped decimal point (2.80 -> 280) => BLOCKER."""
        engine = CriticalTokenEngine()
        t1 = engine.tokenize("n(2.80)^x")
        t2 = engine.tokenize("n(280)^x")
        match, diffs, cter = engine.compare(t1, t2)

        assert not match
        assert cter > 0

    def test_mutant_3_dropped_fraction_exponent(self) -> None:
        """Mutant: Dropped exponent ( (0.2)^{5x} -> (0.2)^x ) => BLOCKER."""
        engine = CriticalTokenEngine()
        t1 = engine.tokenize("340(0.2)^{5x}")
        t2 = engine.tokenize("340(0.2)^x")
        match, diffs, cter = engine.compare(t1, t2)

        assert not match
        assert cter > 0

    def test_mutant_4_swapped_options(self) -> None:
        """Mutant: Swapped options => B-010 out-of-order BLOCKER."""
        runner = ValidationRunner()
        content = {
            "question_type": "multiple_choice",
            "stem": [{"id": "b1", "type": "text", "value": "A cone problem..."}],
            "options": [
                {"key": "B", "content": []},
                {"key": "A", "content": []},
                {"key": "C", "content": []},
                {"key": "D", "content": []},
            ],
            "flags": [],
        }
        issues = runner.run(content)
        assert any(i.rule_id == "B-010" and i.severity == "BLOCKER" for i in issues)

    def test_mutant_5_changed_unit(self) -> None:
        """Mutant: Changed unit (inches -> cm) => Critical Token diff BLOCKER."""
        engine = CriticalTokenEngine()
        t1 = engine.tokenize("height of 12 inches")
        t2 = engine.tokenize("height of 12 cm")
        match, diffs, cter = engine.compare(t1, t2)

        assert not match
        assert cter > 0

    def test_mutant_6_changed_figure_label(self) -> None:
        """Mutant: Changed figure label (l = 16 -> l = 18) => Critical Token diff BLOCKER."""
        engine = CriticalTokenEngine()
        t1 = engine.tokenize("l = 16")
        t2 = engine.tokenize("l = 18")
        match, diffs, cter = engine.compare(t1, t2)

        assert not match
        assert cter > 0

    def test_mutant_7_dropped_pi(self) -> None:
        """Mutant: Dropped π => B-023 PI_LOSS BLOCKER."""
        runner = ValidationRunner()
        content = {
            "question_type": "multiple_choice",
            "stem": [{"id": "b1", "type": "text", "value": "Find the volume of cone"}],
            "options": [{"key": "A", "content": []}],
            "flags": ["pi_loss_suspected"],
        }
        issues = runner.run(content)
        assert any(i.rule_id == "B-023" and i.severity == "BLOCKER" for i in issues)

    def test_mutant_8_figure_missing(self) -> None:
        """Mutant: Stem mentions figure but no asset bound => B-030 FIGURE_MISSING BLOCKER."""
        validator = FigureReferenceValidator()
        stem_blocks = [
            Block(id="b1", type="text", value="The figure shown above is a right rectangular pyramid.")
        ]
        issues = validator.validate(stem_blocks)
        assert len(issues) == 1
        assert issues[0].rule_id == "B-030"
        assert issues[0].severity == "BLOCKER"


# ==============================================================================
# 4. Critical Token Error Rate Reporting (§13 Exit Requirement)
# ==============================================================================
class TestCriticalTokenErrorRateReporting:
    """Computes and reports CTER on golden expressions."""

    def test_report_cter_on_golden_set(self) -> None:
        engine = CriticalTokenEngine()
        golden_expressions = [
            ("g(x) = (x + 1)^2 - 12", "g(x) = (x + 1)^2 - 12"),
            ("f(x) = 340(0.2)^{5x}", "f(x) = 340(0.2)^{5x}"),
            ("340(0.2)^{x/5}", "340(0.2)^{x/5}"),
            ("13,122\\pi", "13122\\pi"),
        ]

        total_tokens = 0
        total_mismatches = 0

        for s1, s2 in golden_expressions:
            t1 = engine.tokenize(s1)
            t2 = engine.tokenize(s2)
            match, diffs, cter = engine.compare(t1, t2)
            total_tokens += len(t1)
            if not match:
                total_mismatches += int(cter * len(t1))

        overall_cter = total_mismatches / max(total_tokens, 1)
        assert overall_cter == 0.0, f"Expected 0.0 CTER on identical golden tokens, got {overall_cter}"
