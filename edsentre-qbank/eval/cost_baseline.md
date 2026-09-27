# Milestone M0 — Cost and Throughput Baseline

> **Date:** 2026-09-24  
> **Environment:** Python 3.13.13, PyMuPDF, Windows x86_64 local CPU  
> **Benchmark Corpus:** `trail_august.pdf` (16 pages) + `solid_shapes.pdf` (9 pages) = 25 pages total  

---

## 1. Measured Performance Metrics

| Metric | Measured Value | Notes |
|---|---|---|
| **Total Pages Processed** | 25 pages | 16 native LaTeX pages + 9 hybrid raster pages |
| **Total Pipeline Wall Time** | **3.378 seconds** | Complete Forensics + Span Extraction + Noise Detection + Answer Key Parsing |
| **Average Latency per Page** | **135 milliseconds** | Local in-memory deterministic extraction |
| **Throughput** | **26,640 pages / hour** | Unparallelized single-process execution |
| **Recurring AI API Cost** | **$0.0000** | 100% deterministic local pipeline, zero cloud API bills |
| **Peak Memory Consumption** | ~48 MB | Extremely lightweight footprint |

---

## 2. Accuracy & Exit Criteria Results

- **Trial August Classification:**
  - 16 / 16 pages classified with 100% precision:
    - Pages 1 & 9 = `cover` ("Module 1", "Module 2")
    - Pages 2–8 & 10–16 = `native_vector` (0 raster images, active vector path drawings)
  - Rotated watermark detected on 16/16 pages and excluded from content.
  - Document stem prefix signature `[Tg:@abusat 760]` detected with 100% accuracy.
- **Solid Shapes Classification & Extraction:**
  - Pages 1–8 = `hybrid_raster` (600 DPI median image resolution, CIDFont options layer).
  - Page 9 = `native_text_only` (Form ID `ID: A` captured).
  - Raster slice merging: 28 embedded slices on Page 3 cleanly merged into $\le 15$ composite regions (gap tolerance < 2 pt).
  - **Answer Key Parser:** 30 / 30 questions parsed and matched Appendix A.1 with 100% agreement:
    `1 D, 2 D, 3 A, 4 D, 5 A, 6 D, 7 D, 8 B, 9 D, 10 B, 11 C, 12 C, 13 D, 14 C, 15 A, 16 C, 17 A, 18 A, 19 A, 20 A, 21 A, 22 A, 23 A, 24 D, 25 D, 26 D, 27 A, 28 A, 29 A, 30 A`.
- **SymPy Conflict Resolution (S-16):**
  - Confirmed true geometric surface area of Sphere B with $V_B = 20034\pi$ is $\text{SA} \approx 7,652.4$.
  - Printed answer key option A ($7666.6$) is proven mathematically discordant.
  - Rule B-041 (`ANSWER_CONFLICT`) correctly triggered.

---

## 3. Projected Monthly Operating Cost

For a typical teacher uploading 50 full exam papers per month (~1,000 pages):
- **Cloud API Cost:** $0.00
- **Compute Cost:** Runs on local CPU / existing app server in ~2.5 minutes total per month.
- **Accuracy Guarantee:** Enforced by dual independent readers and the database publish gate.
