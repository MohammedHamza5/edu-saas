"""
VisionEnricher — AI Vision Layer for QBank Pipeline
=====================================================
يحوّل كل صورة مقصوصة (asset block) تحتوي على نصاً متنكراً في صورة
إلى نصوص رقمية نظيفة تماماً.

القرار الأساسي:
  - إذا كانت الصورة = نص/معادلات (الحالة الأغلب في امتحانات ExamView/SAT)
      → يستخرج النص كاملاً ويحذف الصورة
  - إذا كانت الصورة = رسم بياني/مخطط/شكل هندسي (Figure/Diagram)
      → يحتفظ بها كـ asset مع وصف نصي قصير يوضح ما تحتويه
  - يمسح الشوائب تلقائياً: خطوط النقط (____), أرقام النماذج, العلامات المائية

يعمل مع: Gemini 2.0 Flash (google-genai SDK)
الـ Fallback: إذا فشل الاتصال بالـ AI → يُبقي على الـ asset كما هو (graceful degradation).
"""

from __future__ import annotations

import base64
import json
import logging
import os
import re
from typing import Any

logger = logging.getLogger("qb.vision_enricher")

# ── التحقق من وجود الـ API Key وتحميل .env تلقائياً إذا لزم ────────────────
def _load_env_if_needed() -> None:
    if "GEMINI_API_KEY" in os.environ:
        return
    from pathlib import Path
    for candidate in [
        Path(".env"),
        Path(__file__).parent.parent.parent / ".env",
        Path(__file__).parent.parent.parent.parent / ".env",
    ]:
        if candidate.exists():
            try:
                for line in candidate.read_text(encoding="utf-8", errors="replace").splitlines():
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, _, v = line.partition("=")
                        k = k.strip()
                        v = v.strip().strip('"').strip("'")
                        if k not in os.environ:
                            os.environ[k] = v
            except Exception:
                pass
            if "GEMINI_API_KEY" in os.environ:
                break

_load_env_if_needed()
_GEMINI_API_KEY: str | None = os.environ.get("GEMINI_API_KEY")

# ── System Prompt الدقيق ────────────────────────────────────────────────────
_SYSTEM_PROMPT = """You are an expert academic content extraction AI specialized in standardized tests 
(SAT, ACT, ExamView, national math/science exams).

Your ONLY job is to analyze an image from a scanned exam and decide:

1. IS THIS IMAGE "TEXT IN DISGUISE"?
   - If the image contains primarily text, a math problem, a word problem, numbers, 
     physics/chemistry/biology text, multiple-choice options, or any readable academic content → 
     extract ALL the text faithfully and accurately.
   
2. IS THIS IMAGE A REAL VISUAL ELEMENT?
   - If the image contains a geometric figure, graph, chart, data table, 
     circuit diagram, chemical structure, or any visual that CANNOT be expressed as text → 
     keep it as a visual and provide a brief description.

CRITICAL RULES:
- Remove ALL exam artifacts: blank lines (____), fill-in lines, answer box borders, 
  page numbers, module labels ("Module 1", "Section 2"), watermarks, 
  stray question numbers that are NOT part of the content.
- Preserve ALL mathematical expressions exactly. Use LaTeX notation for formulas:
  fractions → \\frac{a}{b}, exponents → x^{2}, roots → \\sqrt{x}, 
  multiplication → \\times, pi → \\pi
- Preserve the EXACT wording. Do NOT paraphrase or summarize.
- If you see a mix (e.g. a geometry problem with both text AND a figure):
  Return the text separately AND mark the figure for preservation.

RESPOND ONLY with valid JSON in this exact schema:
{
  "decision": "text_only" | "figure_only" | "text_and_figure",
  "confidence": 0.0-1.0,
  "extracted_text": "The full extracted text here, with LaTeX for math",
  "figure_description": "Brief description of the visual element (if any)",
  "has_figure": true | false,
  "detected_artifacts": ["list", "of", "removed", "artifacts"]
}
"""

# ── ما هو "رسم بياني حقيقي"؟ ────────────────────────────────────────────────
_FIGURE_DECISIONS = {"figure_only", "text_and_figure"}


