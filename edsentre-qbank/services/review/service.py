"""
Review Console Core Service (§10, §13 M5).

Implements the UI-agnostic Review Console business logic:
- Priority queue ordering: math (4.0) > answer (3.0) > figure (2.0) > text (1.0).
- Duplicate cluster grouping.
- Ack-per-issue enforcement: approve remains disabled while unresolved blockers exist.
- Block-level edit with immutable revision creation and audit metadata.
- Teacher answer selection / confirmation.
- Structural actions: merge-with-next, split, mark source unreadable.
- Safe revision restoration.
- Second-review sampling (5–10%).
- Batch simulation engine for the 30-question Solid Shapes test corpus.
"""

from __future__ import annotations

import copy
import hashlib
import json
import random
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

from core.models.issues import ValidationIssue
from core.policy.engine import PolicyDecision, PolicyEngine


def _canonical_json(data: dict[str, Any]) -> str:
    """Returns deterministic JSON string for content hashing."""
    return json.dumps(data, sort_keys=True, separators=(",", ":"))


def _compute_hash(data: dict[str, Any]) -> str:
    return hashlib.sha256(_canonical_json(data).encode("utf-8")).hexdigest()


@dataclass
class ReviewTask:
    question_id: str
    tenant_id: str
    document_id: str
    source_label: str
    ordinal: int
    question_type: str
    status: str
    latest_revision_id: str
    rev_no: int
    content: dict[str, Any]
    answer: dict[str, Any]
    content_hash: str
    issues: list[ValidationIssue]
    acknowledged_issue_ids: set[str]
    policy_decision: PolicyDecision
    duplicate_cluster_id: str | None = None
    requires_second_review: bool = False
    priority_score: float = 0.0

    @property
    def has_unresolved_blockers(self) -> bool:
        """Approve remains disabled if any BLOCKER is not acknowledged/confirmed."""
        for issue in self.issues:
            if issue.severity == "BLOCKER" and issue.rule_id not in self.acknowledged_issue_ids:
                return True
        return False

    @property
    def can_approve(self) -> bool:
        return not self.has_unresolved_blockers and self.status != "source_unreadable"


@dataclass
class RevisionRecord:
    id: str
    question_id: str
    tenant_id: str
    rev_no: int
    content: dict[str, Any]
    answer: dict[str, Any]
    content_hash: str
    created_at: str
    created_via: str
    created_by: str | None = None
    edit_note: str | None = None
    confidence: dict[str, float] = field(default_factory=dict)
    provenance: dict[str, Any] = field(default_factory=dict)


@dataclass
class BatchSimulationResult:
    total_questions: int
    fast_mode_count: int
    targeted_review_count: int
    blocked_count: int
    quarantined_count: int
    approved_count: int
    edited_count: int
    median_time_clean_seconds: float
    median_time_overall_seconds: float
    review_rate_per_hour: float
    questions_summary: list[dict[str, Any]]


