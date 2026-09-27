# DECISIONS.md — Architecture & Pipeline Decisions Log
> EdSentre Question Bank Reconstruction System

| ID | Date | Context / Question | Decision | Status | Reversibility | Notes |
|---|---|---|---|---|---|---|
| D-001 | 2026-09-24 | PDF extraction library selection (PyMuPDF vs pypdfium2 + pdfminer) | Start with PyMuPDF behind `core/pdf/` adapter | Active | High | Keep implementation strictly behind the adapter interface so underlying library can be swapped without touching pipeline stages. |
| D-002 | 2026-09-24 | Review Console UI stack | Flutter Web | Active | Medium | Leverage existing Flutter project, Theme tokens, KaTeX/flutter_math_fork, and Auth. Backend exposes a UI-agnostic REST API. |
| D-003 | 2026-09-24 | Zero-cost model hosting strategy | Local deterministic Track N + Local PaddleOCR + local SymPy; local VLM (Qwen2.5-VL via vLLM) only when required | Active | High | Cloud AI completely excluded from default path. M0 will benchmark local execution cost and pages/hour. |
| D-004 | 2026-09-24 | Seed corpus initial placement | Copy `Dr Antonous Ashraf  (solid shapes).pdf` and `Dr Antounios Ashraf (trail August).pdf` to `tests/fixtures/` | Active | High | Ground truth seed files for M0 PoC. |
| D-005 | 2026-09-24 | Taxonomy standard for SAT/EST/ACT | College Board 4-domain taxonomy (Algebra, Advanced Math, Problem-Solving & Data Analysis, Geometry & Trigonometry) | Active | High | Ready for multi-level hierarchical skill codes. |
| D-006 | 2026-09-24 | Database publish gate enforcement | Database trigger + `SECURITY DEFINER` function `publish_revision()` | Active | Low | Absolute guardrail: zero unapproved questions reach students. |
| D-007 | 2026-09-24 | Solid Shapes Q21 (S-16) verification | Verified conflict via SymPy ($SA \approx 7652.4$ vs Key A $7666.6$) | Confirmed | Low | Validated expected behavior: B-041 (ANSWER_CONFLICT) prevents auto-approval and highlights discrepancy for teacher. |
| D-008 | 2026-09-24 | Milestone M0 Exit Sign-off | M0 acceptance tests 6/6 passed, mypy strict clean, 26,640 pages/hr, $0 cost | Completed | Low | Foundation and forensics engine proven on seed corpus. |
