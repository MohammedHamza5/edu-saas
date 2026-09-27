"""
Validation rule registry — implements §9 Rule Catalog.

Each rule is a callable that receives a QuestionRevisionContent and
returns a list of ValidationIssue objects (empty = pass).

Rules are registered by rule_id and invoked by the ValidationRunner.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from core.models.issues import ValidationIssue

# Rule signature: (revision_content: dict) -> list[ValidationIssue]
RuleFn = Callable[[dict[str, Any]], list[ValidationIssue]]

_REGISTRY: dict[str, RuleFn] = {}


def register(rule_id: str) -> Callable[[RuleFn], RuleFn]:
    """Decorator: @register('B-004') def check_stem_empty(content): ..."""

    def decorator(fn: RuleFn) -> RuleFn:
        _REGISTRY[rule_id] = fn
        return fn

    return decorator


def get_rule(rule_id: str) -> RuleFn | None:
    return _REGISTRY.get(rule_id)


def all_rules() -> dict[str, RuleFn]:
    return dict(_REGISTRY)


@register("B-001")
def check_boundary_status(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-001 BLOCKER: Boundary status != confirmed."""
    confidence = content.get("confidence", {})
    boundary_conf = confidence.get("boundary", 1.0)
    flags = content.get("flags", [])
    if boundary_conf < 1.0 or any("boundary_ambiguous" in f for f in flags):
        return [
            ValidationIssue(
                rule_id="B-001",
                severity="BLOCKER",
                message={
                    "en": "Question boundary status is not confirmed.",
                    "ar": "حدود السؤال غير مؤكدة.",
                },
                resolvable_by="confirm",
            )
        ]
    return []


