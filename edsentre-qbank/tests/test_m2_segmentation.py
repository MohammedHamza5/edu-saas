"""Golden acceptance test suite for Milestone M2 (§13):
Structure, Segmentation & Track N Text.
"""

from __future__ import annotations

import copy
from pathlib import Path

import pytest

from core.models.issues import ValidationIssue
from core.pdf.adapter import PdfDocumentAdapter
from core.reconstruct.text_native import NativeTextReconstructor
from core.segmentation.duplicates import DuplicateDetector
from core.segmentation.models import ContinuationType, SegmentedQuestion
from core.segmentation.segmenter import OptionsTerminatedSegmenter
from core.segmentation.structure import StructureAnalyzer
from core.validation.document import DocumentValidator
from core.validation.registry import ValidationRunner

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
# 1. Solid Shapes Golden Segmentation Tests
# ==============================================================================
class TestSolidShapesGoldenSegmentation:
    """Golden exit criteria for Solid Shapes per §13 Milestone 2."""

    def test_solid_shapes_question_count_and_keys(
        self, solid_adapter: PdfDocumentAdapter
    ) -> None:
        """Exit criterion: 30 questions found; every question has 4 option keys A–D."""
        segmenter = OptionsTerminatedSegmenter(solid_adapter)
        questions = segmenter.segment_document("solid_test")

        assert len(questions) == 30, f"Expected 30 questions, found {len(questions)}"

        for q in questions:
            assert q.question_type == "multiple_choice"
            assert q.option_group is not None, f"Q{q.ordinal} missing option group"
            keys = [opt.key for opt in q.option_group.options]
            assert keys == ["A", "B", "C", "D"], f"Q{q.ordinal} option keys != A-D: {keys}"

    def test_solid_shapes_images_attached_per_s08(
        self, solid_adapter: PdfDocumentAdapter
    ) -> None:
        """Exit criterion: Figure/stem images attached per S-08 (above, below, or both).
        21 raster stems have images attached, 9 purely native text stems do not.
        """
        segmenter = OptionsTerminatedSegmenter(solid_adapter)
        questions = segmenter.segment_document("solid_test")

        questions_with_images = [q.ordinal for q in questions if len(q.images) > 0]
        # Per finding S-05: 21 stems are raster, only 3, 7, 11, 12, 19, 20, 22, 23, 26 have native text stems
        pure_text_ordinals = {3, 7, 11, 12, 19, 20, 22, 23, 26}
        expected_image_ordinals = set(range(1, 31)) - pure_text_ordinals

        assert len(questions_with_images) == 21, (
            f"Expected 21 questions with images, got {len(questions_with_images)}: {questions_with_images}"
        )
        assert set(questions_with_images) == expected_image_ordinals

        # Check Q9: has 5 composite regions (stem figure + 4 option images per S-11)
        q9 = next(q for q in questions if q.ordinal == 9)
        assert len(q9.images) == 5, f"Expected 5 images on Q9, got {len(q9.images)}"

    def test_solid_shapes_duplicate_clusters(
        self, solid_adapter: PdfDocumentAdapter
    ) -> None:
        """Exit criterion: Duplicate clusters {2,4}, {6,7}, {25,26} (+ 24/23 similarity noted)."""
        segmenter = OptionsTerminatedSegmenter(solid_adapter)
        questions = segmenter.segment_document("solid_test")

        detector = DuplicateDetector()
        clusters, similar_pairs = detector.detect_clusters(questions)

        cluster_sets = [c.ordinals for c in clusters]
        assert {2, 4} in cluster_sets, f"Cluster {{2, 4}} not found in {cluster_sets}"
        assert {6, 7} in cluster_sets, f"Cluster {{6, 7}} not found in {cluster_sets}"
        assert {25, 26} in cluster_sets, f"Cluster {{25, 26}} not found in {cluster_sets}"

        # Check similarity noted between 23 and 24
        sim_23_24 = any(
            (p.q1 == 23 and p.q2 == 24) or (p.q1 == 24 and p.q2 == 23)
            for p in similar_pairs
        )
        assert sim_23_24, "Similarity between Q23 and Q24 was not noted."

    def test_solid_shapes_structure_form_and_key(
        self, solid_adapter: PdfDocumentAdapter
    ) -> None:
        """Verify Form ID 'A' and 30-item answer key detected."""
        analyzer = StructureAnalyzer(solid_adapter)
        res = analyzer.analyze()

        assert res.form_id == "A"
        assert len(res.answer_key_pages) == 1
        assert res.answer_key_pages[0] == 8  # page 9 (0-indexed 8)
        assert len(res.sections) == 1
        assert res.sections[0].expected_count == 30


