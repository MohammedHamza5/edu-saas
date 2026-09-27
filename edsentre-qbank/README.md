# EdSentre Question Bank Reconstruction System (edsentre-qbank)

> Core Python reconstruction engine for teacher exam PDFs/images into verified digital question banks.
> Built per `docs/canonical/11_QUESTION_BANK_RECONSTRUCTION_SPEC.md`.

## Features
- **Deterministic-first**: Native vector/LaTeX geometry math parsing (Track N) + local OCR/VLM raster consensus (Track R).
- **Dual Independent Readers**: Critical-token consensus diffing.
- **Zero Cloud AI Default**: No recurring API costs on default path.
- **Publish Gate**: Immutably signed revisions verified by database constraints.
