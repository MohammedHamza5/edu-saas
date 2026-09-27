"""Milestone M0 acceptance test suite.
Validates Forensics, Noise/Watermark detection, Key Parser, Composite Image merger, and SymPy solvers
against the two ground truth fixtures: solid_shapes.pdf and trail_august.pdf.
"""

from pathlib import Path

from core.answers.key_parser import ExamViewKeyParser
from core.answers.solver import SymbolicSolver
from core.forensics.analyzer import ForensicsAnalyzer
from core.noise.detector import NoiseDetector
from core.pdf.adapter import PdfDocumentAdapter

FIXTURES_DIR = Path(__file__).parent / "fixtures"
SOLID_SHAPES_PATH = FIXTURES_DIR / "solid_shapes.pdf"
TRAIL_AUGUST_PATH = FIXTURES_DIR / "trail_august.pdf"

# Golden answer key for Solid Shapes (from Appendix A.1)
GOLDEN_SOLID_KEYS = {
    1: "D",
    2: "D",
    3: "A",
    4: "D",
    5: "A",
    6: "D",
    7: "D",
    8: "B",
    9: "D",
    10: "B",
    11: "C",
    12: "C",
    13: "D",
    14: "C",
    15: "A",
    16: "C",
    17: "A",
    18: "A",
    19: "A",
    20: "A",
    21: "A",
    22: "A",
    23: "A",
    24: "D",
    25: "D",
    26: "D",
    27: "A",
    28: "A",
    29: "A",
    30: "A",
}


def test_trail_august_forensics_classification():
    """Verify Trial August has 16 pages: 2 cover pages and 14 native_vector pages."""
    assert TRAIL_AUGUST_PATH.exists(), f"Missing fixture: {TRAIL_AUGUST_PATH}"
    adapter = PdfDocumentAdapter(TRAIL_AUGUST_PATH)
    assert adapter.page_count == 16

    analyzer = ForensicsAnalyzer(adapter)
    doc_forensics = analyzer.analyze_document()

    # Pages 1 and 9 are cover pages ("Module 1", "Module 2")
    assert doc_forensics.pages[0].page_class == "cover"
    assert doc_forensics.pages[8].page_class == "cover"

    # All other 14 pages are native_vector
    for p_idx in [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]:
        page = doc_forensics.pages[p_idx]
        assert page.page_class == "native_vector", (
            f"Page {page.page_no} classified as {page.page_class}"
        )
        assert page.n_embedded_images == 0, f"Page {page.page_no} has embedded images"
        assert page.n_drawings > 0, f"Page {page.page_no} has no vector drawings"


def test_trail_august_noise_and_watermarks():
    """Verify watermark and noise detection on Trial August."""
    adapter = PdfDocumentAdapter(TRAIL_AUGUST_PATH)
    detector = NoiseDetector(adapter)

    # 1. Stem prefix signature detected across stems
    assert detector.stem_prefix_signature is not None
    assert "@abusat 760" in detector.stem_prefix_signature

    # 2. Rotated watermark detected on question pages
    rotated_pages = 0
    for p in range(adapter.page_count):
        noise_items = detector.detect_page_noise(p)
        has_rotated = any(n.kind == "rotated_watermark" for n in noise_items)
        if has_rotated:
            rotated_pages += 1

    # Rotated watermark appears on all 16 pages
    assert rotated_pages >= 14, (
        f"Only {rotated_pages} pages had rotated watermarks detected"
    )


def test_solid_shapes_forensics_classification():
    """Verify Solid Shapes has 9 pages: pp. 1-8 hybrid_raster, p. 9 native_text_only."""
    assert SOLID_SHAPES_PATH.exists(), f"Missing fixture: {SOLID_SHAPES_PATH}"
    adapter = PdfDocumentAdapter(SOLID_SHAPES_PATH)
    assert adapter.page_count == 9

    analyzer = ForensicsAnalyzer(adapter)
    doc_forensics = analyzer.analyze_document()

    # Pages 1-8 are hybrid_raster
    for p_idx in range(8):
        page = doc_forensics.pages[p_idx]
        assert page.page_class == "hybrid_raster", (
            f"Page {page.page_no} is {page.page_class}"
        )
        assert page.n_embedded_images > 0, f"Page {page.page_no} has no images"
        assert page.image_dpi_median is not None
        assert page.image_dpi_median >= 500, (
            f"DPI is {page.image_dpi_median} (expected ~600)"
        )

    # Page 9 is native_text_only with answer key
    page_9 = doc_forensics.pages[8]
    assert page_9.page_class == "native_text_only"
    assert page_9.has_answer_key_pattern is True
    assert page_9.n_embedded_images == 0


def test_solid_shapes_composite_image_merging():
    """Verify S-04: Merging adjacent slice images into composite regions."""
    adapter = PdfDocumentAdapter(SOLID_SHAPES_PATH)

    # Page 3 has 28 embedded slices
    p3_images = adapter.extract_embedded_images(2)  # 0-indexed page 3
    assert len(p3_images) >= 20, f"Expected >= 20 slices, found {len(p3_images)}"

    # After merging, composite regions should be significantly fewer
    composites = adapter.merge_composite_regions(p3_images)
    assert len(composites) < len(p3_images)
    assert len(composites) <= 15, f"Merged into {len(composites)} regions"


def test_solid_shapes_answer_key_parsing():
    """Verify 30/30 answer keys parsed from page 9 and match Appendix A.1 exactly."""
    adapter = PdfDocumentAdapter(SOLID_SHAPES_PATH)
    parser = ExamViewKeyParser(adapter)
    keys = parser.parse_all_keys()

    assert len(keys) == 30, f"Expected 30 keys, found {len(keys)}"

    for q_no, expected_key in GOLDEN_SOLID_KEYS.items():
        assert q_no in keys, f"Missing question {q_no} in parsed keys"
        assert keys[q_no].answer_key == expected_key, (
            f"Q{q_no} mismatch: expected {expected_key}, got {keys[q_no].answer_key}"
        )


def test_sympy_q21_verification_s16():
    """Verify S-16: SymPy verifies the conflict between hand calc SA and printed key."""
    result = SymbolicSolver.solve_solid_q21_verification()
    assert result["has_solver_key_conflict"] is True
    assert abs(result["sa_numeric_approx"] - 7652) < 20
    assert result["printed_key_value"] == 7666.6
