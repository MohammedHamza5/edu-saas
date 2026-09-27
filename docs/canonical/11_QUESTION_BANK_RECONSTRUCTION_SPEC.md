# EdSentre Question Bank Reconstruction System — Implementation Spec v1.0

> **Audience:** an AI coding agent (Claude Code / Cursor / Codex) implementing this system in a repo.
> **Owner:** EdSentre founder (technical, part-time). **Language of code/docs:** English. UI strings: Arabic + English (i18n from day one).
> **Status of claims:** every fact in §2 was measured on the two real sample PDFs (tagged `[VERIFIED]`). Anything tagged `[TO-VERIFY]` must be re-checked by code in Milestone 0 before you rely on it.

---

## 0. Rules of engagement for the agent (read first)

1. **Work milestone by milestone (§13).** Do not start milestone N+1 until every acceptance test of milestone N passes in CI.
2. **Tests before code** for anything in §8 (pipeline) and §9 (rules). Fixtures come from the two sample PDFs (Appendix A).
3. **Never weaken a blocker rule to make a test pass.** If a rule and a fixture disagree, stop, write the conflict to `DECISIONS.md`, and ask the human.
4. **Never write code that publishes a question without the DB publish gate (§6.3).** No shortcuts, no "admin bypass", no service-role writes to `published_*`.
5. **Never let a model output become a fact.** Model outputs are `Candidate` objects (§7.2) with provenance. Only validation + human approval promote them.
6. **Extraction is verbatim.** Do not "fix" typos, spacing, or wording found in the source (see F-14). Corrections are human actions recorded as new revisions.
7. **Everything is idempotent and versioned.** Cache key = `sha256(input) + stage_name + stage_version`. Re-running never overwrites a human-approved revision.
8. **Keep scope tight.** Anything in §12 (Non-goals) is forbidden until the human says otherwise.
9. **Log decisions.** Any ambiguity → add an entry to `DECISIONS.md` (context, options, choice, reversibility) instead of guessing silently.
10. **Small PRs, typed Python (mypy strict on `core/`), pydantic v2 models at every stage boundary.**

---

## 1. Goal and the one invariant

**Goal:** turn teacher-uploaded exam files (PDF: native, scanned, screenshot, mixed; or images) into a trustworthy digital question bank (MCQ, grid-in, true/false, extensible) with solutions, skill tags, difficulty, and adaptive-testing readiness — at near-zero recurring AI cost.

**The invariant (everything serves this):**

```
A question is visible to a student  ⇒
  source-traceable  ∧  all required blocks present  ∧  no open blocker
  ∧  answer status acceptable  ∧  approved by a teacher on an immutable revision (content-hash bound)
```

Failing to extract a question is acceptable. Showing a wrong question to a student is an architectural failure.

---

## 2. Ground truth: what the two sample files actually are

Two files are the seed corpus. **They are two different species.** The pipeline must route per page, never per file.

### 2.1 File S — `solid_shapes.pdf` (ExamView export)