# ==============================================================================
# 2. Trial August Golden Segmentation Tests
# ==============================================================================
class TestTrialAugustGoldenSegmentation:
    """Golden exit criteria for Trial August per §13 Milestone 2."""

    def test_trial_august_counts_and_types(
        self, trial_adapter: PdfDocumentAdapter
    ) -> None:
        """Exit criterion:
        M1 = 22 (16 MCQ + 6 grid-in at ordinals 1, 9, 10, 12, 13, 18),
        M2 = 22 MCQ; all identities (section, ordinal) unique.
        """
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        questions = segmenter.segment_document("trial_test")

        assert len(questions) == 44, f"Expected 44 questions, got {len(questions)}"

        m1_qs = [q for q in questions if q.section == "M1"]
        m2_qs = [q for q in questions if q.section == "M2"]

        assert len(m1_qs) == 22, f"Expected M1=22, got {len(m1_qs)}"
        assert len(m2_qs) == 22, f"Expected M2=22, got {len(m2_qs)}"

        # Check grid-ins in M1
        m1_grid = [q.ordinal for q in m1_qs if q.question_type == "grid_in"]
        expected_grid = [1, 9, 10, 12, 13, 18]
        assert m1_grid == expected_grid, f"M1 grid-in ordinals mismatch: {m1_grid}"

        # Check MCQs in M1
        m1_mcq = [q.ordinal for q in m1_qs if q.question_type == "multiple_choice"]
        assert len(m1_mcq) == 16, f"Expected 16 MCQs in M1, got {len(m1_mcq)}"

        # Check M2 is 100% MCQ
        m2_mcq = [q.ordinal for q in m2_qs if q.question_type == "multiple_choice"]
        assert len(m2_mcq) == 22, f"Expected 22 MCQs in M2, got {len(m2_mcq)}"

        # Verify all identities (section, ordinal) are unique
        identities = [(q.section, q.ordinal) for q in questions]
        assert len(identities) == len(set(identities)), "Duplicate (section, ordinal) identities!"

    def test_trial_august_exact_four_cross_page_merges(
        self, trial_adapter: PdfDocumentAdapter
    ) -> None:
        """Exit criterion:
        4 cross-page merges exactly:
        - M1-Q6 p3→4
        - M1-Q13 p5→6
        - M2-Q15 p13→14
        - M2-Q21 p15→16
        Zero false merges.
        """
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        questions = segmenter.segment_document("trial_test")

        cross_page = [q for q in questions if len(q.pages) > 1]
        assert len(cross_page) == 4, f"Expected exactly 4 cross-page merges, found {len(cross_page)}"

        labels = [cp.source_label for cp in cross_page]
        assert labels == ["M1-Q6", "M1-Q13", "M2-Q15", "M2-Q21"], (
            f"Unexpected cross-page labels: {labels}"
        )

        q_map = {q.source_label: q for q in cross_page}

        # 1. M1-Q6: stem p3 -> options p4
        assert q_map["M1-Q6"].pages == [3, 4]
        assert q_map["M1-Q6"].continuation_type == ContinuationType.STEM_TO_OPTIONS
        assert q_map["M1-Q6"].boundary_status == "confirmed"

        # 2. M1-Q13: label + figure p5 -> stem text p6
        assert q_map["M1-Q13"].pages == [5, 6]
        assert q_map["M1-Q13"].continuation_type == ContinuationType.FIGURE_TO_STEM
        assert q_map["M1-Q13"].boundary_status == "confirmed"

        # 3. M2-Q15: table p13 -> stem p14
        assert q_map["M2-Q15"].pages == [13, 14]
        assert q_map["M2-Q15"].boundary_status == "confirmed"

        # 4. M2-Q21: split option list (A on p15, B–D on p16)
        assert q_map["M2-Q21"].pages == [15, 16]
        assert q_map["M2-Q21"].continuation_type == ContinuationType.SPLIT_OPTION_LIST
        assert q_map["M2-Q21"].boundary_status == "confirmed"
        assert q_map["M2-Q21"].option_group is not None
        assert [m.key for m in q_map["M2-Q21"].option_group.options] == ["A", "B", "C", "D"]

        # Assert all single-page questions have exactly 1 page (zero false merges)
        single_page = [q for q in questions if len(q.pages) == 1]
        assert len(single_page) == 40


# ==============================================================================
# 3. Track N Native Text Reconstruction Tests
# ==============================================================================
class TestTrackNNativeReconstruction:
    """Verifies canonical QuestionRevisionContent generation from segmented questions."""

    def test_reconstruct_m1_q6(self, trial_adapter: PdfDocumentAdapter) -> None:
        """Test cross-page MCQ reconstruction (M1-Q6)."""
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        questions = segmenter.segment_document("trial_test")
        q6 = next(q for q in questions if q.source_label == "M1-Q6")

        reconstructor = NativeTextReconstructor(trial_adapter)
        rev = reconstructor.reconstruct(q6)

        assert rev.source.section == "M1"
        assert rev.source.ordinal == 6
        assert rev.source.pages == [3, 4]
        assert rev.question_type == "multiple_choice"
        assert len(rev.options) == 4

        # Verify source_refs on every block
        for b in rev.stem:
            assert len(b.source_refs) > 0

        for opt in rev.options:
            assert len(opt.source_refs) > 0
            for b in opt.content:
                assert len(b.source_refs) > 0

    def test_reconstruct_m1_q1_grid_in(self, trial_adapter: PdfDocumentAdapter) -> None:
        """Test Grid-in reconstruction (M1-Q1)."""
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        questions = segmenter.segment_document("trial_test")
        q1 = next(q for q in questions if q.source_label == "M1-Q1")

        reconstructor = NativeTextReconstructor(trial_adapter)
        rev = reconstructor.reconstruct(q1)

        assert rev.source.section == "M1"
        assert rev.source.ordinal == 1
        assert rev.question_type == "grid_in"
        assert len(rev.options) == 0
        assert rev.response.type == "numeric"


