"""PDF Adapter isolating PyMuPDF behind a clean, deterministic interface.
Supports spans, vector drawings, embedded images, composite regions, and rendering.
"""

import hashlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import pymupdf


@dataclass
class TextSpan:
    text: str
    font: str
    size: float
    color: int
    bbox: tuple[float, float, float, float]  # (x0, y0, x1, y1)
    origin: tuple[float, float]
    dir: tuple[float, float]  # (dx, dy)
    flags: int = 0


@dataclass
class VectorDrawing:
    rect: tuple[float, float, float, float]
    type: str  # "rect", "line", "curve", etc.
    items: list[Any] = field(default_factory=list)


@dataclass
class EmbeddedImage:
    xref: int
    rect: tuple[float, float, float, float]  # (x0, y0, x1, y1) in pt
    width: int
    height: int
    dpi_x: float
    dpi_y: float


@dataclass
class CompositeRegion:
    bbox: tuple[float, float, float, float]
    slices: list[EmbeddedImage] = field(default_factory=list)


class PdfDocumentAdapter:
    """Deterministic wrapper for PDF operations."""

    def __init__(self, file_path: str | Path):
        self.path = Path(file_path)
        if not self.path.exists():
            raise FileNotFoundError(f"PDF not found: {self.path}")
        self.doc = pymupdf.open(str(self.path))
        self._sha256: str | None = None

    @property
    def sha256(self) -> str:
        if self._sha256 is None:
            hasher = hashlib.sha256()
            with open(self.path, "rb") as f:
                while chunk := f.read(65536):
                    hasher.update(chunk)
            self._sha256 = hasher.hexdigest()
        return self._sha256

    @property
    def page_count(self) -> int:
        return len(self.doc)

    def get_page_size(self, page_no: int) -> tuple[float, float]:
        """Returns (width_pt, height_pt) for a 0-indexed page."""
        page = self.doc[page_no]
        rect = page.rect
        return (float(rect.width), float(rect.height))

    def get_page_rotation(self, page_no: int) -> int:
        return int(self.doc[page_no].rotation)

    def extract_spans(self, page_no: int) -> list[TextSpan]:
        """Extracts text spans with bbox, font, size, origin, and direction."""
        page = self.doc[page_no]
        spans: list[TextSpan] = []
        page_dict = page.get_text("dict")

        for block in page_dict.get("blocks", []):
            if block.get("type") != 0:  # 0 is text block
                continue
            for line in block.get("lines", []):
                line_dir = tuple(line.get("dir", (1.0, 0.0)))
                for span in line.get("spans", []):
                    text = span.get("text", "")
                    if not text:
                        continue
                    bbox_tuple: tuple[float, float, float, float] = tuple(
                        span.get("bbox", (0.0, 0.0, 0.0, 0.0))
                    )
                    origin_tuple: tuple[float, float] = tuple(
                        span.get("origin", (0.0, 0.0))
                    )
                    dir_tuple: tuple[float, float] = line_dir
                    spans.append(
                        TextSpan(
                            text=text,
                            font=span.get("font", ""),
                            size=float(span.get("size", 0.0)),
                            color=int(span.get("color", 0)),
                            bbox=bbox_tuple,
                            origin=origin_tuple,
                            dir=dir_tuple,
                            flags=int(span.get("flags", 0)),
                        )
                    )
        return spans

    def extract_drawings(self, page_no: int) -> list[VectorDrawing]:
        """Extracts vector drawings and paths."""
        page = self.doc[page_no]
        drawings: list[VectorDrawing] = []
        try:
            raw_drawings = page.get_drawings()
            for d in raw_drawings:
                rect_tuple: tuple[float, float, float, float] = tuple(
                    d.get("rect", (0.0, 0.0, 0.0, 0.0))
                )
                drawings.append(
                    VectorDrawing(
                        rect=rect_tuple,
                        type=d.get("type", "path"),
                        items=d.get("items", []),
                    )
                )
        except Exception:
            pass
        return drawings

    def extract_embedded_images(self, page_no: int) -> list[EmbeddedImage]:
        """Extracts embedded raster images and computes their page placements and DPI."""
        page = self.doc[page_no]
        images: list[EmbeddedImage] = []
        image_list = page.get_images(full=True)

        for img_info in image_list:
            xref = img_info[0]
            # Find the placement rect on the page
            rects = page.get_image_rects(xref)
            for r in rects:
                w_pt = max(r.width, 0.1)
                h_pt = max(r.height, 0.1)
                pix_w = img_info[2]
                pix_h = img_info[3]
                dpi_x = (pix_w / w_pt) * 72.0
                dpi_y = (pix_h / h_pt) * 72.0
                images.append(
                    EmbeddedImage(
                        xref=xref,
                        rect=(float(r.x0), float(r.y0), float(r.x1), float(r.y1)),
                        width=pix_w,
                        height=pix_h,
                        dpi_x=dpi_x,
                        dpi_y=dpi_y,
                    )
                )
        return images

    def merge_composite_regions(
        self, images: list[EmbeddedImage], gap_tolerance_pt: float = 2.0
    ) -> list[CompositeRegion]:
        """Merges adjacent/overlapping embedded images into composite regions per S-04."""
        if not images:
            return []

        # Sort images by y0, then x0
        sorted_imgs = sorted(images, key=lambda img: (img.rect[1], img.rect[0]))
        composites: list[CompositeRegion] = []

        for img in sorted_imgs:
            merged = False
            ix0, iy0, ix1, iy1 = img.rect

            for comp in composites:
                cx0, cy0, cx1, cy1 = comp.bbox
                # Check horizontal alignment overlap
                x_overlap = max(0.0, min(ix1, cx1) - max(ix0, cx0))
                x_span = max(ix1, cx1) - min(ix0, cx0)

                # Vertical adjacency or overlap
                v_adjacent = (
                    abs(iy0 - cy1) <= gap_tolerance_pt
                    or abs(cy0 - iy1) <= gap_tolerance_pt
                    or (iy0 <= cy1 and iy1 >= cy0)
                )

                if v_adjacent and (
                    x_overlap > 0.5 * min(ix1 - ix0, cx1 - cx0) or abs(ix0 - cx0) < 5.0
                ):
                    # Merge into comp
                    new_bbox = (
                        min(cx0, ix0),
                        min(cy0, iy0),
                        max(cx1, ix1),
                        max(cy1, iy1),
                    )
                    comp.bbox = new_bbox
                    comp.slices.append(img)
                    merged = True
                    break

            if not merged:
                composites.append(
                    CompositeRegion(
                        bbox=img.rect,
                        slices=[img],
                    )
                )

        return composites

    def render_page(self, page_no: int, dpi: int = 300) -> bytes:
        """Renders page as PNG at given DPI."""
        page = self.doc[page_no]
        zoom = dpi / 72.0
        mat = pymupdf.Matrix(zoom, zoom)
        pix = page.get_pixmap(matrix=mat, alpha=False)
        return bytes(pix.tobytes("png"))

    def render_crop(
        self, page_no: int, bbox_pt: tuple[float, float, float, float], dpi: int = 300
    ) -> bytes:
        """Renders a specific bounding box crop as PNG."""
        page = self.doc[page_no]
        zoom = dpi / 72.0
        mat = pymupdf.Matrix(zoom, zoom)
        clip = pymupdf.Rect(*bbox_pt)
        pix = page.get_pixmap(matrix=mat, clip=clip, alpha=False)
        return bytes(pix.tobytes("png"))

    def close(self) -> None:
        self.doc.close()