| ID | Finding | Status | Consequence |
|---|---|---|---|
| S-01 | 9 pages. Title metadata: `ExamView - … .tst`; producer 4-Heights. Pages 1–8 questions; **page 9 = "Answer Section"** | VERIFIED | Answer-key parser is mandatory; doc has 30 MCQ + key. |
| S-02 | Fonts: only 3 CID fonts. **Zero vector drawings** on every page. | VERIFIED | Figures are raster, not vector. |
| S-03 | Embedded images all **600 DPI**, 3–28 per page. | VERIFIED | Source resolution is excellent; crops from embedded data beat page renders. |
| S-04 | **Images are sliced.** Page 3 has 28 embedded images: strips ~5 pt tall, and one prism figure is stored as two stacked 1140-px halves. | VERIFIED | **Never treat one embedded image = one figure.** Merge adjacent/overlapping image rects into a *composite region* (gap < 2 pt), then extract/render the region. Keep raw slices as evidence. |
| S-05 | **21 of 30 stems are 100 % raster** (text layer contains only the number + options). Only Q3, 7, 11, 12, 19, 20, 22, 23, 26 have native text stems. | VERIFIED | ~70 % of stems need OCR/VLM. Text layer is only a partial evidence source here. |
| S-06 | **The π glyph is absent from the text layer.** Q3/Q12/Q13 options extract as `13,122`, `216`, `288`… while the page shows `13,122π`, `216π`, `288π`. Q11 mixes a real π glyph (option a, dropped from text) with literal `PI` (b–d). Q23 has `228666 PI` next to bare numbers. | VERIFIED | Text-layer-only options would silently become *wrong numbers*. Text-vs-image diff catches it. Also requires `PI → π` display normalization as a **flagged suggestion**, not silent rewrite. |
| S-07 | Options are laid out in **two columns** (a,b left; c,d right). Text extraction interleaves rows (`a. 11.7 c. 21.2 / b. 1.6 d. 7.7`). | VERIFIED | Cluster option markers by bbox x/y, never by line order. |
| S-08 | Question number position vs its stem image is **inconsistent**: image above the number (Q4, Q5, Q6, Q8, Q9), number above image (Q10, Q13, Q21), figure above both (Q1, Q14, Q16). | VERIFIED | Do **not** attach images by "the image after the number". Use options-terminated segmentation (§8.4). |
| S-09 | Header `ID: A` on every page = ExamView **form id**; the key page also has `ID: A`. | VERIFIED | Capture as `form_id`, bind answer key to it. It is metadata, not noise. |
| S-10 | Near-duplicate questions: **Q2 ≈ Q4** (same cone problem, same options, different wording), **Q6 ≈ Q7** (cube edge 41), **Q25 ≈ Q26** (hemisphere r=70; Q24 same template r=83; Q23 same idea). | VERIFIED | Within-document duplicate clustering; flag, never auto-merge. |
| S-11 | **Q9 options are images clipped at the right edge** (`V=10(`, `V=500(` visibly cut). | VERIFIED | Detector: ink touching the crop border ⇒ `SOURCE_TRUNCATED` blocker. |
| S-12 | **Q14 figure carries a third-party raster watermark** ("…ghest… ring service … @Jo…"). Cannot be removed by text filtering. | VERIFIED | Asset-level OCR for stray text ⇒ `ASSET_THIRD_PARTY_MARK` warning + rights flag. |
| S-13 | **Q21 stem image is a transcription artifact**: contains literal meta-labels `Text:` and `Table:`, and says "shown above" while the table is inside the same image. | VERIFIED | `META_LABEL_IN_STEM` warning; figure-reference rule must resolve against assets *inside the same crop*. |
| S-14 | **Q28 stem is raster with typos**: `are2`, `cmby`, `cenmtimeters`, `porti on`. | VERIFIED | A VLM will "correct" these silently. Verbatim policy + reader-disagreement check (§8.5). |
| S-15 | **Q20 lacks "in terms of π" and options lack π**: 2/3·π·29³ ≈ 51,079 ≠ any option; options equal the π-coefficient (16259.33 → 16259). Key = A. | VERIFIED (hand calc) | Solver-vs-key conflict ⇒ REVIEW. Expected test case. |
| S-16 | **Q21 key (A = 7666.6) does not match my hand calc** (V_B = 20034π ⇒ r ≈ 24.68 ⇒ SA ≈ 7,652). Options look synthetic (7666.6/7555.5/7444.4/7333.3). | TO-VERIFY (by SymPy in M0) | Likely key/solver conflict ⇒ REVIEW. |
| S-17 | For the other 28 questions my hand calculation agrees with the printed key (Appendix A.1). | VERIFIED (hand) — re-verify by code | Key parser + solver agreement fixtures. |

### 2.2 File T — `trail_august.pdf` (LaTeX-generated, Bluebook-style)