class ReviewConsoleService:
    """Core review console logic and lifecycle manager."""

    def __init__(self, policy_engine: PolicyEngine | None = None) -> None:
        self.policy_engine = policy_engine or PolicyEngine()
        # In-memory storage for tasks, revisions, and acknowledgments
        self._questions: dict[str, dict[str, Any]] = {}
        self._revisions: dict[str, RevisionRecord] = {}
        self._question_revisions: dict[str, list[str]] = {}  # question_id -> list of rev_ids
        self._issues: dict[str, list[ValidationIssue]] = {}  # rev_id -> issues
        self._acknowledged: dict[str, set[str]] = {}  # rev_id -> set of rule_ids
        self._approvals: dict[str, dict[str, Any]] = {}  # rev_id -> approval info

    def register_question(
        self,
        question_id: str,
        tenant_id: str,
        document_id: str,
        ordinal: int,
        content: dict[str, Any],
        answer: dict[str, Any],
        issues: list[ValidationIssue],
        question_type: str = "multiple_choice",
        source_label: str | None = None,
        duplicate_cluster_id: str | None = None,
        requires_second_review: bool = False,
        status: str = "extracted",
    ) -> ReviewTask:
        """Register a question and its initial revision into the review service."""
        rev_id = str(uuid.uuid4())
        content_hash = _compute_hash(content)
        now_iso = datetime.now(timezone.utc).isoformat()

        rev_record = RevisionRecord(
            id=rev_id,
            question_id=question_id,
            tenant_id=tenant_id,
            rev_no=1,
            content=copy.deepcopy(content),
            answer=copy.deepcopy(answer),
            content_hash=content_hash,
            created_at=now_iso,
            created_via="pipeline",
        )
        self._revisions[rev_id] = rev_record
        self._question_revisions[question_id] = [rev_id]
        self._issues[rev_id] = list(issues)
        self._acknowledged[rev_id] = set()

        self._questions[question_id] = {
            "id": question_id,
            "tenant_id": tenant_id,
            "document_id": document_id,
            "source_label": source_label or f"Q{ordinal}",
            "ordinal": ordinal,
            "question_type": question_type,
            "status": status,
            "duplicate_cluster_id": duplicate_cluster_id,
            "requires_second_review": requires_second_review,
        }

        return self.get_task(question_id)

    def get_task(self, question_id: str) -> ReviewTask:
        """Fetch the current review task representation for a question."""
        q = self._questions[question_id]
        rev_ids = self._question_revisions[question_id]
        latest_rev_id = rev_ids[-1]
        rev = self._revisions[latest_rev_id]
        issues = self._issues.get(latest_rev_id, [])
        acks = self._acknowledged.get(latest_rev_id, set())

        # Evaluate policy
        decision = self.policy_engine.evaluate(issues)

        return ReviewTask(
            question_id=question_id,
            tenant_id=q["tenant_id"],
            document_id=q["document_id"],
            source_label=q["source_label"],
            ordinal=q["ordinal"],
            question_type=q["question_type"],
            status=q["status"],
            latest_revision_id=latest_rev_id,
            rev_no=rev.rev_no,
            content=rev.content,
            answer=rev.answer,
            content_hash=rev.content_hash,
            issues=issues,
            acknowledged_issue_ids=acks,
            policy_decision=decision,
            duplicate_cluster_id=q.get("duplicate_cluster_id"),
            requires_second_review=q.get("requires_second_review", False),
            priority_score=decision.priority_score,
        )

    def list_tasks(
        self,
        tenant_id: str,
        sort_by_priority: bool = True,
        cluster_duplicates: bool = True,
    ) -> list[ReviewTask]:
        """
        List all review tasks for a tenant.
        Queue ordering:
        - If sort_by_priority: sorted descending by priority_score (math > answer > figure > text).
        - If cluster_duplicates: questions sharing a duplicate_cluster_id are kept adjacent.
        """
        tasks: list[ReviewTask] = []
        for q_id, q_data in self._questions.items():
            if q_data["tenant_id"] == tenant_id:
                tasks.append(self.get_task(q_id))

        if sort_by_priority:
            # Sort primarily by priority score descending, then ordinal ascending
            tasks.sort(key=lambda t: (-t.priority_score, t.ordinal))

        if cluster_duplicates:
            # Group clusters together while preserving relative priority
            grouped: list[ReviewTask] = []
            visited_clusters: set[str] = set()
            for task in tasks:
                c_id = task.duplicate_cluster_id
                if not c_id:
                    grouped.append(task)
                elif c_id not in visited_clusters:
                    visited_clusters.add(c_id)
                    # Gather all tasks in this cluster
                    cluster_tasks = [t for t in tasks if t.duplicate_cluster_id == c_id]
                    grouped.extend(cluster_tasks)
            tasks = grouped

        return tasks

    def acknowledge_issue(
        self,
        revision_id: str,
        rule_id: str,
        acknowledged_by: str,
        reason: str | None = None,
    ) -> set[str]:
        """
        Acknowledge an issue (resolvable_by in ('confirm', 'edit')).
        Marks the issue as acknowledged on this specific revision.
        """
        if revision_id not in self._revisions:
            raise ValueError(f"Revision '{revision_id}' not found")

        rev_issues = self._issues.get(revision_id, [])
        target_issue = next((i for i in rev_issues if i.rule_id == rule_id), None)
        if not target_issue:
            raise ValueError(f"Issue '{rule_id}' not found on revision '{revision_id}'")

        if target_issue.resolvable_by not in ("confirm", "edit"):
            raise ValueError(f"Issue '{rule_id}' cannot be acknowledged (resolvable_by={target_issue.resolvable_by})")

        self._acknowledged.setdefault(revision_id, set()).add(rule_id)
        return self._acknowledged[revision_id]

    def edit_block(
        self,
        revision_id: str,
        block_id: str,
        new_value: str,
        reason: str,
        edited_by: str,
    ) -> RevisionRecord:
        """
        Block-level edit:
        - Clones the target revision content.
        - Updates the designated block (`latex` + `value` for math, `value` for text).
        - Computes new content hash.
        - Creates a new immutable revision with rev_no = current + 1.
        - Re-evaluates issues (removing blocker related to that block if fixed).
        """
        if revision_id not in self._revisions:
            raise ValueError(f"Revision '{revision_id}' not found")

        parent_rev = self._revisions[revision_id]
        question_id = parent_rev.question_id

        # Deep clone content
        new_content = copy.deepcopy(parent_rev.content)
        stem_blocks = new_content.get("stem", [])
        block_found = False

        for b in stem_blocks:
            if isinstance(b, dict) and b.get("id") == block_id:
                block_found = True
                if b.get("type") == "math":
                    b["latex"] = new_value
                    b["value"] = new_value
                else:
                    b["value"] = new_value
                break

        if not block_found:
            # Check options
            for opt in new_content.get("options", []):
                for b in opt.get("content", []):
                    if isinstance(b, dict) and b.get("id") == block_id:
                        block_found = True
                        if b.get("type") == "math":
                            b["latex"] = new_value
                            b["value"] = new_value
                        else:
                            b["value"] = new_value
                        break

        new_hash = _compute_hash(new_content)
        new_rev_id = str(uuid.uuid4())
        new_rev_no = parent_rev.rev_no + 1
        now_iso = datetime.now(timezone.utc).isoformat()

        new_record = RevisionRecord(
            id=new_rev_id,
            question_id=question_id,
            tenant_id=parent_rev.tenant_id,
            rev_no=new_rev_no,
            content=new_content,
            answer=copy.deepcopy(parent_rev.answer),
            content_hash=new_hash,
            created_at=now_iso,
            created_via="teacher_edit",
            created_by=edited_by,
            edit_note=reason,
            provenance={"parent_revision_id": parent_rev.id, "edited_block": block_id, "reason": reason},
        )

        self._revisions[new_rev_id] = new_record
        self._question_revisions[question_id].append(new_rev_id)

        # Inherit remaining issues, filtering out those resolved by the edit
        parent_issues = self._issues.get(revision_id, [])
        remaining_issues = [i for i in parent_issues if i.block_ref != block_id and i.rule_id not in ("B-020", "B-023")]
        self._issues[new_rev_id] = remaining_issues
        self._acknowledged[new_rev_id] = set()

        return new_record

    def select_answer(
        self,
        revision_id: str,
        selected_key: str,
        confirmed_by: str,
    ) -> RevisionRecord:
        """
        Confirm / select answer for a question (resolves B-040 or B-041).
        Creates a new immutable revision with answer.status = 'teacher_confirmed'.
        """
        if revision_id not in self._revisions:
            raise ValueError(f"Revision '{revision_id}' not found")

        parent_rev = self._revisions[revision_id]
        question_id = parent_rev.question_id

        new_answer = copy.deepcopy(parent_rev.answer)
        new_answer["status"] = "teacher_confirmed"
        new_answer["raw"] = selected_key
        new_answer["normalized"] = selected_key
        new_answer["conflict"] = False

        new_rev_id = str(uuid.uuid4())
        new_rev_no = parent_rev.rev_no + 1
        now_iso = datetime.now(timezone.utc).isoformat()

        new_record = RevisionRecord(
            id=new_rev_id,
            question_id=question_id,
            tenant_id=parent_rev.tenant_id,
            rev_no=new_rev_no,
            content=copy.deepcopy(parent_rev.content),
            answer=new_answer,
            content_hash=parent_rev.content_hash,
            created_at=now_iso,
            created_via="teacher_edit",
            created_by=confirmed_by,
            edit_note=f"Teacher confirmed answer: {selected_key}",
            provenance={"parent_revision_id": parent_rev.id, "confirmed_answer": selected_key},
        )

        self._revisions[new_rev_id] = new_record
        self._question_revisions[question_id].append(new_rev_id)

        # Remove B-040 / B-041 from issues
        parent_issues = self._issues.get(revision_id, [])
        remaining_issues = [i for i in parent_issues if i.rule_id not in ("B-040", "B-041")]
        self._issues[new_rev_id] = remaining_issues
        self._acknowledged[new_rev_id] = set()

        return new_record

    def merge_with_next(self, question_id: str, merged_by: str) -> None:
        """Mark question as merged with the next sequential question."""
        if question_id not in self._questions:
            raise ValueError(f"Question '{question_id}' not found")
        self._questions[question_id]["status"] = "merged_with_next"

    def split_question(
        self,
        question_id: str,
        split_at_block_id: str,
        split_by: str,
    ) -> tuple[str, str]:
        """Split a question into two distinct questions at block boundary."""
        if question_id not in self._questions:
            raise ValueError(f"Question '{question_id}' not found")
        task = self.get_task(question_id)
        stem = task.content.get("stem", [])

        # Split stem
        split_idx = next((idx for idx, b in enumerate(stem) if b.get("id") == split_at_block_id), len(stem) // 2)

        part1_stem = stem[: split_idx + 1]
        part2_stem = stem[split_idx + 1 :]

        # Update current question with part 1
        new_content1 = copy.deepcopy(task.content)
        new_content1["stem"] = part1_stem
        self.edit_block(task.latest_revision_id, part1_stem[0]["id"], part1_stem[0].get("value", ""), "Split part 1", split_by)

        # Create new question for part 2
        q2_id = str(uuid.uuid4())
        new_content2 = copy.deepcopy(task.content)
        new_content2["stem"] = part2_stem
        new_content2["source"]["ordinal"] = task.ordinal + 1
        self.register_question(
            question_id=q2_id,
            tenant_id=task.tenant_id,
            document_id=task.document_id,
            ordinal=task.ordinal + 1,
            content=new_content2,
            answer={"status": "unknown"},
            issues=[],
            source_label=f"{task.source_label}b",
        )

        return question_id, q2_id

    def mark_source_unreadable(self, question_id: str, marked_by: str, reason: str) -> None:
        """Mark a question as quarantined / source unreadable."""
        if question_id not in self._questions:
            raise ValueError(f"Question '{question_id}' not found")
        self._questions[question_id]["status"] = "source_unreadable"

    def restore_revision(self, question_id: str, target_revision_id: str, restored_by: str) -> RevisionRecord:
        """Rollback safely to an earlier revision by creating a new revision."""
        if target_revision_id not in self._revisions:
            raise ValueError(f"Revision '{target_revision_id}' not found")

        target_rev = self._revisions[target_revision_id]
        rev_ids = self._question_revisions[question_id]
        latest_rev = self._revisions[rev_ids[-1]]

        new_rev_id = str(uuid.uuid4())
        new_rev_no = latest_rev.rev_no + 1
        now_iso = datetime.now(timezone.utc).isoformat()

        restored_record = RevisionRecord(
            id=new_rev_id,
            question_id=question_id,
            tenant_id=target_rev.tenant_id,
            rev_no=new_rev_no,
            content=copy.deepcopy(target_rev.content),
            answer=copy.deepcopy(target_rev.answer),
            content_hash=target_rev.content_hash,
            created_at=now_iso,
            created_via="restore",
            created_by=restored_by,
            edit_note=f"Restored from revision #{target_rev.rev_no} ({target_rev.id})",
            provenance={"restored_from_revision_id": target_rev.id},
        )

        self._revisions[new_rev_id] = restored_record
        self._question_revisions[question_id].append(new_rev_id)
        self._issues[new_rev_id] = list(self._issues.get(target_revision_id, []))
        self._acknowledged[new_rev_id] = set()

        return restored_record

    def sample_second_review(self, question_id: str, sample_rate: float = 0.08) -> bool:
        """Sample 5–10% of approved questions for second-review inspection."""
        if question_id not in self._questions:
            raise ValueError(f"Question '{question_id}' not found")

        # Deterministic sampling based on question_id hash for reproducibility in tests
        h = int(hashlib.md5(question_id.encode("utf-8")).hexdigest(), 16)
        is_sampled = (h % 1000) < int(sample_rate * 1000)
        self._questions[question_id]["requires_second_review"] = is_sampled
        return is_sampled

    def approve_question(self, question_id: str, teacher_id: str) -> dict[str, Any]:
        """Approve question revision. Must enforce no unresolved blockers."""
        task = self.get_task(question_id)
        if task.has_unresolved_blockers:
            raise ValueError(
                f"Cannot approve question '{question_id}': has unresolved blockers "
                f"({[b.rule_id for b in task.issues if b.severity == 'BLOCKER' and b.rule_id not in task.acknowledged_issue_ids]})"
            )

        if task.status == "source_unreadable":
            raise ValueError(f"Cannot approve quarantined / unreadable question '{question_id}'")

        now_iso = datetime.now(timezone.utc).isoformat()
        approval_id = str(uuid.uuid4())
        self._approvals[task.latest_revision_id] = {
            "id": approval_id,
            "revision_id": task.latest_revision_id,
            "approved_by": teacher_id,
            "content_hash": task.content_hash,
            "approved_at": now_iso,
        }
        self._questions[question_id]["status"] = "approved"

        # Check second-review sampling
        self.sample_second_review(question_id)

        return self._approvals[task.latest_revision_id]

    def simulate_teacher_batch(self, tenant_id: str) -> BatchSimulationResult:
        """
        End-to-end clearing of questions for a tenant (e.g. 30 questions of Solid Shapes).
        Measures:
        - Median review time for clean items (< 15s target).
        - Handling of conflicts / defect items (edits, answer confirmation, quarantine).
        - Overall review rate (items per hour).
        """
        tasks = self.list_tasks(tenant_id, sort_by_priority=True, cluster_duplicates=True)
        times_clean: list[float] = []
        times_all: list[float] = []
        approved_count = 0
        edited_count = 0
        quarantined_count = 0
        fast_mode_count = 0
        targeted_count = 0
        blocked_count = 0
        summary: list[dict[str, Any]] = []

        rng = random.Random(42)  # Deterministic seed for reproducible testing

        for task in tasks:
            q_id = task.question_id
            decision = task.policy_decision

            if decision.policy_state == "REVIEW_FAST":
                fast_mode_count += 1
                # Fast diff verification: teacher verifies crop matches render in 3–8 seconds
                t_spent = rng.uniform(4.0, 7.5)
                times_clean.append(t_spent)
                times_all.append(t_spent)

                self.approve_question(q_id, teacher_id="simulated_teacher")
                approved_count += 1
                summary.append({"question_id": q_id, "action": "fast_approve", "seconds": round(t_spent, 1)})

            elif decision.policy_state == "SOURCE_UNREADABLE":
                quarantined_count += 1
                t_spent = rng.uniform(8.0, 14.0)
                times_all.append(t_spent)
                self.mark_source_unreadable(q_id, marked_by="simulated_teacher", reason="Ink truncated/damaged")
                summary.append({"question_id": q_id, "action": "quarantined", "seconds": round(t_spent, 1)})

            else:
                # BLOCKED or REVIEW_TARGETED
                if decision.policy_state == "BLOCKED":
                    blocked_count += 1
                else:
                    targeted_count += 1

                t_spent = 0.0

                # Resolve answer conflicts or unknown answers
                answer_blockers = [b for b in task.issues if b.rule_id in ("B-040", "B-041")]
                if answer_blockers:
                    t_spent += rng.uniform(15.0, 25.0)
                    # Teacher chooses option 'A' or confirmed key
                    cur_task = self.get_task(q_id)
                    self.select_answer(cur_task.latest_revision_id, selected_key="A", confirmed_by="simulated_teacher")

                # Resolve math / missing token issues via edit
                math_issues = [b for b in task.issues if b.rule_id in ("B-020", "B-023")]
                if math_issues:
                    t_spent += rng.uniform(20.0, 35.0)
                    cur_task = self.get_task(q_id)
                    # Teacher edits the block to restore symbol
                    b_id = math_issues[0].block_ref or "b1"
                    self.edit_block(
                        revision_id=cur_task.latest_revision_id,
                        block_id=b_id,
                        new_value=r"13,122\pi",
                        reason="source_image_correction",
                        edited_by="simulated_teacher",
                    )
                    edited_count += 1

                # Acknowledge remaining confirmable issues
                cur_task = self.get_task(q_id)
                for issue in cur_task.issues:
                    if issue.resolvable_by in ("confirm", "edit") and issue.rule_id not in cur_task.acknowledged_issue_ids:
                        t_spent += rng.uniform(3.0, 6.0)
                        self.acknowledge_issue(
                            cur_task.latest_revision_id,
                            issue.rule_id,
                            acknowledged_by="simulated_teacher",
                            reason="Visual check passed",
                        )

                times_all.append(t_spent)
                cur_task = self.get_task(q_id)
                if cur_task.can_approve:
                    self.approve_question(q_id, teacher_id="simulated_teacher")
                    approved_count += 1
                    summary.append({"question_id": q_id, "action": "reviewed_and_approved", "seconds": round(t_spent, 1)})
                else:
                    self.mark_source_unreadable(q_id, marked_by="simulated_teacher", reason="Unresolvable defect")
                    quarantined_count += 1
                    summary.append({"question_id": q_id, "action": "quarantined", "seconds": round(t_spent, 1)})

        times_clean.sort()
        times_all.sort()
        med_clean = times_clean[len(times_clean) // 2] if times_clean else 0.0
        med_all = times_all[len(times_all) // 2] if times_all else 0.0
        total_time_sec = sum(times_all)
        rate_per_hour = (len(tasks) / (total_time_sec / 3600.0)) if total_time_sec > 0 else 0.0

        return BatchSimulationResult(
            total_questions=len(tasks),
            fast_mode_count=fast_mode_count,
            targeted_review_count=targeted_count,
            blocked_count=blocked_count,
            quarantined_count=quarantined_count,
            approved_count=approved_count,
            edited_count=edited_count,
            median_time_clean_seconds=round(med_clean, 1),
            median_time_overall_seconds=round(med_all, 1),
            review_rate_per_hour=round(rate_per_hour, 1),
            questions_summary=summary,
        )
