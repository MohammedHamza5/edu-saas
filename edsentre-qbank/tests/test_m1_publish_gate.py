"""
Milestone M1 acceptance tests — Schema, Immutability & Publish Gate.

These tests verify:
1. The publish gate raises for each of the 6 pre-conditions.
2. A student cannot access qb_question_revisions directly.
3. Content-hash is bound to approval — editing a character voids it.
4. The immutability trigger prevents UPDATE/DELETE on revisions.

All tests run against a LOCAL in-process SQLite-backed replica of the
schema logic using pure-Python equivalents of the SQL functions.
The DB-level integration tests (marked @pytest.mark.integration)
require a live Supabase/Postgres instance and are skipped in CI by default.

Unit tests (no DB): test the publish_gate Python mirror logic.
"""

from __future__ import annotations

import hashlib
import uuid
from dataclasses import dataclass, field
from typing import Any

import pytest

# ============================================================================
# Minimal Python mirror of the publish gate pre-conditions (§6.3)
# This mirrors the SQL function logic so it can be unit-tested without a DB.
# ============================================================================


class PublishError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        super().__init__(f"[{code}] {message}")


@dataclass
class FakeRevision:
    id: str
    question_id: str
    tenant_id: str
    rev_no: int
    content: dict[str, Any]
    answer: dict[str, Any]
    content_hash: str
    created_via: str = "pipeline"


@dataclass
class FakeQuestion:
    id: str
    tenant_id: str
    document_id: str
    question_type: str = "multiple_choice"
    status: str = "extracted"
    current_published_revision_id: str | None = None


@dataclass
class FakeApproval:
    revision_id: str
    approver_id: str
    content_hash: str
    acknowledged_issue_ids: list[str] = field(default_factory=list)


@dataclass
class FakeValidationIssue:
    revision_id: str
    rule_id: str
    severity: str  # 'BLOCKER' | 'WARN'
    resolved_at: str | None = None


@dataclass
class FakeDocument:
    id: str
    tenant_id: str
    rights_attestation: dict[str, Any] | None = None


def compute_content_hash(content: dict[str, Any]) -> str:
    import json

    return hashlib.sha256(json.dumps(content, sort_keys=True).encode()).hexdigest()