@register("B-004")
def check_stem_not_empty(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-004 BLOCKER: Stem empty or shorter than minimum after noise removal."""
    stem = content.get("stem", [])
    text_blocks = [b for b in stem if b.get("type") == "text"]
    total_chars = sum(len(b.get("value", "")) for b in text_blocks)

    if not stem:
        return [
            ValidationIssue(
                rule_id="B-004",
                severity="BLOCKER",
                message={"en": "Stem has no blocks", "ar": "السؤال لا يحتوي على نص"},
                resolvable_by="edit",
            )
        ]
    if text_blocks and total_chars < 5:
        return [
            ValidationIssue(
                rule_id="B-004",
                severity="BLOCKER",
                message={
                    "en": f"Stem text is too short ({total_chars} chars)",
                    "ar": "نص السؤال قصير جدًا",
                },
                resolvable_by="edit",
            )
        ]
    return []


@register("B-010")
def check_mcq_options(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-010 BLOCKER: MCQ options ≠ 4, duplicated, or out of order."""
    if content.get("question_type") != "multiple_choice":
        return []
    options = content.get("options", [])
    issues: list[ValidationIssue] = []

    if len(options) != 4:
        issues.append(
            ValidationIssue(
                rule_id="B-010",
                severity="BLOCKER",
                message={
                    "en": f"MCQ has {len(options)} options, expected 4",
                    "ar": "عدد الخيارات غير صحيح",
                },
                resolvable_by="edit",
            )
        )

    keys = [o.get("key", "") for o in options]
    if len(keys) != len(set(keys)):
        issues.append(
            ValidationIssue(
                rule_id="B-010",
                severity="BLOCKER",
                message={"en": "Duplicate option keys", "ar": "خيارات مكررة"},
                resolvable_by="edit",
            )
        )

    expected_order = ["A", "B", "C", "D"][: len(keys)]
    if keys != expected_order:
        issues.append(
            ValidationIssue(
                rule_id="B-010",
                severity="BLOCKER",
                message={
                    "en": f"Options out of order: {keys}",
                    "ar": "ترتيب الخيارات غير صحيح",
                },
                resolvable_by="edit",
            )
        )
    return issues


@register("B-011")
def check_image_clipping(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-011 BLOCKER: Option image clipped at border (SOURCE_TRUNCATED)."""
    flags = content.get("flags", [])
    if "source_truncated" in flags or "image_clipped" in flags:
        return [
            ValidationIssue(
                rule_id="B-011",
                severity="BLOCKER",
                message={
                    "en": "Option image is clipped at border (SOURCE_TRUNCATED).",
                    "ar": "صورة الخيار مقطوعة عند الحافة.",
                },
                resolvable_by="edit",
            )
        ]
    return []


@register("B-020")
def check_critical_token_diff(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-020 BLOCKER: Critical-token diff between readers on a block."""
    flags = content.get("flags", [])
    disputed_blocks = [f for f in flags if f.startswith("disputed_block:")]
    if disputed_blocks or "critical_token_diff" in flags:
        return [
            ValidationIssue(
                rule_id="B-020",
                severity="BLOCKER",
                message={
                    "en": f"Critical-token diff between readers: {disputed_blocks or 'disagreement'}",
                    "ar": "تباين في الرموز الحرجة بين القراء المستقلين.",
                },
                resolvable_by="edit",
            )
        ]
    return []


@register("B-021")
def check_math_parse_syntax(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-021 BLOCKER: Math parse failure / unbalanced delimiters."""
    flags = content.get("flags", [])
    if "math_syntax_error" in flags:
        return [
            ValidationIssue(
                rule_id="B-021",
                severity="BLOCKER",
                message={
                    "en": "Math parse failure: unbalanced delimiters or invalid syntax.",
                    "ar": "فشل في تحليل الصيغة الرياضية: أقواس غير متوازنة أو صيغة غير صالحة.",
                },
                resolvable_by="edit",
            )
        ]
    return []


@register("B-022")
def check_number_sign_missing(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-022 BLOCKER: Number/sign present in crop OCR but absent in LaTeX (or vice-versa)."""
    flags = content.get("flags", [])
    if "number_sign_mismatch" in flags:
        return [
            ValidationIssue(
                rule_id="B-022",
                severity="BLOCKER",
                message={
                    "en": "Number/sign present in crop OCR is absent in LaTeX representation.",
                    "ar": "رقم أو إشارة موجودة في الصورة ولكنها مفقودة في النص الرياضي.",
                },
                resolvable_by="edit",
            )
        ]
    return []


@register("B-023")
def check_pi_loss(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-023 BLOCKER: π/unit/superscript loss suspected (text layer lacks glyph seen in OCR)."""
    flags = content.get("flags", [])
    if "pi_loss_suspected" in flags or "pua_glyph_detected" in flags:
        return [
            ValidationIssue(
                rule_id="B-023",
                severity="BLOCKER",
                message={
                    "en": "π loss suspected: text layer lacks π glyph or uses PUA symbol.",
                    "ar": "اشتباه في فقدان رمز π في الطبقة النصية.",
                },
                resolvable_by="edit",
            )
        ]
    return []


@register("B-030")
def check_figure_missing(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-030 BLOCKER: FIGURE_MISSING (reference without bound asset)."""
    flags = content.get("flags", [])
    if "figure_missing" in flags:
        return [
            ValidationIssue(
                rule_id="B-030",
                severity="BLOCKER",
                message={
                    "en": "Stem refers to a figure/table but no visual asset is bound (FIGURE_MISSING).",
                    "ar": "نص السؤال يشير إلى رسم أو جدول ولكن لا يوجد رسم مرفق.",
                },
                resolvable_by="edit",
            )
        ]
    return []


@register("B-031")
def check_asset_third_party_mark(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-031 WARN: ASSET_THIRD_PARTY_MARK (URLs, handles, marketing marks)."""
    flags = content.get("flags", [])
    if any("third_party_mark" in f for f in flags):
        return [
            ValidationIssue(
                rule_id="B-031",
                severity="WARN",
                message={
                    "en": "Figure asset carries third-party watermark or handle (ASSET_THIRD_PARTY_MARK).",
                    "ar": "الرسم يحتوي على علامة مائية لطرف ثالث.",
                },
                resolvable_by="confirm",
            )
        ]
    return []


@register("B-032")
def check_meta_label_in_stem(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-032 WARN: META_LABEL_IN_STEM ('Text:', 'Table:')."""
    flags = content.get("flags", [])
    if any("meta_label_in_stem" in f for f in flags):
        return [
            ValidationIssue(
                rule_id="B-032",
                severity="WARN",
                message={
                    "en": "Stem or figure contains literal meta-labels ('Text:', 'Table:').",
                    "ar": "نص السؤال يحتوي على وسوم وصفية إضافية.",
                },
                resolvable_by="confirm",
            )
        ]
    return []


@register("B-051")
def check_reader_disagreement(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-051 WARN: READER_DISAGREEMENT on prose (typo-like)."""
    flags = content.get("flags", [])
    if any("reader_disagreement" in f for f in flags):
        return [
            ValidationIssue(
                rule_id="B-051",
                severity="WARN",
                message={
                    "en": "Reader disagreement on prose (possible source typo).",
                    "ar": "تباين في قراءة النص بين القراء (احتمال وجود خطأ إملائي أصلي).",
                },
                resolvable_by="confirm",
            )
        ]
    return []


@register("B-040")
def check_answer_status(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-040 BLOCKER: Answer unknown or ai_proposed — teacher must confirm."""
    answer = content.get("answer", {})
    status = answer.get("status", "unknown")
    if status in ("unknown", "ai_proposed"):
        return [
            ValidationIssue(
                rule_id="B-040",
                severity="BLOCKER",
                block_ref="answer",
                message={
                    "en": f'Answer status "{status}" requires teacher confirmation before publishing.',
                    "ar": f'حالة الإجابة "{status}" تتطلب مراجعة المدرس قبل النشر.',
                },
                resolvable_by="confirm",
            )
        ]
    return []


@register("B-042")
def check_mcq_answer_key_in_options(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-042 BLOCKER: MCQ answer key ∉ option keys."""
    if content.get("question_type") != "multiple_choice":
        return []
    answer = content.get("answer", {})
    raw_key = answer.get("raw")
    option_keys = {o.get("key") for o in content.get("options", [])}
    if raw_key and raw_key.upper() not in option_keys:
        return [
            ValidationIssue(
                rule_id="B-042",
                severity="BLOCKER",
                block_ref="answer",
                message={
                    "en": f'Answer key "{raw_key}" not in option keys {option_keys}',
                    "ar": f'مفتاح الإجابة "{raw_key}" غير موجود في الخيارات',
                },
                resolvable_by="edit",
            )
        ]
    return []


@register("B-060")
def check_source_refs(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-060 BLOCKER: Source not traceable — source_refs missing on stem blocks."""
    issues: list[ValidationIssue] = []
    for blk in content.get("stem", []):
        if not blk.get("source_refs"):
            issues.append(
                ValidationIssue(
                    rule_id="B-060",
                    severity="BLOCKER",
                    block_ref=blk.get("id"),
                    message={
                        "en": f"Block '{blk.get('id')}' has no source_refs — not traceable.",
                        "ar": "الكتلة لا تحتوي على مرجع مصدري — غير قابلة للتتبع.",
                    },
                    resolvable_by="none",
                )
            )
    return issues


@register("B-050")
def check_watermark_removed_flag(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-050 WARN: watermark_removed_from_text flag present (Trail August)."""
    flags = content.get("flags", [])
    if "watermark_removed_from_text" in flags:
        return [
            ValidationIssue(
                rule_id="B-050",
                severity="WARN",
                message={
                    "en": "Watermark was removed from stem text — verify stem is complete.",
                    "ar": "تم حذف العلامة المائية من النص — تحقق من اكتمال السؤال.",
                },
                resolvable_by="confirm",
            )
        ]
    return []


@register("B-033")
def check_unverified_figure_solving(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-033 BLOCKER: Figure data extracted (unverified) used for solving without visual match."""
    flags = content.get("flags", [])
    if "unverified_figure_solving" in flags:
        return [
            ValidationIssue(
                rule_id="B-033",
                severity="BLOCKER",
                block_ref="figure",
                message={
                    "en": "Unverified figure extraction data was used for solving without visual confirmation.",
                    "ar": "تم استخدام بيانات رسم غير مؤكدة للحل الرياضي دون مطابقة بصرية.",
                },
                resolvable_by="edit",
            )
        ]
    return []


@register("B-041")
def check_answer_conflict(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-041 BLOCKER: ANSWER_CONFLICT key vs solver (S-Q20, S-Q21)."""
    answer = content.get("answer", {})
    flags = content.get("flags", [])
    has_conflict = (
        answer.get("conflict") is True
        or answer.get("status") == "conflict"
        or "answer_conflict" in flags
        or "solver_key_conflict" in flags
    )
    if has_conflict:
        details = answer.get("conflict_details") or "Answer key conflicts with deterministic math solver result."
        return [
            ValidationIssue(
                rule_id="B-041",
                severity="BLOCKER",
                block_ref="answer",
                message={
                    "en": f"ANSWER_CONFLICT: {details}",
                    "ar": "تعارض بين مفتاح الإجابة الأصلي وحل المحرك الرياضي الدقيق.",
                },
                resolvable_by="confirm",
            )
        ]
    return []


@register("B-043")
def check_grid_in_normalization(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-043 BLOCKER: Grid-in without accepted-equivalents/normalization (T grid-ins)."""
    if content.get("question_type") != "grid_in":
        return []
    answer = content.get("answer", {})
    status = answer.get("status", "unknown")
    if status not in ("unknown", "ai_proposed"):
        resp = content.get("response", {})
        equiv = resp.get("equivalence")
        accepted = answer.get("accepted_equivalents", [])
        if not equiv or not accepted:
            return [
                ValidationIssue(
                    rule_id="B-043",
                    severity="BLOCKER",
                    block_ref="answer",
                    message={
                        "en": "Grid-in question lacks accepted equivalents or normalization schema.",
                        "ar": "سؤال الإجابة المباشرة يفتقر للمكافئات المقبولة أو مخطط المعادلة.",
                    },
                    resolvable_by="edit",
                )
            ]
    return []


@register("B-053")
def check_math_symbol_mix(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-053 WARN: PI/π mix in options; hyphen/U+2212 mix (S-Q11, S-Q23; T-10)."""
    flags = content.get("flags", [])
    issues: list[ValidationIssue] = []
    if "pi_literal_mix" in flags:
        issues.append(
            ValidationIssue(
                rule_id="B-053",
                severity="WARN",
                block_ref="options",
                message={
                    "en": "Mix of literal 'PI' and 'π' glyphs detected in options.",
                    "ar": "خلط بين رمز π والكلمة النصية PI في الخيارات.",
                },
                resolvable_by="confirm",
            )
        )
    if "mixed_minus_signs" in flags:
        issues.append(
            ValidationIssue(
                rule_id="B-053",
                severity="WARN",
                block_ref="stem",
                message={
                    "en": "Mix of ASCII hyphen '-' and Unicode minus '−' detected.",
                    "ar": "خلط بين إشارة الطرح ASCII وعلامة السالب الرياضية Unicode.",
                },
                resolvable_by="confirm",
            )
        )
    return issues


@register("B-070")
def check_rights_attestation(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-070 BLOCKER: Rights attestation missing at document level."""
    flags = content.get("flags", [])
    if "rights_attestation_missing" in flags:
        return [
            ValidationIssue(
                rule_id="B-070",
                severity="BLOCKER",
                message={
                    "en": "Document contains third-party marks but lacks rights attestation.",
                    "ar": "المستند يحتوي على علامات طرف ثالث ولكن يفتقر لإقرار حقوق الملكية.",
                },
                resolvable_by="confirm",
            )
        ]
    return []


@register("B-052")
def check_possible_duplicate(content: dict[str, Any]) -> list[ValidationIssue]:
    """B-052 WARN: possible_duplicate_of flag set."""
    flags = content.get("flags", [])
    dupe_flags = [f for f in flags if f.startswith("possible_duplicate_of:")]
    if dupe_flags:
        return [
            ValidationIssue(
                rule_id="B-052",
                severity="WARN",
                message={
                    "en": f"Possible duplicate detected: {dupe_flags}",
                    "ar": "سؤال محتمل التكرار — تحقق يدويًا.",
                },
                resolvable_by="confirm",
            )
        ]
    return []


class ValidationRunner:
    """Runs all registered rules against a revision content dict."""

    def run(self, content: dict[str, Any]) -> list[ValidationIssue]:
        all_issues: list[ValidationIssue] = []
        for rule_id, fn in _REGISTRY.items():
            all_issues.extend(fn(content))
        return all_issues

    def run_rule(self, rule_id: str, content: dict[str, Any]) -> list[ValidationIssue]:
        fn = get_rule(rule_id)
        if fn is None:
            raise KeyError(f"Unknown rule_id: {rule_id}")
        return fn(content)
