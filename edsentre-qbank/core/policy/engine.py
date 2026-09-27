"""Policy engine: decides question triage status and review priority score (§8.9, §9, §10, §11.4)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

from core.models.issues import ValidationIssue

PolicyState = Literal[
    "BLOCKED",
    "REVIEW_TARGETED",
    "REVIEW_FAST",
    "SOURCE_UNREADABLE",
    "MACHINE_CLEARED",
]

TriageStatus = Literal[
    "ok",
    "review_required",
    "quarantined",
]

BLOCK_TYPE_WEIGHTS: dict[str, float] = {
    "math": 4.0,
    "answer": 3.0,
    "figure": 2.0,
    "text": 1.0,
    "document": 1.0,
}

SEVERITY_WEIGHTS: dict[str, float] = {
    "BLOCKER": 10.0,
    "WARN": 3.0,
    "INFO": 1.0,
}

# Rules that indicate the source itself cannot be reliably read/reconstructed
UNREADABLE_RULES = frozenset({"B-011", "B-060", "B-033"})


@dataclass
class PolicyDecision:
    policy_state: PolicyState
    status: TriageStatus
    priority_score: float
    blockers: list[ValidationIssue]
    warnings: list[ValidationIssue]
    infos: list[ValidationIssue]
    summary_en: str
    summary_ar: str
    is_machine_cleared_eligible: bool = False
    machine_cleared_disabled_reason: str | None = None
    priority_breakdown: dict[str, float] = field(default_factory=dict)


class PolicyEngine:
    """
    Evaluates validation issues and produces a triage decision + priority score.
    Does NOT touch the database — pure logic layer.
    """

    @staticmethod
    def infer_block_type(issue: ValidationIssue) -> str:
        """Determines the academic domain of an issue: math > answer > figure > text."""
        ref = (issue.block_ref or "").lower()
        if "math" in ref or issue.rule_id in ("B-020", "B-021", "B-022", "B-023", "B-053"):
            return "math"
        if "answer" in ref or issue.rule_id in ("B-040", "B-041", "B-042", "B-043"):
            return "answer"
        if "figure" in ref or "image" in ref or issue.rule_id in ("B-011", "B-030", "B-031", "B-032", "B-033"):
            return "figure"
        return "text"

    def calculate_priority_score(self, issues: list[ValidationIssue]) -> tuple[float, dict[str, float]]:
        """
        Calculates review queue priority:
        priority_score = sum(severity_weight * block_type_weight)
        Ordering: math (4.0) > answer (3.0) > figure (2.0) > text (1.0).
        """
        total_score = 0.0
        breakdown: dict[str, float] = {"math": 0.0, "answer": 0.0, "figure": 0.0, "text": 0.0}

        for issue in issues:
            b_type = self.infer_block_type(issue)
            b_weight = BLOCK_TYPE_WEIGHTS.get(b_type, 1.0)
            s_weight = SEVERITY_WEIGHTS.get(issue.severity, 1.0)
            score = b_weight * s_weight
            total_score += score
            breakdown[b_type] = breakdown.get(b_type, 0.0) + score

        return round(total_score, 2), breakdown

    def evaluate(self, issues: list[ValidationIssue]) -> PolicyDecision:
        blockers = [i for i in issues if i.severity == "BLOCKER"]
        warnings = [i for i in issues if i.severity == "WARN"]
        infos = [i for i in issues if i.severity == "INFO"]

        priority_score, breakdown = self.calculate_priority_score(issues)

        # 1. Source Unreadable / Quarantined
        unreadable_hits = [b for b in blockers if b.rule_id in UNREADABLE_RULES]
        if unreadable_hits:
            rule_ids = [u.rule_id for u in unreadable_hits]
            return PolicyDecision(
                policy_state="SOURCE_UNREADABLE",
                status="quarantined",
                priority_score=priority_score,
                blockers=blockers,
                warnings=warnings,
                infos=infos,
                summary_en=f"Source unreadable / quarantined: {rule_ids}",
                summary_ar=f"المصدر غير قابل للقراءة أو محجور: {rule_ids}",
                priority_breakdown=breakdown,
            )

        # 2. Blocked
        if blockers:
            return PolicyDecision(
                policy_state="BLOCKED",
                status="review_required",
                priority_score=priority_score,
                blockers=blockers,
                warnings=warnings,
                infos=infos,
                summary_en=f"BLOCKED: {len(blockers)} blocker(s), {len(warnings)} warning(s) — human review required",
                summary_ar=f"محظور: {len(blockers)} حاجز، {len(warnings)} تحذير — يتطلب مراجعة بشرية",
                priority_breakdown=breakdown,
            )

        # 3. Review Targeted (only warnings)
        if warnings:
            return PolicyDecision(
                policy_state="REVIEW_TARGETED",
                status="review_required",
                priority_score=priority_score,
                blockers=[],
                warnings=warnings,
                infos=infos,
                summary_en=f"REVIEW_TARGETED: {len(warnings)} warning(s) require teacher attention",
                summary_ar=f"مراجعة موجهة: {len(warnings)} تحذير يتطلب انتباه المدرس",
                priority_breakdown=breakdown,
            )

        # 4. Clean (Zero blockers, Zero warnings) -> REVIEW_FAST
        # Check machine-cleared eligibility (§11.4)
        is_mc_eligible = len(issues) == 0
        mc_reason = (
            "Machine-cleared mode is disabled in V1 (§11.4 / §12 non-goals). All questions require teacher review."
        )

        return PolicyDecision(
            policy_state="REVIEW_FAST",
            status="ok",
            priority_score=priority_score,
            blockers=[],
            warnings=[],
            infos=infos,
            summary_en="REVIEW_FAST: Clean item — fast teacher approval eligible",
            summary_ar="مراجعة سريعة: عنصر سليم وجاهز للاعتماد السريع",
            is_machine_cleared_eligible=is_mc_eligible,
            machine_cleared_disabled_reason=mc_reason,
            priority_breakdown=breakdown,
        )