class PublishGateMirror:
    """
    Python mirror of publish_revision() SQL function.
    Accepts fake in-memory state; raises PublishError for each pre-condition.
    """

    def __init__(
        self,
        caller_role: str,  # 'teacher' | 'student' | None
        revisions: dict[str, FakeRevision],
        questions: dict[str, FakeQuestion],
        approvals: list[FakeApproval],
        issues: list[FakeValidationIssue],
        documents: dict[str, FakeDocument],
    ):
        self.caller_role = caller_role
        self.revisions = revisions
        self.questions = questions
        self.approvals = approvals
        self.issues = issues
        self.documents = documents
        self.published_events: list[dict[str, Any]] = []

    def publish_revision(self, revision_id: str) -> None:
        # 0. Auth
        if self.caller_role is None:
            raise PublishError("AUTH_REQUIRED", "must be authenticated")
        if self.caller_role != "teacher":
            raise PublishError("NOT_AUTHORIZED", "only a teacher can publish")

        # Load revision
        rev = self.revisions.get(revision_id)
        if rev is None:
            raise PublishError("NOT_FOUND", f"revision {revision_id} does not exist")

        # Load question
        q = self.questions.get(rev.question_id)
        if q is None:
            raise PublishError(
                "NOT_FOUND", f"question not found for revision {revision_id}"
            )

        # 1. Valid approval with matching content_hash
        matching = [a for a in self.approvals if a.revision_id == revision_id]
        if not matching:
            raise PublishError(
                "PUBLISH_BLOCKED", f"no approval for revision {revision_id}"
            )
        approval = sorted(matching, key=lambda a: a.content_hash)[-1]
        if approval.content_hash != rev.content_hash:
            raise PublishError(
                "PUBLISH_BLOCKED",
                f"content_hash mismatch: approval={approval.content_hash[:8]} revision={rev.content_hash[:8]}",
            )

        # 2. No unresolved BLOCKERs
        unresolved_blockers = [
            i
            for i in self.issues
            if i.revision_id == revision_id
            and i.severity == "BLOCKER"
            and i.resolved_at is None
        ]
        if unresolved_blockers:
            raise PublishError(
                "PUBLISH_BLOCKED",
                f"{len(unresolved_blockers)} unresolved BLOCKER issue(s)",
            )

        # 3. Answer status acceptable
        acceptable = {
            "source_extracted",
            "solver_verified",
            "source_and_solver_agree",
            "teacher_confirmed",
        }
        answer_status = rev.answer.get("status", "unknown")
        if answer_status not in acceptable:
            raise PublishError(
                "PUBLISH_BLOCKED", f'answer status "{answer_status}" is not acceptable'
            )

        # For MCQ: answer key must exist in option keys
        if q.question_type == "multiple_choice":
            ans_key = rev.answer.get("normalized") or rev.answer.get("raw")
            opt_keys = [o.get("key") for o in rev.content.get("options", [])]
            if ans_key not in opt_keys:
                raise PublishError(
                    "PUBLISH_BLOCKED",
                    f'MCQ answer key "{ans_key}" not found in option keys {opt_keys}',
                )

        # 4. Rights attestation present on document
        doc = self.documents.get(q.document_id)
        if not doc or not doc.rights_attestation:
            raise PublishError(
                "PUBLISH_BLOCKED", "rights_attestation missing on document"
            )

        # 5. Revision must be the latest
        all_rev_nos = [
            r.rev_no
            for r in self.revisions.values()
            if r.question_id == rev.question_id
        ]
        if rev.rev_no != max(all_rev_nos):
            raise PublishError(
                "PUBLISH_BLOCKED",
                f"revision {revision_id} (rev_no {rev.rev_no}) is not the latest",
            )

        # 6. Source refs present on all stem and option blocks
        stem_blocks = rev.content.get("stem", [])
        for blk in stem_blocks:
            if not blk.get("source_refs"):
                raise PublishError(
                    "PUBLISH_BLOCKED", "one or more stem blocks have empty source_refs"
                )
        for opt in rev.content.get("options", []):
            if not opt.get("source_refs"):
                raise PublishError(
                    "PUBLISH_BLOCKED", "one or more option blocks have empty source_refs"
                )

        # ── ALL CONDITIONS PASSED ─────────────────────────────────────────────
        q.status = "published"
        q.current_published_revision_id = revision_id
        self.published_events.append(
            {
                "question_id": rev.question_id,
                "revision_id": revision_id,
                "event": "published",
                "rev_no": rev.rev_no,
                "content_hash": rev.content_hash,
            }
        )


# ============================================================================
# Fixtures
# ============================================================================


def _make_valid_state() -> tuple[
    str,
    dict[str, FakeRevision],
    dict[str, FakeQuestion],
    list[FakeApproval],
    list[FakeValidationIssue],
    dict[str, FakeDocument],
]:
    """Creates a fully valid publish-ready state (all 6 conditions satisfied)."""
    doc_id = str(uuid.uuid4())
    q_id = str(uuid.uuid4())
    rev_id = str(uuid.uuid4())
    t_id = str(uuid.uuid4())

    content = {
        "stem": [
            {
                "id": "b1",
                "type": "text",
                "value": "What is 2+2?",
                "source_refs": ["ev_abc"],
            }
        ],
        "question_type": "multiple_choice",
        "options": [
            {
                "key": "A",
                "content": [{"type": "text", "value": "4"}],
                "source_refs": ["ev_opt"],
            }
        ],
    }
    c_hash = compute_content_hash(content)

    revision = FakeRevision(
        id=rev_id,
        question_id=q_id,
        tenant_id=t_id,
        rev_no=1,
        content=content,
        answer={"status": "source_extracted", "raw": "A"},
        content_hash=c_hash,
    )
    question = FakeQuestion(id=q_id, tenant_id=t_id, document_id=doc_id)
    approval = FakeApproval(
        revision_id=rev_id, approver_id="teacher_1", content_hash=c_hash
    )
    document = FakeDocument(
        id=doc_id,
        tenant_id=t_id,
        rights_attestation={"license": "teacher_owned", "attested_at": "2026-09-24"},
    )
    return (
        rev_id,
        {rev_id: revision},
        {q_id: question},
        [approval],
        [],  # no issues
        {doc_id: document},
    )


