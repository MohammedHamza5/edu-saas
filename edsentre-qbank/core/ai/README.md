# Vision AI Layer — QBank Pipeline

## الهدف
تحويل **كل سؤال** مستخرج من ملفات الامتحان إلى نص رقمي نظيف 100%،
بدلاً من عرضه كصورة مقصوصة باهتة.

## كيف يعمل

```
PDF → Segmenter → CropImage → [VisionEnricher] → Clean Text or Real Figure
```

### قرارات VisionEnricher لكل صورة:

| نوع المحتوى | القرار | النتيجة |
|---|---|---|
| نص عادي في صورة | `text_only` | → نص رقمي نظيف (يُحذف الـ asset) |
| معادلات رياضية في صورة | `text_only` | → نص بـ LaTeX (`\frac{a}{b}`, `x^2`) |
| رسم بياني / مخطط / شكل هندسي | `figure_only` | → يُبقي الصورة + يضيف وصفاً |
| نص + رسم في نفس الصورة | `text_and_figure` | → نص منفصل + صورة منفصلة |

### ما يُحذف تلقائياً (Artifacts):
- خطوط النقط: `____ 5.` / `____`
- أرقام الموديولات: `Module 1`, `Section 2`
- أرقام الصفحات والترويسات
- العلامات المائية

## التثبيت

```bash
# تثبيت بدون AI (الـ fallback يُبقي الصور كما هي)
pip install -e .

# تثبيت مع AI (موصى به للـ production)
pip install -e ".[ai]"
```

## الإعداد

```bash
# في ملف .env للـ Worker فقط
GEMINI_API_KEY=AIza...
```

> **أمان:** الـ API Key يُوضع فقط في environment variables للـ Worker.
> لا يدخل Flutter، لا يُرفع على Git، لا يُخزن في قاعدة البيانات.

## الـ Fallback (Graceful Degradation)

إذا لم يكن `GEMINI_API_KEY` موجوداً، أو فشل الاتصال بـ Gemini:
- الـ `VisionEnricher` يعمل في **PASSTHROUGH mode**
- الصور تُبقى كـ `asset` blocks كما كانت قبل
- لا يتوقف الـ Pipeline ولا تُفقد أي بيانات

## التكلفة التقديرية

| الامتحان | الأسئلة | تكلفة AI تقريبية |
|---|---|---|
| امتحان SAT كامل (Module 1+2) | ~50 سؤال | < $0.03 (3 سنتات) |
| 100 ورقة امتحان | ~5000 سؤال | < $3.00 |

باستخدام Gemini 2.0 Flash (أسرع وأرخص نموذج في السوق بدقة مرتفعة).

## Flags في قاعدة البيانات

عند نجاح التحويل، يُضاف flag في `qb_question_revisions.provenance.flags`:
```
ai_enriched:2_images_to_text
```
يُمكن استخدامه لاحقاً للفلترة والمراجعة.