| ID | Finding | Status | Consequence |
|---|---|---|---|
| T-01 | 16 pages, no metadata, **zero embedded raster images**. Figures are **vector drawings** (2–44 path objects per page). | VERIFIED | Figure data (scatter points, histogram bars, axes) is recoverable from paths. |
| T-02 | Fonts: **Computer Modern** (CMR/CMMI/CMSY/CMEX/CMBX/CMTI) ⇒ LaTeX origin. **Helvetica/Helvetica-Bold appear only for the watermark.** | VERIFIED | Font-family is a deterministic noise discriminator. |
| T-03 | **Diagonal watermark = 2 rotated text objects**: "Dr Antounios Ashraf" (Helvetica-Bold 32.7 pt, gray #808080, direction ≈ (0.82, −0.57)) and a phone number (16.7 pt). | VERIFIED | Remove by `line.dir ≠ (1,0)` + font + color. Explains "scattered characters" some extractors produce. Keep in evidence, exclude from content. |
| T-04 | Header `2026 Aug I / Tg: DigitSAT` and footer `@abusat 760 … page-number` on every page. Each stem starts with a **real in-line bold prefix `[Tg:@abusat 760]`**. | VERIFIED | Strip stem prefix by document-level signature (repeat ≥ 80 % of stems), record as `watermark_removed_from_text`. |
| T-05 | Structure: **cover pages** at p1 and p9 ("Module 1", "Module 2"). **Numbering resets per module** (Q1–Q22 twice). | VERIFIED | Identity = `(section, ordinal)`, e.g. `M2-Q7`. Bare numbers collide. |
| T-06 | **Cross-page questions (4 found):** M1-Q6 (stem p3 → options p4), M1-Q13 (label + figure p5 → stem text p6), M2-Q15 (table p13 → stem p14), M2-Q21 (option A on p15, B–D on p16). | VERIFIED | Segmentation must handle continuation in three shapes: stem→options, figure→stem, split option list. |
| T-07 | **Grid-in (no options) in Module 1:** Q1, Q9, Q10, Q12, Q13, Q18. Module 2 is all MCQ (A–D). 44 questions total. | VERIFIED | Type detection = absence of option group + presence of numeric-answer wording. |
| T-08 | **No answer key.** | VERIFIED | Every answer starts `unknown`. |
| T-09 | **Math structure is flattened in the text stream:** superscripts come out as trailing characters (`(x + 1)2 −12`, `n(2.80)x`, `340(0.2)5x` vs `340(0.2) x 5`), fractions as stacked numbers (`160 391`), radicals as `√` + digits, `in.3` for in³. | VERIFIED | Naive text = silently different math (`(0.2)^{5x}` vs `(0.2)^{x/5}`). |
| T-06b | **…but geometry is intact:** superscripts are separate spans in `CMR8` (8 pt vs 12 pt base) with baseline raised ≈ 4.3 pt; fractions have numerator/denominator spans plus a horizontal rule path. | VERIFIED | **Native-LaTeX math can be reconstructed deterministically from span size + baseline + rules** (§8.6, Track N). No math-OCR needed for this class; OCR becomes the *second independent reader*. |
| T-10 | **Minus signs are mixed:** ASCII hyphen in options (`-90`, `-18`, `-17`), U+2212 in expressions. | VERIFIED (in extracted text) | Normalize for comparison; keep raw; compare after normalization only. |
| T-11 | `1, 760 yards` (math-mode comma + space); `P Q`, `XY Z`, `T R` letter spacing. | VERIFIED | Tokenizer must not split a number at `, `; must not treat `1, 760` as a list. |
| T-12 | Whole-document text stream **concatenates the footer phone number with the next page header** (`…01210838829` + `2026 Aug I`). | VERIFIED | Always extract **per page, per span with bbox**; never use a document-level text dump. |

### 2.3 What earlier reviews got wrong (do not repeat)
- "Trial file is a screenshot PDF with near-zero text" — **false**. It is native LaTeX with a full text layer + vector figures.
- "Trial watermark digits are scattered inside stems" — the *cause* is rotated watermark spans; the clean, real stem prefix is `[Tg:@abusat 760]`.
- "Q7 appears duplicated in extraction" — the real cause is **(module, number) collision** (M1-Q7 vs M2-Q7).
- Any DPI/GPU/cost figure quoted without measurement. **Measure in M0.**

---

## 3. Principles (short list)

1. **Evidence-first:** original file + page renders + spans with bboxes + embedded images + vector paths are stored immutably; every content block cites `source_refs`.
2. **Two independent readers for every critical token** (digits, signs, decimal points, exponents, fractions, units, variables). Disagreement = blocker on that block.
3. **Deterministic first, models last, cloud never on the default path.**
4. **Confidence vector + hard blockers + policy engine.** No single scalar decides anything.
5. **Original visual crop is the truth; semantic description of a figure is optional and unverified.**
6. **Answer has a status and a source.** `ai_proposed` never becomes `verified` by itself.
7. **Published is a strict read-model** fed only by the DB publish gate.
8. **Human approval is mandatory in v1.** "Machine-cleared" is designed but disabled (§11.4).

---

## 4. Tech stack and repo layout

- **Language/runtime:** Python 3.11+, `uv`, FastAPI, pydantic v2, SQLAlchemy 2 + psycopg3, Alembic.
- **DB/Auth/Storage:** Supabase (Postgres, Auth, RLS, Storage). **All tables carry `tenant_id`; RLS on everything.**
- **Queue:** Postgres `jobs` table + `SELECT … FOR UPDATE SKIP LOCKED`. No Celery/Kafka/K8s in v1.
- **PDF:** PyMuPDF for spans/drawings/images/render. ⚠ **License decision needed (AGPL vs commercial)** → `DECISIONS.md`; keep it behind `core/pdf/` so `pypdfium2` + `pdfminer.six` can replace it.
- **CV:** OpenCV, scikit-image (border-ink detection, crops, deskew).
- **OCR/layout:** PaddleOCR (+ PP-Structure for tables); Tesseract only as fallback.
- **Math OCR:** bake-off in M3 among pix2tex, UniMERNet, Pix2Text; pick by Critical Token Error Rate on the corpus.
- **VLM (local):** Qwen2.5-VL / Qwen3-VL served through an **OpenAI-compatible endpoint (vLLM)**. Model is config, not code.
- **Symbolic:** SymPy; LaTeX→SymPy via `latex2sympy2` (or ANTLR `parse_latex`) behind an adapter.
- **Sandbox for any model-generated code:** separate process, no network, CPU/time/memory limits.
- **Review Console:** Flutter Web (reuse `flutter_math_fork`/KaTeX for rendering) **or** internal web app — decide in M1 (`DECISIONS.md`). API contract in §10 is UI-agnostic.

```
edsentre-qbank/
  AGENTS.md                 # copy of §0 + coding conventions
  DECISIONS.md
  pyproject.toml
  core/                     # pure logic, no I/O side effects, fully typed
    models/                 # pydantic: Candidate, Block, Question, Issue, Policy…
    pdf/                    # adapter: spans, drawings, images, render
    forensics/
    noise/
    segmentation/
    reconstruct/{text,math_native,math_ocr,visual,options}/
    answers/{key_parser,solver,ai_proposed}/
    validation/             # rules registry (§9)
    policy/
    providers/              # TextExtractor, MathExtractor, LayoutAnalyzer, SemanticInterpreter
  services/
    api/                    # FastAPI
    worker/                 # job runner
  db/migrations/
  console/                  # review UI
  tests/
    fixtures/{solid_shapes.pdf,trail_august.pdf}
    golden/                 # expected JSON (Appendix A)
    mutation/
    unit/ integration/ e2e/
  eval/                     # benchmark runner + metrics report
```

---

## 5. Pipeline overview

```
Upload → [0] Forensics → [1] Evidence Package (immutable)
       → [2] Noise & Layout → [3] Document Structure
       → [4] Segmentation (question hypotheses)
       → [5] Reconstruction  (Track N native | Track R raster)
       → [6] Answer Engine
       → [7] Validation Suite (rules §9)
       → [8] Policy & Triage
       → [9] Teacher Review (block-level edits → new revisions)
       → [10] DB Publish Gate → published read-model → students
       → [11] Feedback loop (corrections → regression corpus; student reports; anomalies)
```

**Per-page routing (not per-file):**

| `page_class` | Rule | Example |
|---|---|---|
| `native_vector` | text layer trusted ≥ threshold, no raster stems, figures are vector paths | all Trial pages |
| `hybrid_raster` | native text (numbers/options) + raster stems/figures | Solid pp. 1–8 |
| `native_text_only` | text, no images/drawings | Solid p. 9 (answer key) |
| `scanned` / `screenshot` | little/no text layer, page-size raster | (future files) |
| `cover` | section title only, no questions | Trial pp. 1, 9 |

**Track N (native-deterministic):** spans → lines → math geometry → LaTeX; OCR of the rendered crop is the second reader.
**Track R (raster):** merge slices → crop → PaddleOCR reader #1 + VLM reader #2 (+ math OCR for equation regions) → critical-token diff.

---

## 6. Data model

### 6.1 Core tables (abridged DDL; add `tenant_id uuid not null` + RLS policy to every table)

```sql
create table documents(
  id uuid primary key default gen_random_uuid(), tenant_id uuid not null,
  sha256 text not null, original_path text not null, mime text, size_bytes bigint,
  page_count int, uploader_id uuid, rights_attestation jsonb,   -- who uploaded, claimed license, source notes
  forensic jsonb, created_at timestamptz default now(),
  unique(tenant_id, sha256));

create table document_pages(
  id uuid primary key, document_id uuid references documents, page_no int not null,
  page_class text not null check (page_class in
    ('native_vector','hybrid_raster','native_text_only','scanned','screenshot','cover','unknown')),
  text_trust numeric, render_path text, width_pt numeric, height_pt numeric, rotation int,
  unique(document_id, page_no));

create table evidence_assets(          -- immutable
  id uuid primary key, document_id uuid, page_id uuid, kind text not null check (kind in
   ('page_render','embedded_image','composite_image','vector_group','crop','span_dump','key_crop')),
  bbox_pt numeric[4], storage_path text, sha256 text not null, dpi int,
  derived_from uuid[], producer jsonb);   -- {tool, version, params}

create table page_regions(id uuid primary key, page_id uuid, kind text, bbox_pt numeric[4],
  source text, confidence numeric, noise_class text);   -- noise_class: header|footer|watermark|page_number|null

create table exam_sections(id uuid primary key, document_id uuid, label text, ordinal int,
  expected_question_count int, form_id text);           -- 'Module 1', form 'A'

create table questions(
  id uuid primary key, tenant_id uuid, document_id uuid, section_id uuid, source_label text,   -- 'M2-Q7'
  question_type text references question_types(code),
  current_published_revision_id uuid, status text not null check (status in
   ('extracted','review_required','in_review','approved','published','rejected','quarantined')),
  unique(document_id, source_label));

create table question_revisions(       -- IMMUTABLE (no UPDATE/DELETE; enforced by trigger)
  id uuid primary key, question_id uuid references questions, rev_no int not null,
  content jsonb not null, answer jsonb not null, confidence jsonb, provenance jsonb not null,
  content_hash text not null, created_by uuid, created_via text check (created_via in ('pipeline','teacher_edit','restore')),
  edit_note text, created_at timestamptz default now(), unique(question_id, rev_no));

create table validation_runs(id uuid primary key, revision_id uuid, pipeline_version text, ran_at timestamptz);
create table validation_issues(id uuid primary key, run_id uuid, rule_id text, severity text check (severity in ('BLOCKER','WARN','INFO')),
  block_ref text, message jsonb, resolvable_by text check (resolvable_by in ('edit','confirm','none')), resolved_by uuid, resolved_at timestamptz);

create table review_tasks(id uuid primary key, revision_id uuid, priority int, mode text, assigned_to uuid, status text);
create table review_actions(id uuid primary key, task_id uuid, actor_id uuid, action text, payload jsonb, created_at timestamptz default now());
create table approvals(id uuid primary key, revision_id uuid, approver_id uuid, content_hash text not null,
  acknowledged_issue_ids uuid[], created_at timestamptz default now());
create table question_events(id bigserial primary key, question_id uuid, revision_id uuid, actor uuid, event text, diff jsonb, at timestamptz default now());

create table question_types(code text primary key, response_schema jsonb, validator text, renderer text);
create table taxonomy(id text primary key, parent_id text, name_en text, name_ar text);
create table taxonomy_assignments(revision_id uuid, taxonomy_id text, source text check (source in ('ai_suggested','teacher_assigned')), status text, confidence numeric);
create table jobs(id uuid primary key, kind text, payload jsonb, status text, attempts int, run_after timestamptz, locked_by text, cache_key text);
```

### 6.2 Read model

```sql
create view published_question_revision as
select r.* from questions q join question_revisions r on r.id = q.current_published_revision_id
where q.status = 'published';
-- Students get SELECT on this view only. No SELECT on question_revisions/drafts/documents/evidence.
```

### 6.3 The publish gate (only path to publication)

`publish_revision(p_revision_id uuid)` — `SECURITY DEFINER`, owned by a dedicated role; app roles have **no** INSERT/UPDATE on `questions.current_published_revision_id` or `questions.status='published'`. It must raise if any of these fails:

1. an `approvals` row exists for this revision **with `content_hash` = revision.content_hash** (editing a single character creates a new revision and voids approval);
2. no `validation_issues` with `severity='BLOCKER'` and `resolved_at is null` for the latest run on this revision;
3. every content block and option has non-empty `source_refs`;
4. `answer.status ∈ ('source_extracted','solver_verified','source_and_solver_agree','teacher_confirmed')`, and for MCQ the answer key ∈ option keys;
5. `documents.rights_attestation` present;
6. revision is the latest for the question.

---

## 7. Canonical schemas

### 7.1 Question revision content (JSONB, validated by pydantic)

```jsonc
{
  "source": {"document_id":"…","section":"M1","ordinal":13,"pages":[5,6],"form_id":null},
  "question_type": "grid_in",              // registry code
  "language": "en", "direction": "ltr",
  "stem": [                                // ordered blocks
    {"id":"b1","type":"asset","asset_id":"…","role":"figure","source_refs":["ev_…"],"confidence":{"crop":0.98}},
    {"id":"b2","type":"text","value":"The figure shown is a right rectangular pyramid, where","raw":"…","source_refs":[…],"lang":"en"},
    {"id":"b3","type":"math","latex":"l=16","raw_readers":{"native":"l=16","ocr":"l=16"},"crop_asset":"…","source_refs":[…]}
  ],
  "options": [ {"key":"A","content":[…],"source_refs":[…]} ],     // empty for grid_in
  "response": {"type":"numeric","accepted_forms":["integer","decimal","fraction"],"equivalence":"sympy_exact","tolerance":null},
  "answer": {"status":"unknown","raw":null,"normalized":null,"accepted_equivalents":[],"candidates":[],"source_ref":null},
  "taxonomy": [{"id":"geo.solids.surface_area","source":"ai_suggested","status":"provisional","confidence":0.8}],
  "difficulty": {"value":null,"source":"ai_estimated|teacher_assigned|empirically_calibrated"},
  "confidence": {"boundary":0.99,"text":0.97,"math":0.7,"options":1.0,"diagram":0.9,"answer":0.0},
  "flags": ["watermark_removed_from_text"]
}
```

### 7.2 `Candidate` (what every extractor returns)

```python
class Candidate(BaseModel):
    value: str | dict
    reader: str                # "pdf_native" | "paddleocr" | "vlm:qwen2.5-vl-7b" | "mathocr:unimernet" | "human"
    reader_version: str
    prompt_version: str | None
    input_hash: str
    evidence_refs: list[str]
    self_confidence: float | None    # informational only; never used alone
    latency_ms: int; est_cost_usd: float
```

### 7.3 Answer status machine

```
unknown → ai_proposed → …
source_extracted ─┐
solver_verified  ─┴→ source_and_solver_agree → teacher_confirmed
```

---

## 8. Stage specifications

### 8.1 Stage 0 — Forensics (deterministic)
Per page compute and store in `documents.forensic`:
`n_chars`, `n_spans`, `fonts[]` (+ family class: CM/TeX, CID, Helvetica…), `n_embedded_images`, `image_dpi_min/median`, `n_drawings`, `rotated_text_span_count`, `bbox_overlap_ratio` of words, `coverage_text`, `coverage_raster`, `has_answer_key_pattern`, `is_cover`.
Emit `page_class` + `text_trust` (0..1). Text trust drops with: overlapping word boxes, private-use glyphs, non-horizontal text mixed with body font, missing-glyph patterns (e.g., Greek letters absent while `PI` literals present).

### 8.2 Stage 1 — Evidence package (immutable)
- Store original + SHA-256. Reject duplicates per tenant.
- Render each page PNG at 300 DPI; on demand re-render regions at 450–600 DPI.
- Dump **spans**, **drawings**, **embedded images**.
- **Composite images:** union adjacent/overlapping embedded-image rects (gap < 2 pt, same x-range ±2 pt) → `composite_image` assets; store raw slices as children.

### 8.3 Stage 2 — Noise & layout
1. **Rotated / off-axis text** (`dir ≠ (1,0)`, tolerance 1°) ⇒ `watermark`.
2. **Font/color discriminators:** Helvetica-Bold gray on Trial ⇒ watermark.
3. **Repetition:** same text at same position on ≥ 3 pages ⇒ header/footer; page-number pattern.
4. **Document signatures:** string present in ≥ 80 % of stems (e.g., `[Tg:@abusat 760]`) ⇒ `stem_prefix_watermark`.

### 8.4 Stages 3–4 — Document structure and segmentation
Options-terminated segmentation for hybrid/raster layouts. Continuation rules across pages. Store top scoring hypotheses if close.

### 8.5 Stage 5 — Reconstruction: text, options, critical-token consensus
Two independent readers per block. Critical-token diff on `{number, decimal_point, sign, operator, variable, unit, sup, sub, frac, root, greek}`. Verbatim policy (typos in source kept, differences flagged).

### 8.6 Math
Track N — geometry-based reconstruction from native LaTeX spans (baseline, size, horizontal rules, radical overlines, CMSY/CMEX glyph mapping). Output LaTeX + AST. Second reader = OCR of rendered crop.

### 8.7 Visuals (figures, graphs, tables)
Original crop always stored. Vector figures extract candidate data. Figure-reference rule: reference without bound asset ⇒ `FIGURE_MISSING` blocker.

### 8.8 Stage 6 — Answer engine
1. Key parser (ExamView regex on answer pages).
2. Deterministic solvers (SymPy).
3. Formalization solver (AI, sandboxed).
4. Conflict resolution (key vs solver ⇒ `ANSWER_CONFLICT` blocker).

---

## 9. Rule catalog (Validation Suite)

| ID | Sev | Trigger | Seen in samples |
|---|---|---|---|
| B-001 | BLOCKER | Boundary status ≠ `confirmed` | M1-Q6, M1-Q13, M2-Q15, M2-Q21 |
| B-002 | BLOCKER | Question left open at EOF / section end | — |
| B-003 | BLOCKER | Ordinal gap/repeat inside a section; count ≠ expected | (module,number) collision |
| B-004 | BLOCKER | Stem empty or shorter than minimum after noise removal | 21 raster stems in S |
| B-010 | BLOCKER | MCQ options ≠ 4, duplicated, or out of order | M2-Q21 split list |
| B-011 | BLOCKER | Option image clipped at border (`SOURCE_TRUNCATED`) | S-Q9 |
| B-020 | BLOCKER | Critical-token diff between readers on a block | π missing (S-06), `(0.2)^{5x}` vs `^{x/5}` |
| B-021 | BLOCKER | Math parse failure / unbalanced / empty denominator | — |
| B-022 | BLOCKER | Number/sign present in crop OCR but absent in LaTeX (or vice-versa) | sign/`−` risks |
| B-023 | BLOCKER | π/unit/superscript loss suspected (text layer lacks glyph seen in OCR) | S-Q3/11/12/13/23, T `in.3` |
| B-030 | BLOCKER | `FIGURE_MISSING` (reference without bound asset) | — |
| B-031 | WARN | `ASSET_THIRD_PARTY_MARK` | S-Q14 |
| B-032 | WARN | `META_LABEL_IN_STEM` (`Text:`, `Table:`) | S-Q21 |
| B-033 | BLOCKER | Figure data extracted (`unverified`) used for solving without visual match | — |
| B-040 | BLOCKER | Answer `unknown` or `ai_proposed` (teacher must set/confirm) | all of T |
| B-041 | BLOCKER | `ANSWER_CONFLICT` key vs solver | S-Q20, likely S-Q21 |
| B-042 | BLOCKER | MCQ answer key ∉ option keys; key page count ≠ question count | — |
| B-043 | BLOCKER | Grid-in without accepted-equivalents/normalization | T grid-ins |
| B-050 | WARN | `watermark_removed_from_text` | T (every stem) |
| B-051 | WARN | `READER_DISAGREEMENT` on prose (typo-like) | S-Q28 |
| B-052 | WARN | `possible_duplicate_of` (same normalized stem/options) | S: Q2/Q4, Q6/Q7, Q25/Q26 |
| B-053 | WARN | `PI`/`π` mix in options; hyphen/U+2212 mix | S-Q11, S-Q23; T-10 |
| B-060 | BLOCKER | Source not traceable (`source_refs` missing) or human edit without audit event | — |
| B-070 | BLOCKER | Rights attestation missing at document level | watermark ⇒ third-party origin |

---

## 10. Review Console

Layout: Left = original crop(s); Right = rendered student view; Top = issue chips; Bottom = confidence & revisions.
Behaviors: Block-level edit, acknowledge per issue, Fast mode, Merge with next / Split.

---

## 11. Security, rights, cost, scale
Sandboxed parsers, structured output only, RLS on every table, rights attestation, local models default with zero cloud AI cost.

---

## 12. Non-goals
Automatic publishing · figure→SVG/parametric conversion · multi-API LLM ensembles · IRT before thousands of attempts · stored MathML · vector search · microservices/Kubernetes.

---

## 13. Milestones with exit criteria
- **M0 — Corpus + forensics PoC (1–2 weeks)**
- **M1 — Foundation + publish gate + minimal console (3–5 weeks)**
- **M2 — Structure, segmentation, Track N text (4–6 weeks)**
- **M3 — Reconstruction: math, raster readers, visuals (4–6 weeks)**
- **M4 — Answer engine, validation, policy (3–5 weeks)**
- **M5 — Console completion (3–4 weeks)**
- **M6 — Real pilot (4+ weeks)**

---

## Appendix A — Golden fixtures

### A.1 Solid Shapes answer key (parsed from p. 9)
```
1 D | 2 D | 3 A | 4 D | 5 A | 6 D | 7 D | 8 B | 9 D | 10 B
11 C | 12 C | 13 D | 14 C | 15 A | 16 C | 17 A | 18 A | 19 A | 20 A
21 A | 22 A | 23 A | 24 D | 25 D | 26 D | 27 A | 28 A | 29 A | 30 A
```

### A.2 Solid Shapes structural expectations
- Native-text stems: Q3, 7, 11, 12, 19, 20, 22, 23, 26. All other stems raster.
- Options two-column; letters lowercase `a.–d.`; form id `A`.
- Flags expected: B-023 {3, 11, 12, 13, 23}; B-011 {9}; B-031 {14}; B-032 {21}; B-051 {28}; B-041 {20, 21?}; B-052 {(2,4), (6,7), (25,26)}; B-053 {11, 23}.

### A.3 Trial August structural expectations
- Pages: cover {1, 9}; M1 pages 2–8 (22 questions); M2 pages 10–16 (22 questions).
- Grid-in ordinals (M1): 1, 9, 10, 12, 13, 18. Everything else MCQ `A–D`.
- Cross-page: M1-Q6 (3→4), M1-Q13 (5→6), M2-Q15 (13→14), M2-Q21 (15→16).
- Watermark: rotated Helvetica-Bold gray spans (name + phone) on every page; stem prefix `[Tg:@abusat 760]` on 44/44 stems; header `2026 Aug I | Tg: DigitSAT`; footer `@abusat 760 … N`.