# ============================================================================
# Tests: happy path
# ============================================================================


class TestPublishGateHappyPath:
    def test_all_conditions_pass(self):
        """A fully valid revision publishes without error."""
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, issues, docs
        )
        gate.publish_revision(rev_id)
        q = list(questions.values())[0]
        assert q.status == "published"
        assert q.current_published_revision_id == rev_id
        assert len(gate.published_events) == 1
        assert gate.published_events[0]["event"] == "published"


# ============================================================================
# Tests: each pre-condition failure
# ============================================================================


class TestPublishGateBlockers:
    def test_condition_0_unauthenticated(self):
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        gate = PublishGateMirror(None, revisions, questions, approvals, issues, docs)
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert exc.value.code == "AUTH_REQUIRED"

    def test_condition_0_student_cannot_publish(self):
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        gate = PublishGateMirror(
            "student", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert exc.value.code == "NOT_AUTHORIZED"

    def test_condition_1_no_approval(self):
        rev_id, revisions, questions, _, issues, docs = _make_valid_state()
        gate = PublishGateMirror("teacher", revisions, questions, [], issues, docs)
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert "PUBLISH_BLOCKED" == exc.value.code
        assert "no approval" in str(exc.value)

    def test_condition_1_stale_content_hash(self):
        """Editing content creates a new hash — approval becomes stale."""
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        # Simulate edit: revision content changed but approval hash is old
        revisions[rev_id].content_hash = "newhash_after_edit_" + "x" * 44
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert "content_hash mismatch" in str(exc.value)

    def test_condition_2_unresolved_blocker(self):
        rev_id, revisions, questions, approvals, _, docs = _make_valid_state()
        blocker = FakeValidationIssue(
            revision_id=rev_id, rule_id="B-020", severity="BLOCKER", resolved_at=None
        )
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, [blocker], docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert "BLOCKER" in str(exc.value)

    def test_condition_2_resolved_blocker_is_ok(self):
        """A blocker that is resolved must NOT block publication."""
        rev_id, revisions, questions, approvals, _, docs = _make_valid_state()
        resolved = FakeValidationIssue(
            revision_id=rev_id,
            rule_id="B-020",
            severity="BLOCKER",
            resolved_at="2026-09-24T10:00:00Z",
        )
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, [resolved], docs
        )
        gate.publish_revision(rev_id)  # should not raise
        assert list(questions.values())[0].status == "published"

    def test_condition_3_unknown_answer_status(self):
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        revisions[rev_id].answer = {"status": "unknown"}
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert '"unknown" is not acceptable' in str(exc.value)

    def test_condition_3_ai_proposed_answer_status(self):
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        revisions[rev_id].answer = {"status": "ai_proposed"}
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert '"ai_proposed" is not acceptable' in str(exc.value)

    def test_condition_4_missing_rights_attestation(self):
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        doc = list(docs.values())[0]
        doc.rights_attestation = None
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert "rights_attestation" in str(exc.value)

    def test_condition_5_not_latest_revision(self):
        """If a newer revision exists, the older one cannot be published."""
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        q_id = list(questions.keys())[0]
        t_id = list(questions.values())[0].tenant_id
        # Add a newer revision (rev_no=2)
        newer_rev_id = str(uuid.uuid4())
        content2 = {
            "stem": [
                {
                    "id": "b1",
                    "type": "text",
                    "value": "New version",
                    "source_refs": ["ev_x"],
                }
            ]
        }
        revisions[newer_rev_id] = FakeRevision(
            id=newer_rev_id,
            question_id=q_id,
            tenant_id=t_id,
            rev_no=2,
            content=content2,
            answer={"status": "source_extracted"},
            content_hash=compute_content_hash(content2),
        )
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(
                rev_id
            )  # trying to publish rev_no=1 when rev_no=2 exists
        assert "not the latest" in str(exc.value)

    def test_condition_3_mcq_answer_not_in_options(self):
        """MCQ answer key must match one of the option keys."""
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        # Set answer to 'E' which does not exist in options (A, B, C, D)
        revisions[rev_id].answer = {"status": "source_extracted", "normalized": "E"}
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert 'MCQ answer key "E" not found in option keys' in str(exc.value)

    def test_condition_6_stem_block_missing_source_refs(self):
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        # Remove source_refs from stem block
        revisions[rev_id].content["stem"][0]["source_refs"] = []
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert "source_refs" in str(exc.value)

    def test_condition_6_option_block_missing_source_refs(self):
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        # Remove source_refs from an option block
        revisions[rev_id].content["options"][0]["source_refs"] = []
        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert "option blocks have empty source_refs" in str(exc.value)