# ==============================================================================
# 4. Mutation Tests for Section Count (B-003) and Key Count (B-042)
# ==============================================================================
class TestDocumentValidationMutations:
    """Mutation suite: ensures B-003, B-042, and B-001 fire correctly when fixtures are corrupted."""

    def test_clean_trial_document_passes_validation(
        self, trial_adapter: PdfDocumentAdapter
    ) -> None:
        """Clean document yields 0 document-level blocker issues."""
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        questions = segmenter.segment_document("trial_test")
        struct = segmenter.structure_analyzer.analyze()

        validator = DocumentValidator()
        issues = validator.validate_document(questions, struct)
        blockers = [i for i in issues if i.severity == "BLOCKER"]
        assert len(blockers) == 0, f"Unexpected blockers on clean document: {blockers}"

    def test_mutation_b003_ordinal_gap(
        self, trial_adapter: PdfDocumentAdapter
    ) -> None:
        """Mutant: Drop question 3 from M1 -> B-003 blocker MUST fire."""
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        questions = segmenter.segment_document("trial_test")
        struct = segmenter.structure_analyzer.analyze()

        # Mutate: remove Q3 from M1
        mutated_questions = [
            q for q in questions if not (q.section == "M1" and q.ordinal == 3)
        ]

        validator = DocumentValidator()
        issues = validator.validate_document(mutated_questions, struct)
        b003_issues = [i for i in issues if i.rule_id == "B-003"]

        assert len(b003_issues) > 0, "B-003 failed to detect dropped question in M1!"

    def test_mutation_b003_repeated_ordinal(
        self, trial_adapter: PdfDocumentAdapter
    ) -> None:
        """Mutant: Duplicate question 5 in M1 -> B-003 blocker MUST fire."""
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        questions = segmenter.segment_document("trial_test")
        struct = segmenter.structure_analyzer.analyze()

        # Mutate: duplicate Q5
        q5 = next(q for q in questions if q.section == "M1" and q.ordinal == 5)
        mutated_questions = list(questions) + [copy.deepcopy(q5)]

        validator = DocumentValidator()
        issues = validator.validate_document(mutated_questions, struct)
        b003_issues = [i for i in issues if i.rule_id == "B-003"]

        assert len(b003_issues) > 0, "B-003 failed to detect duplicate ordinal in M1!"

    def test_mutation_b003_section_count_mismatch(
        self, solid_adapter: PdfDocumentAdapter
    ) -> None:
        """Mutant: Section count mismatch (e.g. 29 questions when 30 expected) -> B-003 fires."""
        segmenter = OptionsTerminatedSegmenter(solid_adapter)
        questions = segmenter.segment_document("solid_test")
        struct = segmenter.structure_analyzer.analyze()

        # Mutate: drop question 30
        mutated_questions = [q for q in questions if q.ordinal != 30]

        validator = DocumentValidator()
        issues = validator.validate_document(mutated_questions, struct)
        b003_issues = [i for i in issues if i.rule_id == "B-003"]

        assert len(b003_issues) > 0, "B-003 failed to detect count mismatch in Solid Shapes!"

    def test_mutation_b042_key_count_mismatch(
        self, solid_adapter: PdfDocumentAdapter
    ) -> None:
        """Mutant: Answer key count != questions count -> B-042 blocker MUST fire."""
        segmenter = OptionsTerminatedSegmenter(solid_adapter)
        questions = segmenter.segment_document("solid_test")
        struct = segmenter.structure_analyzer.analyze()

        validator = DocumentValidator()
        # Injected key_count = 28 (questions count is 30)
        issues = validator.validate_document(questions, struct, key_count=28)
        b042_issues = [i for i in issues if i.rule_id == "B-042"]

        assert len(b042_issues) > 0, "B-042 failed to detect answer key count mismatch!"

    def test_mutation_b001_unconfirmed_boundary(
        self, trial_adapter: PdfDocumentAdapter
    ) -> None:
        """Mutant: Question boundary_status is 'probable' instead of 'confirmed' -> B-001 fires."""
        segmenter = OptionsTerminatedSegmenter(trial_adapter)
        questions = segmenter.segment_document("trial_test")
        struct = segmenter.structure_analyzer.analyze()

        # Mutate: mark M1-Q6 as probable
        mutated_questions = []
        for q in questions:
            if q.source_label == "M1-Q6":
                q_copy = copy.deepcopy(q)
                q_copy.boundary_status = "probable"
                mutated_questions.append(q_copy)
            else:
                mutated_questions.append(q)

        validator = DocumentValidator()
        issues = validator.validate_document(mutated_questions, struct)
        b001_issues = [i for i in issues if i.rule_id == "B-001"]

        assert len(b001_issues) > 0, "B-001 failed to detect unconfirmed boundary status!"