def _build_genai_client() -> Any | None:
    """يُنشئ عميل Gemini. يُعيد None إذا لم يكن الـ SDK أو الـ Key متاحَين."""
    api_key = os.environ.get("GEMINI_API_KEY") or _GEMINI_API_KEY
    if not api_key:
        logger.warning("GEMINI_API_KEY not set — VisionEnricher disabled.")
        return None
    try:
        import google.generativeai as genai  # type: ignore[import]
        genai.configure(api_key=api_key)
        model_name = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash")
        return genai.GenerativeModel(
            model_name=model_name,
            generation_config={
                "temperature": 0.0,        # حتمية = لا إبداع، فقط استخراج
                "response_mime_type": "application/json",
                "max_output_tokens": 2048,
            },
            system_instruction=_SYSTEM_PROMPT,
        )
    except ImportError:
        logger.warning("google-generativeai not installed — VisionEnricher disabled.")
        return None
    except Exception as exc:
        logger.warning("Failed to initialize Gemini client: %s", exc)
        return None


class VisionEnrichmentResult:
    """نتيجة إثراء صورة واحدة."""

    def __init__(
        self,
        decision: str,
        confidence: float,
        extracted_text: str,
        figure_description: str,
        has_figure: bool,
        detected_artifacts: list[str],
        raw_response: str = "",
    ):
        self.decision = decision
        self.confidence = confidence
        self.extracted_text = extracted_text.strip()
        self.figure_description = figure_description
        self.has_figure = has_figure
        self.detected_artifacts = detected_artifacts
        self.raw_response = raw_response

    @property
    def is_text_extractable(self) -> bool:
        """هل يمكن تحويل هذه الصورة لنص؟"""
        return bool(self.extracted_text) and self.decision in ("text_only", "text_and_figure")

    @property
    def should_keep_figure(self) -> bool:
        """هل يجب الاحتفاظ برسمة المخطط/الشكل؟"""
        return self.has_figure and self.decision in _FIGURE_DECISIONS


