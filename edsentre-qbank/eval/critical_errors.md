# Critical Error Taxonomies & Definitions (§14)
> EdSentre Question Bank Reconstruction Engine — Operational Quality Invariant

## 1. The Core Principle
```text
A question is visible to a student  ⇒
  source-traceable  ∧  all required blocks present  ∧  no open blocker
  ∧  answer status acceptable  ∧  approved by a teacher on an immutable revision (content-hash bound)
```
**Failing to extract a question is acceptable.**
**Showing a wrong question, altered math, or wrong answer to a student is an architectural failure.**

---

## 2. Critical Error Categories (Target Escape Rate: 0.0%)

Any published question exhibiting one of the following defects constitutes a **Critical Error**:

| Code | Defect Category | Precise Definition | Detection / Enforcement Layer |
|---|---|---|---|
| **CE-01** | **Wrong Answer Key** | `answer.raw` or `answer.normalized` differs from mathematical truth or published answer key. | `publish_revision()` DB gate, SymPy verification, B-040..042 blockers. |
| **CE-02** | **Altered Math Token / Sign / Value** | Any math symbol, sign ($+$ vs $-$), exponent, root, fraction, decimal point, unit, or constant (e.g. $\pi$) altered or missing compared to source document. | Critical-token consensus, Track N geometry diff, B-020..023 blockers. |
| **CE-03** | **Missing or Incorrect Visual Asset** | Figure, diagram, graph, or table referenced in stem is absent (`FIGURE_MISSING`) or misbound to the wrong question. | Figure-reference resolution, B-030..033 blockers, asset bbox verification. |
| **CE-04** | **Swapped or Missing Options** | MCQ has $\ne 4$ options, duplicate option keys, or option content swapped/misordered. | B-010 blocker, two-column layout clustering, option integrity gate. |
| **CE-05** | **Erroneous Split or Merge** | Content from two questions concatenated into one, or a single question truncated across pages without continuation. | Boundary consensus, cross-page merge tracking, B-001..003 blockers. |
| **CE-06** | **Truncated Source Ink** | Option or stem text/image clipped by crop boundary so critical letters or numbers are lost. | Ink-border touch detector, B-011 blocker (`SOURCE_TRUNCATED`). |

---

## 3. Product-Level Metrics (§14, §13 M6)

1. **Critical Error Escape Rate (CEER):**
   $$\text{CEER} = \frac{\text{Critical Errors Published}}{\text{Total Questions Published}} \times 100\%$$
   **Target:** $\mathbf{0.0\%}$ (Absolute requirement).

2. **Review Rate:**
   $$\text{Throughput} = \frac{\text{Questions Reviewed}}{\text{Teacher Review Hours}}$$
   **Target:** $\ge 200\text{ questions / hour}$ for mixed batches with fast-mode diff.

3. **Time per Question:**
   - Clean questions (`REVIEW_FAST`): $\le 15.0\text{ seconds}$ (achieved 5.8s in M5).
   - Targeted review with warnings: $\le 45\text{ seconds}$.
   - Complex items with edits/answer confirmation: $\le 90\text{ seconds}$.

4. **Approved-then-Corrected Rate (ATCR):**
   $$\text{ATCR} = \frac{\text{Revisions Corrected Post-Initial-Approval}}{\text{Total Approved Questions}} \times 100\%$$
   Tracks second-review audit effectiveness (Target: $\le 2.0\%$).