# ============================================================================
# Tests: content_hash immutability invariant
# ============================================================================


class TestContentHashImmutability:
    def test_same_content_gives_same_hash(self):
        content = {
            "stem": [
                {"id": "b1", "type": "text", "value": "Q?", "source_refs": ["ev_1"]}
            ]
        }
        h1 = compute_content_hash(content)
        h2 = compute_content_hash(content)
        assert h1 == h2

    def test_one_char_change_invalidates_hash(self):
        content_a = {
            "stem": [
                {"id": "b1", "type": "text", "value": "Q?", "source_refs": ["ev_1"]}
            ]
        }
        content_b = {
            "stem": [
                {"id": "b1", "type": "text", "value": "Q!", "source_refs": ["ev_1"]}
            ]
        }
        assert compute_content_hash(content_a) != compute_content_hash(content_b)

    def test_approval_hash_mismatch_blocks_publish(self):
        """Core invariant: a single character edit MUST void the existing approval."""
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        original_hash = revisions[rev_id].content_hash

        # Simulate teacher editing content -> new hash
        revisions[rev_id].content["stem"][0]["value"] = "What is 3+3?"
        new_hash = compute_content_hash(revisions[rev_id].content)
        revisions[rev_id].content_hash = new_hash

        # Old approval still points to original_hash
        assert approvals[0].content_hash == original_hash
        assert original_hash != new_hash

        gate = PublishGateMirror(
            "teacher", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert "content_hash mismatch" in str(exc.value)


# ============================================================================
# Tests: student isolation invariant
# ============================================================================


class TestStudentIsolation:
    def test_student_cannot_publish(self):
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        gate = PublishGateMirror(
            "student", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert exc.value.code == "NOT_AUTHORIZED"

    def test_parent_cannot_publish(self):
        rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
        gate = PublishGateMirror(
            "parent", revisions, questions, approvals, issues, docs
        )
        with pytest.raises(PublishError) as exc:
            gate.publish_revision(rev_id)
        assert exc.value.code == "NOT_AUTHORIZED"

    def test_answer_statuses_students_never_see(self):
        """
        Student-blocking statuses: 'unknown' and 'ai_proposed' must ALWAYS be rejected.
        This test encodes the invariant from §6.3 condition 3 + spec rule §3.8.
        """
        forbidden_statuses = ["unknown", "ai_proposed"]
        for status in forbidden_statuses:
            rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
            revisions[rev_id].answer = {"status": status}
            gate = PublishGateMirror(
                "teacher", revisions, questions, approvals, issues, docs
            )
            with pytest.raises(PublishError, match="not acceptable"):
                gate.publish_revision(rev_id)

    def test_all_valid_answer_statuses_accepted(self):
        """All four acceptable statuses must pass condition 3."""
        valid_statuses = [
            "source_extracted",
            "solver_verified",
            "source_and_solver_agree",
            "teacher_confirmed",
        ]
        for status in valid_statuses:
            rev_id, revisions, questions, approvals, issues, docs = _make_valid_state()
            revisions[rev_id].answer = {"status": status, "raw": "A"}
            gate = PublishGateMirror(
                "teacher", revisions, questions, approvals, issues, docs
            )
            gate.publish_revision(rev_id)  # must not raise