class VisionEnricher:
    """
    طبقة الذكاء الاصطناعي البصري للـ Pipeline.

    الاستخدام:
        enricher = VisionEnricher()
        result = enricher.analyze_crop(crop_png_bytes)
        if result.is_text_extractable:
            # استخدم result.extracted_text بدلاً من الصورة
        if result.should_keep_figure:
            # احتفظ بالصورة كـ asset
    """

    def __init__(self) -> None:
        self._client = _build_genai_client()
        self._enabled = self._client is not None
        if self._enabled:
            model = os.environ.get("GEMINI_MODEL", "gemini-3.8-flash")
            logger.info("VisionEnricher initialized with %s.", model)
        else:
            logger.info("VisionEnricher running in PASSTHROUGH mode (no AI).")

    @property
    def is_enabled(self) -> bool:
        return self._enabled

    def analyze_crop(
        self,
        crop_png_bytes: bytes,
        context_hint: str = "",
    ) -> VisionEnrichmentResult:
        """
        يحلل صورة مقصوصة واحدة ويُعيد قرار الإثراء.

        Args:
            crop_png_bytes: بيانات PNG كـ bytes
            context_hint: سياق اختياري (مثل: "question stem for SAT Math")

        Returns:
            VisionEnrichmentResult مع قرار النص أو الصورة
        """
        _FALLBACK = VisionEnrichmentResult(
            decision="figure_only",
            confidence=0.0,
            extracted_text="",
            figure_description="Original crop (AI unavailable)",
            has_figure=True,
            detected_artifacts=[],
        )

        if not self._enabled:
            return _FALLBACK

        if not crop_png_bytes:
            return _FALLBACK

        try:
            # تحويل الصورة إلى Base64
            b64_image = base64.b64encode(crop_png_bytes).decode("utf-8")

            # بناء الطلب
            prompt_parts = []
            if context_hint:
                prompt_parts.append(f"Context: {context_hint}\n\n")
            prompt_parts.append("Analyze this exam content image:")

            response = self._client.generate_content(
                [
                    "".join(prompt_parts),
                    {
                        "mime_type": "image/png",
                        "data": b64_image,
                    },
                ],
                request_options={"timeout": 30},
            )

            raw_text = response.text.strip()

            # تنظيف إذا جاء مع ```json ... ```
            if raw_text.startswith("```"):
                raw_text = re.sub(r"^```[a-z]*\n?", "", raw_text)
                raw_text = re.sub(r"\n?```$", "", raw_text.strip())

            data: dict[str, Any] = json.loads(raw_text)

            return VisionEnrichmentResult(
                decision=data.get("decision", "figure_only"),
                confidence=float(data.get("confidence", 0.5)),
                extracted_text=data.get("extracted_text", ""),
                figure_description=data.get("figure_description", ""),
                has_figure=bool(data.get("has_figure", False)),
                detected_artifacts=data.get("detected_artifacts", []),
                raw_response=raw_text,
            )

        except json.JSONDecodeError as exc:
            logger.warning("VisionEnricher: JSON parse error: %s", exc)
            return _FALLBACK
        except Exception as exc:
            logger.warning("VisionEnricher: AI call failed: %s", exc)
            return _FALLBACK

    def enrich_stem_blocks(
        self,
        stem_blocks: list[dict],
        crop_bytes_map: dict[str, bytes],
    ) -> list[dict]:
        """
        يُطبق الإثراء الذكي على قائمة stem blocks كاملة.
        يستبدل كل block من نوع 'asset' بـ block(s) نصية إذا كان ذلك ممكناً.

        Args:
            stem_blocks: قائمة Block dicts (من model_dump())
            crop_bytes_map: dict يربط crop_asset path → PNG bytes

        Returns:
            قائمة blocks مُحسَّنة (أنقى وأدق)
        """
        enriched: list[dict] = []

        for block in stem_blocks:
            block_type = block.get("type", "text")

            if block_type != "asset":
                # نص عادي أو معادلة — لا تغيير
                enriched.append(block)
                continue

            crop_path = block.get("crop_asset") or block.get("value", "")
            crop_bytes = crop_bytes_map.get(crop_path, b"")

            if not crop_bytes:
                # لا توجد صورة مسترجعة — أبق الـ asset
                logger.debug("No crop bytes for '%s', keeping as asset.", crop_path)
                enriched.append(block)
                continue

            # 🧠 تحليل الصورة بالذكاء الاصطناعي
            context = f"SAT/ACT exam question stem, source: {crop_path}"
            result = self.analyze_crop(crop_bytes, context_hint=context)

            logger.info(
                "VisionEnricher crop '%s': decision=%s, confidence=%.2f, artifacts=%s",
                crop_path,
                result.decision,
                result.confidence,
                result.detected_artifacts,
            )

            # ── بناء الـ blocks الجديدة ───────────────────────────────────
            new_blocks: list[dict] = []

            # 1. إذا استُخرج نص → أنشئ text block
            if result.is_text_extractable:
                text_block = dict(block)  # copy
                text_block["type"] = "text"
                text_block["value"] = result.extracted_text
                text_block["raw"] = result.extracted_text
                # احذف الحقول الخاصة بالـ asset
                text_block["crop_asset"] = None
                text_block["asset_id"] = None
                text_block["confidence"] = {
                    **block.get("confidence", {}),
                    "ai_vision": round(result.confidence, 3),
                }
                if result.detected_artifacts:
                    text_block.setdefault("uncertain", [])
                    text_block["uncertain"].append({
                        "type": "removed_artifacts",
                        "items": result.detected_artifacts,
                    })
                new_blocks.append(text_block)

            # 2. إذا كان هناك رسم بياني → أبق الـ asset مع وصف
            if result.should_keep_figure:
                figure_block = dict(block)  # copy
                figure_block["type"] = "asset"
                # أضف وصف الرسمة إذا وُجد
                if result.figure_description:
                    figure_block["value"] = result.figure_description
                figure_block["confidence"] = {
                    **block.get("confidence", {}),
                    "ai_vision": round(result.confidence, 3),
                }
                new_blocks.append(figure_block)

            # 3. إذا فشل كل شيء → أبق الأصل
            if not new_blocks:
                logger.warning(
                    "VisionEnricher returned empty for '%s', keeping original asset.",
                    crop_path,
                )
                new_blocks.append(block)

            enriched.extend(new_blocks)

        return enriched
