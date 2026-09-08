---
> **Canonical v1.0 · 2026-09-06 · المعتمد الوحيد** — هذه النسخة تحل محل أي ملف قديم بنفس الاسم أو الغرض.
---

# منصة SaaS التعليمية — الوثيقة المرجعية الموحدة
### Master Architecture & Product Reference

| | |
|---|---|
| **النطاق** | كل القرارات المعمارية من Baseline v0.1 حتى v1.21 |
| **الحالة العامة** | 🔒 كل قسم هنا LOCKED إلا ما هو مذكور صراحة تحت "بنود مفتوحة" (قسم 22) |
| **آخر تحديث** | تجميع بتاريخ 6 سبتمبر 2026 |
| **الغرض** | مرجع واحد نهائي يُعطى لأي Developer أو AI Coding Agent قبل بدء أي تنفيذ |

---

## كيفية استخدام هذه الوثيقة

1. هذه الوثيقة تجمع **كل** القرارات المعمارية السابقة (24 ركنًا: v0.1 → v1.21) في مكان واحد، بعد حذف التكرار وحل التعارضات وتوحيد النسخة النهائية لكل قرار (مثال: تصميم `exam_questions` تغيّر بين v1.3 وv1.7/v1.14 — النسخة المعتمدة هنا هي الأحدث فقط).
2. أي تعارض بين نسخة قديمة ونسخة أحدث من نفس القرار في المحادثات الأصلية → **الأحدث هو المعتمد**، وهذه الوثيقة تعكسه فقط.
3. تم أثناء التجميع اكتشاف وإصلاح عدد من الثغرات الهندسية الصغيرة لم تكن مغطاة صراحة في الأركان الأصلية. كل إصلاح مُعلَّم بعلامة **🔧 [إصلاح تجميع]** في مكانه، ومُلخّص بالكامل في قسم "سجل التغييرات" (قسم 23).
4. أي Feature جديدة تُبنى **يجب** أن تُراجَع أولًا مقابل هذه الوثيقة. لا تُعدَّل البنود المقفولة هنا إلا بقرار صريح موثّق كـ"مراجعة" جديدة.

---

## فهرس المحتويات

0. المبادئ الحاكمة العليا
1. تعريف المنتج ونطاق V1
2. تعدد المستأجرين (Multi-Tenancy)
3. الأدوار (Roles) ودورة حياة الحساب
4. قاعدة البيانات الكاملة (Schema)
5. الصلاحيات وRLS (Authorization Matrix)
6. المحتوى، الملفات، والفيديو
7. الواجبات والامتحانات (Academic Layer)
8. الحضور وتتبع النشاط
9. الإشعارات والتواصل
10. التحليلات والتقارير (Analytics)
11. عقد التكامل مع الـBackend (Repository / Edge Functions)
12. الأمان وتحليل التهديدات (Security & Threat Model)
13. الخصوصية والاحتفاظ بالبيانات (🔧 قسم جديد بالكامل)
14. معمارية الـFrontend (State Management + Project Structure)
15. الهوية البصرية ونظام التصميم (UI/UX)
16. الأداء والتخزين المؤقت والعمل دون إنترنت
17. البنية التحتية والنشر (Infrastructure & Deployment)
18. تهيئة المشروع والـPackages
19. التكلفة والاقتصاديات (Cost & Unit Economics)
20. النسخ الاحتياطي والمراقبة والتعافي من الكوارث
21. الاختبار وضمان الجودة (Testing & QA)
22. الاشتراك ودورة حياة الـTenant (⚠️ فجوة موثّقة)
23. عقد الذكاء الاصطناعي الموحّد (AI Coding Contract)
24. بنود مفتوحة / خارطة الطريق
25. سجل التغييرات الكامل لهذا التجميع

---

# 0. المبادئ الحاكمة العليا

هذه المبادئ تحكم **كل** قرار آخر في الوثيقة، ولا يجوز لأي Feature أن تخالفها بدون مراجعة معمارية صريحة:

1. **Flutter عميل غير موثوق (Untrusted Client).** أي بيانات تصل من Flutter (tenant_id، role، status، score، is_correct...) لا تُعتبر حقيقة. الحقيقة تُشتق دائمًا من `auth.uid()` → `public.users` → tenant/role/status.
2. **PostgreSQL + RLS هي خط الدفاع الحقيقي**، وليس إخفاء الأزرار في الواجهة. أي صلاحية لا تُفرض على مستوى الـDatabase تُعتبر غير موجودة أمنيًا.
3. **العزل بين الـTenants مطلق.** لا استثناء، ولا "مؤقتًا" لتسهيل التطوير.
4. **البيانات الأكاديمية التاريخية Immutable.** النتائج والدرجات القديمة لا تتغير بأثر رجعي مهما تغيّر المحتوى أو الامتحان لاحقًا.
5. **العمليات الحساسة تمر عبر Backend/RPC/Edge Function، وتكون Atomic.** لا حسابات درجات أو موافقات أو صلاحيات تُحسم من Flutter مباشرة.
6. **لا نبني تعقيدًا لا نحتاجه الآن.** كل جدول، كل Package، كل طبقة Abstraction يجب أن يكون له سبب حقيقي وليس "لأن SaaS المفروض كده".
7. **الذكاء الاصطناعي منفّذ، وليس مهندسًا معماريًا.** (تفصيل كامل في القسم 23).
8. **لا وعود لا نقدر نوفيها**: لا "Anti-Cheat 100%"، لا "منع تصوير الشاشة"، لا "Unlimited Everything".

---

# 1. تعريف المنتج ونطاق V1

**المنتج:** White-label Education SaaS للمدرسين (وليس موقعًا لمدرس واحد). العميل الحالي هو أول Tenant.

**أهداف التصميم:**
- تشغيل منصة تعليمية حقيقية.
- عزل بيانات كل مدرس تمامًا.
- إمكانية إضافة مدرسين آخرين مستقبلًا دون إعادة هندسة.
- بساطة تجربة الاستخدام للعميل الحالي، دون Enterprise-complexity غير ضرورية.

**نطاق V1:**
- نظام أمريكي (American System)، ~10 طلاب حاليًا.
- الطلاب منظّمون في **Groups** (مثال: Basics, Advanced, SAT, EST, ACT)، وقد ينتمي الطالب لأكثر من Group.
- الـGroup هي الوحدة الأساسية لتوزيع المحتوى.

**التقنية الأساسية:**

| الطبقة | الاختيار |
|---|---|
| Frontend | Flutter Web + Mobile (Android/iOS) |
| Backend | Supabase (Auth + PostgreSQL + Storage + Realtime + Edge Functions) |
| فيديو | Bunny Stream (مرشح معتمد، ليس نهائي 100%) |
| Push | Firebase Cloud Messaging (FCM) — Delivery فقط |
| استضافة الويب | Cloudflare Pages |

---

# 2. تعدد المستأجرين (Multi-Tenancy)

المنصة **Multi-Tenant من الداخل منذ اليوم الأول**، حتى لو كان هناك Tenant واحد فعليًا الآن.

```text
Platform
 ├── Teacher / Tenant A  → Students, Groups, Content, Reports
 ├── Teacher / Tenant B  → ...
 └── Teacher / Tenant C  → ...
```

**المبدأ الذهبي:** بيانات Tenant لا تصل إلى Tenant آخر أبدًا، والعزل مفروض على مستوى Database/RLS وليس Flutter.

**كيف يُشتق الـTenant الحقيقي:**

```text
auth.uid()  →  public.users.id  →  public.users.tenant_id
```

`tenant_id` القادم من Flutter **لا يُستخدم كمصدر ثقة** في أي Query أو Policy أو Edge Function.

---

# 3. الأدوار (Roles) ودورة حياة الحساب

## 3.1 الأدوار الثلاثة في V1

| الدور | أهم الصلاحيات |
|---|---|
| **Teacher** | إدارة كاملة لـTenant الخاص به: الطلاب، الـGroups، المحتوى، الواجبات، الامتحانات، الحضور، النشاط، الإشعارات |
| **Student** | تسجيل الدخول، الوصول لمحتوى Groups الخاصة به، حل الواجبات والامتحانات، رؤية نتائجه ونشاطه فقط |
| **Parent** | متابعة (Read-only) للأبناء المرتبطين به فقط: واجبات، درجات، حضور، نشاط |

**غير موجود في V1 (عمدًا):** Admin, Assistant Teacher, Moderator, Staff — لا تُضاف إلا بحاجة حقيقية مثبتة.

## 3.2 دورة حياة حساب Teacher

الـTenant/Teacher **لا يُنشئ نفسه** عبر تسجيل مفتوح في V1. يتم إنشاؤه أثناء Onboarding من طرف المنصة:

```text
Platform creates Tenant → Create Teacher Auth Account → Create users record
(role=teacher, status=active) → Teacher logs in → Teacher Dashboard
```

## 3.3 دورة حياة حساب Student

```text
Student Registration → status = pending → Teacher Review → Approve/Reject
```

- **pending:** الطالب يسجّل دخول لكن يرى فقط رسالة انتظار الموافقة، ولا يصل لأي محتوى/بيانات أكاديمية.
- **active:** بعد الموافقة. الموافقة **لا تضيفه تلقائيًا لأي Group** — المدرس يُسند العضوية كخطوة منفصلة، لأن الطالب قد ينتمي لأكثر من Group (SAT + EST مثلًا).
- **rejected:** الحساب **لا يُحذف** — يُحتفظ به لسجل من حاول التسجيل، ويمكن للمدرس تحويله لاحقًا إلى active.
- **suspended:** الطالب كان Active وتم إيقافه. يُمنع من الوصول للبيانات التعليمية، لكن حساب الـAuth لا يُحذف، ويمكن إعادة تفعيله (suspended → active).

**حالة الطالب (state machine):**

```text
Register → Pending ⇄ (Rejected | Approved→Active) ⇄ Suspended
```

## 3.4 دورة حياة حساب Parent

```text
Parent Register → Account created → Teacher links Parent ↔ Student (parent_students)
```

- الـParent **لا يربط نفسه بطالب** بنفسه — الربط عملية يقوم بها المدرس/المنصة فقط، منعًا لأي محاولة وصول غير مصرح بها لبيانات طالب عشوائي.
- Parent قد يُربط بأكثر من طفل (`parent_students` علاقة Many-to-Many منطقيًا من جهة الأب).

## 3.5 قواعد أمنية عابرة لكل الأدوار

- `role` القادم من Flutter **لا يُوثق به إطلاقًا**. يُحدَّد Server-side عند إنشاء الحساب ولا يمكن للمستخدم تغييره بنفسه.
- الـRole في Flutter (`if user.role == 'teacher'`) هو UX فقط، وليس Security Boundary.
- Email Verification مستقلة عن Teacher Approval: طالب قد يكون `email verified = true` و`status = pending` في نفس الوقت.
- Password Reset بالكامل عبر Supabase Auth — لا نبني نظام استرجاع كلمة مرور خاص بنا.
- لا حذف نهائي للحسابات في V1 (Student/Parent) — فقط Suspend/Deactivate، حفاظًا على سلامة البيانات التاريخية (درجات، حضور، تسليمات).

## 3.6 🔧 [إصلاح تجميع] دورة حياة الـTenant المعلَّق (Suspended Tenant)

كان معرَّفًا فقط `tenants.status ∈ {active, suspended}` بدون تحديد السلوك الفعلي. **القرار المعتمد الآن:**

عند `tenant.status = suspended`:

| ماذا يحدث | القرار |
|---|---|
| تسجيل دخول مستخدمي هذا الـTenant (Teacher/Student/Parent) | **يُمنع بالكامل** — رسالة واضحة: "This account is currently suspended. Contact support." |
| Sessions مفتوحة مسبقًا | تُبطَل عند أول طلب لاحق يمر عبر أي Policy/Edge Function تتحقق من حالة الـTenant (وليس فقط عند تسجيل الدخول) |
| القراءة أو الكتابة على أي بيانات تابعة للـTenant | **ممنوعة بالكامل** (لا وضع Read-only جزئي في V1 — القرار الافتراضي الأبسط والأكثر أمانًا) |
| المحتوى/الفيديو/الملفات المخزّنة | **لا تُحذف** — تبقى محفوظة لحين إعادة التفعيل أو قرار عمل لاحق |
| إعادة التفعيل | `suspended → active` يعيد كل شيء لوضعه الطبيعي فورًا دون الحاجة لإعادة بناء بيانات |

> هذا القرار (منع كامل بدل Read-only) قابل للمراجعة كقرار عمل تجاري لاحقًا، لكنه **الافتراضي الآمن** لحين اتخاذ قرار مختلف صراحة.

---

# 4. قاعدة البيانات الكاملة (Schema)

> هذه هي **النسخة النهائية المعتمدة** بعد دمج v1.3 وv1.7 وv1.14 (الأحدث يجبّ الأقدم عند التعارض — أهم تعارض: `exam_questions` تنتمي إلى `exam_version_id` وليس `exam_id` مباشرة).

## 4.1 مبادئ عامة

- كل Primary Key: `uuid` (توليد عبر `gen_random_uuid()`)، ما عدا `users.id` الذي **يجب** أن يساوي `auth.users.id` تمامًا (لا UUID منفصل).
- `created_at` / `updated_at`: `timestamptz`، وتُخزَّن UTC دائمًا — التحويل للتوقيت المحلي يتم في التطبيق فقط.
- لا نستخدم PostgreSQL ENUM أنواع صارمة لحقول مثل `role`, `status`, `type` — نستخدم `text` + Application/DB-level validation، لسهولة التوسّع لاحقًا (مثال: مستوى Group جديد يضيفه المدرس بنفسه).
- **لا Hard Delete** للبيانات الأكاديمية ذات القيمة التاريخية (Content, Assignment, Exam, Group, User) — نستخدم `status = archived/suspended` بدل `DELETE`. الحذف الفعلي يُسمح فقط لبيانات مؤقتة/غير حساسة.

## 4.2 الجداول

### tenants
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| name | text | |
| logo_url | text | |
| email | text | |
| phone | text | |
| status | text | `active` \| `suspended` — راجع قسم 3.6 |
| created_at / updated_at | timestamptz | |

### users
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | **= auth.users.id** (نفس القيمة تمامًا) |
| tenant_id | uuid FK → tenants | |
| role | text | `teacher` \| `student` \| `parent` |
| full_name / email / phone / avatar_url | text | |
| status | text | `pending` \| `active` \| `rejected` \| `suspended` |
| last_activity_at | timestamptz | يُحدَّث عند Meaningful Activity فقط (راجع قسم 8) |
| created_at / updated_at | timestamptz | |

### groups
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| tenant_id | uuid FK | |
| name / level / description | text | `level` نص حر وليس Enum |
| previous_content_access | text | `allow` \| `deny` — سياسة على مستوى الـGroup كاملة، وليست لكل طالب |
| status | text | |
| created_at / updated_at | timestamptz | |

### group_members
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| group_id | uuid FK | |
| student_id | uuid FK → users | |
| joined_at | timestamptz | **هذا هو المرجع الزمني لسياسة "المحتوى السابق"** — راجع قسم 6.4 |
| status | text | |
| **Constraint** | `UNIQUE(group_id, student_id)` | يمنع انضمام الطالب مرتين لنفس الـGroup |

### parent_students
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| parent_id | uuid FK → users | |
| student_id | uuid FK → users | |
| relationship | text | |
| created_at | timestamptz | |
| **Constraint** | `UNIQUE(parent_id, student_id)` | |

### content
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| tenant_id / group_id | uuid FK | المحتوى ملك للـGroup وليس لطالب فردي |
| title / description | text | |
| type | text | `video` \| `pdf` \| `image` \| `assignment` \| `exam` |
| status | text | `draft` \| `published` \| `archived` |
| sort_order | integer | ترتيب يدوي، وليس بالاعتماد على `created_at` |
| published_at | timestamptz | |
| created_at / updated_at | timestamptz | |

### files
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| tenant_id / content_id | uuid FK | |
| storage_path / file_name / mime_type | text | الملف الفعلي في Supabase Storage، وهذا Metadata فقط |
| file_size | integer | |
| created_at | timestamptz | |

### videos
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| content_id | uuid FK | |
| provider | text | `bunny` (V1) |
| provider_video_id / thumbnail_url | text | |
| duration | integer | |
| status | text | `uploading` \| `processing` \| `ready` \| `failed` \| `deleted` |
| created_at / updated_at | timestamptz | |

> لا يوجد Video Binary داخل PostgreSQL أبدًا — Metadata فقط. Publish المحتوى **يُمنع** ما لم يكن `videos.status = ready`.

### assignments
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| content_id / tenant_id | uuid FK | |
| instructions | text | |
| due_at | timestamptz | |
| allow_late_submission | boolean | |
| max_score | integer | |
| created_at / updated_at | timestamptz | |

### assignment_submissions
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| assignment_id / student_id | uuid FK | |
| attempt_number | integer | يدعم إعادة الرفع/التسليم |
| submitted_at | timestamptz | |
| status | text | `submitted` \| `reviewed` \| `late` |
| score / teacher_feedback | | |
| reviewed_at / reviewed_by | | |
| **Constraint** | `UNIQUE(assignment_id, student_id, attempt_number)` | |

> **ملاحظة هندسية اختيارية (غير مُلزمة):** نموذج `attempt_number` صحيح ومقفول، لكنه يضيف تعقيدًا (تعريف "أي attempt هو المعتمد؟"). بديل أبسط يمكن اعتماده أثناء التنفيذ الفعلي بدون كسر القرار المعماري: submission واحد "حيّ" لكل طالب + جدول `submission_history` كسجل نصي/JSON للنسخ القديمة عند إعادة الرفع، مع تبسيط الـUNIQUE إلى `(assignment_id, student_id)`. القرار النهائي يُترك لمرحلة التنفيذ.

### submission_files
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| submission_id | uuid FK | |
| storage_path / file_name / mime_type / file_size | | يدعم أكثر من ملف لكل تسليم (صور + PDF) |
| created_at | timestamptz | |

### exams
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| content_id / tenant_id | uuid FK | |
| duration_minutes / max_score / passing_score | | |
| shuffle_questions / show_result / allow_retake | boolean | |
| start_at / end_at | timestamptz | |
| created_at / updated_at | timestamptz | |

### exam_versions **(النسخة المعتمدة النهائية — تحل محل الربط المباشر exam_questions↔exam_id في v1.3)**
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| exam_id | uuid FK | |
| version_number | integer | |
| status | text | `draft` \| `published` \| `archived` |
| created_at / published_at | timestamptz | |

**القاعدة الذهبية لهذا الجدول:** Published Version = **Snapshot غير قابل للتعديل**. أي تعديل جوهري على امتحان له محاولات/طلاب استخدموه ينشئ **Version جديدة**، ولا يُعدَّل القديم أبدًا. راجع قسم 7.3 للتفصيل الكامل.

### exam_questions
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| exam_version_id | uuid FK → exam_versions | **وليس exam_id مباشرة** |
| question_text | text | |
| question_type | text | V1: `multiple_choice` \| `true_false` فقط |
| points / sort_order | | |

### question_options
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| question_id | uuid FK | |
| option_text / sort_order | | |
| is_correct | boolean | **ممنوع أن يصل للطالب في أي Response/API** — يُحقَّق عبر تصميم الـRepository/DTO وليس RLS فقط |

### exam_attempts
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| exam_id / exam_version_id / student_id | uuid FK | المحاولة مرتبطة بالـVersion الدقيقة التي استخدمها الطالب |
| started_at / submitted_at | timestamptz | `started_at` هو مرجع Server-side لحساب انتهاء الوقت |
| status | text | `in_progress` \| `submitted` \| `expired` |
| score / percentage | | تُحسب Server-side فقط، لا يرسلها الطالب أبدًا |
| **Constraint (أصلي)** | — | — |
| **🔧 Constraint [إصلاح تجميع]** | `UNIQUE (exam_id, student_id) WHERE status = 'in_progress'` (Partial Unique Index) | **راجع التفصيل الكامل في قسم 4.3 أدناه — يمنع Race Condition عند فتح الامتحان في أكثر من تبويب/جهاز في نفس الوقت** |

### exam_answers
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| attempt_id / question_id | uuid FK | |
| selected_option_id | uuid FK | الطالب يرسل هذا فقط |
| is_correct / points_earned | | تُحسب وتُخزَّن Server-side وقت التسليم، ولا تُعاد حسابها لاحقًا حتى لو تغيّر السؤال — هذا ما يحافظ على Historical Integrity |
| answered_at | timestamptz | |

### attendance
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| tenant_id / group_id / student_id | uuid FK | |
| date | date | وليس `session_id` — V1 لا يحتاج جدولة حصص كاملة |
| status | text | `present` \| `absent` \| `late` \| `excused` |
| marked_at / marked_by / note | | |
| **Constraint** | `UNIQUE(group_id, student_id, date)` | |

### activity_events
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| tenant_id / user_id / group_id / content_id | uuid FK | |
| event_type | text | Whitelist فقط — راجع قسم 8.1 |
| metadata | jsonb | بيانات إضافية مرنة، لا تُستخدم لتخزين Business Data أساسية |
| created_at | timestamptz | |

### video_progress
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| tenant_id / video_id / student_id | uuid FK | |
| progress_seconds / duration_seconds / percentage | | |
| completed | boolean | راجع تعريف "Completion" في قسم 10.6 |
| last_watched_at | timestamptz | |
| **Constraint** | `UNIQUE(video_id, student_id)` | UPSERT دائمًا — سجل واحد لكل (طالب، فيديو)، وليس سجلًا لكل ثانية مشاهدة |

### notifications
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| tenant_id | uuid FK | |
| title / body | text | لا بيانات حساسة هنا (راجع قسم 9) |
| type | text | Whitelist — راجع قسم 9.4 |
| data | jsonb | للـDeep Linking |
| created_at | timestamptz | |

### notification_recipients
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| notification_id / user_id | uuid FK | إشعار واحد → عدة مستلمين |
| read_at | timestamptz nullable | `NULL` = غير مقروء (وليس `boolean is_read`، لأننا نريد معرفة **متى** قُرئ) |
| created_at | timestamptz | |

### user_devices
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK | |
| platform | text | `android` \| `ios` \| `web` |
| push_token | text | |
| is_active | boolean | يُعطَّل تلقائيًا عند فشل Push المتكرر |
| last_seen_at | timestamptz | |
| created_at | timestamptz | مستخدم واحد قد يملك عدة أجهزة (وليس `user.push_token` عمود واحد) |

### audit_logs
| Column | Type | ملاحظات |
|---|---|---|
| id | uuid PK | |
| tenant_id / actor_user_id | uuid FK | |
| action / entity_type / entity_id | text/uuid | |
| metadata | jsonb | |
| created_at | timestamptz | **غير قابل للتعديل أو الحذف حتى من Teacher** |

## 4.3 🔧 [إصلاح تجميع] معالجة Race Condition في بدء الامتحان

**المشكلة المكتشفة أثناء التجميع:** لو الطالب فتح نفس الامتحان في أكثر من تبويب متصفح، أو ضغط "Start Exam" مرتين بسرعة (اتصال بطيء)، الـFlow الأصلي في `start-exam` (v1.15) كان يمكن أن يُنشئ أكثر من `exam_attempt` بحالة `in_progress` لنفس (طالب، امتحان) قبل أن تكتمل أول Transaction.

**الحل المعتمد (طبقتان):**
1. **على مستوى الـDatabase:** Partial Unique Index:
   ```sql
   CREATE UNIQUE INDEX one_active_attempt_per_student
   ON exam_attempts (exam_id, student_id)
   WHERE status = 'in_progress';
   ```
2. **على مستوى الـEdge Function (`start-exam`):** التحقق من وجود Attempt نشطة قبل الإنشاء، داخل نفس الـTransaction، مع الاعتماد على الـIndex أعلاه كخط دفاع أخير حتى لو حدث Concurrent Request فعليًا (الـFunction تتعامل مع خطأ الـUnique Violation بإرجاع الـAttempt الموجودة فعلًا بدل إنشاء واحدة جديدة أو رمي خطأ غامض للمستخدم).

هذا لا يغيّر أي قرار معماري سابق — هو **سد فجوة تنفيذية** في تصميم موجود بالفعل.

## 4.4 الفهارس الأساسية (Indexes)

```text
users(tenant_id), users(tenant_id, role), users(tenant_id, status)
groups(tenant_id)
group_members(group_id, student_id) [unique], group_members(student_id)
parent_students(parent_id), parent_students(student_id)
content(tenant_id, group_id), content(group_id, status), content(group_id, published_at)
assignments(content_id)
assignment_submissions(assignment_id, student_id)
exams(content_id), exam_versions(exam_id), exam_questions(exam_version_id)
exam_attempts(exam_id, student_id)  [+ partial unique index أعلاه]
attendance(group_id, date), attendance(student_id, date)
activity_events(user_id, created_at), activity_events(tenant_id, created_at)
video_progress(video_id, student_id) [unique]
notifications(tenant_id, created_at)
notification_recipients(user_id, read_at)
```

القاعدة: Index حسب الـQueries الفعلية، وليس "Index لكل عمود".

## 4.5 استراتيجية الـMigrations

- كل تغيير في الـSchema = ملف Migration في Git (`supabase/migrations/NNN_description.sql`)، **لا تعديل يدوي على Production من الـDashboard**.
- ترتيب النشر: `Local → Dev → Review → Production`.
- Migrations هدّامة (`DROP COLUMN` مثلًا) تُنفَّذ على مراحل: إضافة عمود جديد → نشر الكود → ترحيل البيانات → حذف القديم لاحقًا، وليس دفعة واحدة.
- `Seed Data` (بيانات تجريبية) في بيئة Development فقط، ولا تُنقل تلقائيًا لـProduction.

---

# 5. الصلاحيات وRLS (Authorization Matrix)

## 5.1 المبدأ

> Flutter يحدد ما **يظهر**. RLS + Backend يحددان ما **يُسمح فعليًا**.

كل Policy تستخرج هوية المستخدم من `auth.uid()`، ثم Tenant/Role/Status من `public.users` — **لا نثق أبدًا** بأي قيمة (tenant_id, role, status) يرسلها الـClient.

## 5.2 مصفوفة الصلاحيات الكاملة

| المورد | Teacher | Student | Parent |
|---|:---:|:---:|:---:|
| ملفه الشخصي | Read/Write | Read/Write محدود | Read/Write محدود |
| Students | CRUD (Tenant الخاص به) | بياناته فقط | الأبناء المرتبطين فقط |
| Groups | CRUD | القراءة لعضوياته فقط | قراءة لعضوية أبنائه |
| Group Members | CRUD | قراءة عضويته فقط، **لا يضيف نفسه** | قراءة فقط |
| Content | CRUD | قراءة المنشور + المصرح به فقط | قراءة المصرح به لأبنائه |
| Files | CRUD (Tenant) | محتوى مصرّح به / تسليماته الخاصة | محتوى مصرّح به لأبنائه |
| Videos | CRUD metadata | تشغيل مصرّح به (مؤقت) | تشغيل مصرّح به لأبنائه |
| Assignments | CRUD | قراءة + تسليم | قراءة فقط |
| Submissions | قراءة/تقييم | ملكه فقط | ملك أبنائه فقط |
| Exams | CRUD (مع قيود بعد النشر) | أداء/نتيجته فقط | نتيجة أبنائه فقط |
| Questions/Options | CRUD | حقول آمنة فقط (بدون `is_correct`) | حقول آمنة فقط |
| Attempts/Answers | قراءة | ملكه فقط | ملك أبنائه فقط |
| Attendance | CRUD | قراءة فقط | قراءة لأبنائه |
| Activity | قراءة (Tenant) | ملكه فقط | ملك أبنائه |
| Notifications | إنشاء/قراءة | ملكه فقط | ملكه فقط |
| Audit Logs | قراءة محدودة (Backend فقط للكتابة) | ❌ | ❌ |

## 5.3 قواعد أساسية إضافية

- **previous_content_access:** المقارنة تكون دائمًا مع `group_members.joined_at`، وليس تاريخ إنشاء حساب الطالب. محتوى نُشر قبل `joined_at` = "محتوى سابق"، ويخضع لسياسة الـGroup (`allow`/`deny`).
- **Draft Content:** لا يصل لأي طالب مهما عرف الـID، الشرط دائمًا `status = published`.
- **Video:** لا رابط Bunny دائم — Playback عبر Authorization مؤقتة فقط (راجع قسم 6.5).
- **Exam Submission:** الطالب يرسل `selected_option_id` فقط، ولا يرسل أبدًا `score`/`is_correct`/`percentage`.
- **Soft Delete افتراضي**، `DELETE` حقيقي مسموح فقط للبيانات المؤقتة/غير الحساسة (مثل ملف مسودة لم يُنشر بعد).

## 5.4 حماية IDOR (Insecure Direct Object Reference)

كل وصول لمورد بمعرف (`assignment_id`, `content_id`, `exam_id`...) يمر عبر السلسلة الكاملة:

```text
User → Tenant → Group Membership → Resource Authorization
```

وليس فقط "الـUUID صحيح إذن مسموح". امتلاك UUID صالح **لا يعني** صلاحية الوصول.

## 5.5 🔧 [إصلاح تجميع] متطلب اختبار أداء RLS قبل الإطلاق

الـPolicies المتداخلة عبر عدة جداول (مثال: Student → `group_members` → `groups` → `content`) صحيحة أمنيًا لكنها لم تُختبر أداءً. **قبل الإطلاق يجب:**
1. تشغيل `EXPLAIN ANALYZE` على أهم الاستعلامات المحمية بـRLS (قائمة المحتوى للطالب، قائمة الامتحانات، تفاصيل الطالب للمدرس) للتأكد من استخدام الـIndexes الصحيحة وعدم وجود Sequential Scans مخفية داخل الـPolicy نفسها.
2. تكرار هذا الاختبار عند أي إضافة جديدة لعدد الطلاب/الـTenants بشكل ملحوظ (وليس فقط مرة واحدة عند الإطلاق).
3. لو ظهر Bottleneck، الحل المفضل هو تحسين الـIndex/الـPolicy أولًا، وليس تخفيف RLS.

---

# 6. المحتوى، الملفات، والفيديو

## 6.1 دورة حياة المحتوى

```text
Draft (لا يظهر لأحد) → Published (يظهر حسب الصلاحيات) → Archived (لا يظهر، لا يُحذف)
```

## 6.2 المحتوى ملك للـGroup

المحتوى يُنشر مرة واحدة للـGroup بالكامل، وليس لكل طالب على حدة. `sort_order` يحدد ترتيب العرض التعليمي (وليس `created_at`).

## 6.3 أنواع المحتوى (V1)

`video` • `pdf` • `image` • `assignment` • `exam`

## 6.4 سياسة المحتوى السابق (Previous Content Access)

قرار على مستوى الـ**Group بالكامل** (`allow`/`deny`)، وليس لكل طالب يدويًا. المرجع الزمني: `group_members.joined_at` مقابل `content.published_at`.

## 6.5 الفيديو

- **لا** Supabase Storage كـVideo CDN. الفيديو منفصل تمامًا: `Teacher → Video Provider (Bunny) → Encoding → CDN → Student`.
- Supabase يحتفظ فقط بـMetadata (`videos` table).
- **لا رابط دائم/عام** — كل تشغيل يمر عبر Authorization Backend يتحقق من (عضوية Group + نشر المحتوى + سياسة المحتوى السابق) ثم يُصدر صلاحية تشغيل مؤقتة.
- **لا Publish للفيديو** قبل أن يكون `status = ready`.
- Upload مباشر من Flutter إلى Bunny (بعد الحصول على تفويض من Backend)، وليس عبر السيرفر كـProxy — لتقليل التكلفة والحمل.
- Webhook من Bunny → Edge Function → تحديث `videos.status`.
- **لا Download للفيديو في V1** — Streaming فقط، تقليلًا لمخاطر النسخ والتكرار.
- **لا وعد بمنع تصوير الشاشة** — المنتج يُوصف بـ"Protected Streaming"، وليس "100% Anti-Copy".

## 6.6 الملفات (PDF/صور)

- Supabase Storage، **Buckets خاصة (Private) دائمًا**، لا Public Bucket لبيانات الطلاب أبدًا.
- تنظيم المسارات بـUUID-based paths (وليس أسماء ملفات مباشرة):
  ```text
  materials/{tenant_id}/{content_id}/{file_uuid}.ext
  submissions/{tenant_id}/{submission_id}/{file_uuid}.ext
  profiles/{tenant_id}/{user_id}/{file_uuid}.ext
  ```
- الوصول عبر **Signed URL مؤقت** بعد Authorization، وليس رابطًا عامًا دائمًا.
- قيود الرفع: أنواع ملفات محددة (PDF, JPG, JPEG, PNG)، وحد أقصى للحجم، وMIME validation حقيقي (وليس فقط الامتداد).

---

# 7. الواجبات والامتحانات (Academic Layer)

## 7.1 الواجبات (Homework)

```text
Teacher creates → Select Group → Students receive → Student submits →
Teacher reviews → Grade + Feedback → Student sees result → Notification
```

- إعادة الرفع مسموحة (`attempt_number` أو البديل المبسّط في قسم 4.2).
- عدة ملفات لكل تسليم عبر `submission_files`.

## 7.2 الامتحانات — البنية الأساسية

```text
Exam → Questions → Options/Correct Answers → Grades
```

- أنواع الأسئلة في V1: `multiple_choice`, `true_false` فقط — لا Essay/Matching/Drag&Drop إلا بحاجة حقيقية.
- `is_correct` **لا يصل للطالب أبدًا** أثناء أداء الامتحان.

## 7.3 Exam Versioning — القرار النهائي (أهم قرار في هذا القسم)

**المشكلة التي حللناها:** لو المدرس عدّل امتحانًا بعد أن أدّاه طالب، يجب ألا تتأثر نتيجة الطالب القديمة.

**الحل:**

```text
Exam
 ├── Version 1 → Questions → Options   |   Attempts → Answers
 └── Version 2 → Questions → Options   |   Attempts → Answers
```

- **Published Version = Snapshot غير قابل للتعديل** بعد النشر.
- أي تعديل جوهري بعد النشر/الاستخدام → **Version جديدة**، والقديمة تبقى كما هي للأبد.
- كل `exam_attempt` مرتبطة بـ`exam_version_id` محدد — نتيجة الطالب القديمة لا تتغير مهما تغيّر الامتحان لاحقًا.
- دورة حياة الامتحان: `Draft → Published → Active → Closed → Archived`.

## 7.4 التوقيت (Server-Side فقط)

- `started_at` يُسجَّل Server-side عند `start-exam`.
- التحقق من انتهاء الوقت: `server_now <= started_at + duration_minutes` — **لا** يُعتمَد على مؤقّت Flutter كمصدر حقيقة، فقط للعرض.
- انتهاء الوقت تلقائيًا → `status = expired`، مع حفظ آخر إجابات وصلت قبل الانتهاء.

## 7.5 التسليم (Submission) — عملية Atomic واحدة

```text
Validate attempt ownership → Validate timing → Load exact exam_version →
Validate every question/option → Calculate score (Server-side) →
Save answers → Update attempt → Commit (الكل ينجح أو لا شيء يُسجَّل)
```

- الطالب يرسل **إجابات فقط**، أبدًا لا يرسل الدرجة.
- **Idempotency إلزامية:** تسليم مكرر بسبب Network Retry لا يُنتج نتيجتين.
- 🔧 راجع قسم 4.3 لحل Race Condition الخاص بإنشاء أكثر من Attempt نشطة لنفس الطالب.

## 7.6 إعادة المحاولة (Retake)

`allow_retake = true` → أكثر من Attempt مسموح؛ سياسة النتيجة المعروضة في V1: **أعلى درجة (Highest Score)**.

## 7.7 Shuffle

ترتيب الأسئلة (وOptions إن أُضيف لاحقًا) يُثبَّت **وقت بداية الـAttempt** ولا يتغير أثناءه — لكل Attempt ترتيبه الخاص المحفوظ.

## 7.8 حدود واقعية (Anti-Cheat)

النظام يوفر: توقيت Server-side، تسليم Atomic، حساب Server-side، عدم كشف الإجابات الصحيحة، تجميد النسخة المنشورة. **لا** يُقدَّم كوعد بمنع الغش الكامل — لا "Anti-Cheat System" في أي مادة تسويقية.

---

# 8. الحضور وتتبع النشاط

## 8.1 Activity Events (Whitelist فقط)

```text
login • content_opened • video_started • video_completed •
assignment_submitted • exam_started • exam_submitted
```

**لا** نسجل: `click`, `scroll`, `hover`, كل حركة UI — هذا Tracking بلا قيمة ويضخّم الـDatabase بلا داعٍ.

## 8.2 Last Activity ≠ Logout Time

`users.last_activity_at` يتحدث عند Meaningful Activity فقط. **لا نَعِد** بـ"وقت خروج دقيق" — المتصفح/الموبايل لا يضمنان Logout صريحًا دائمًا. العبارة الصحيحة: "آخر نشاط معروف كان الساعة كذا"، وليس "خرج الساعة كذا".

## 8.3 الحضور (Attendance)

سجل يومي بسيط (`date`, وليس `session_id`) — لا نبني جدولة حصص كاملة قبل وجود حاجة حقيقية. `UNIQUE(group_id, student_id, date)` يمنع تكرار التسجيل.

## 8.4 تتبع تقدم الفيديو (Video Progress)

- سجل واحد لكل (طالب، فيديو) يُحدَّث بـUPSERT — **ليس** سجلًا لكل ثانية مشاهدة.
- الإرسال من الـPlayer يكون دوريًا (كل عدة ثوانٍ / عند pause / seek / خروج / اكتمال)، وليس كل ثانية.
- **Resume:** الطالب يعود لآخر `progress_seconds` محفوظة.

## 8.5 Audit Log ≠ Activity Log (فرق جوهري)

| | Activity | Audit |
|---|---|---|
| مثال | "الطالب شاهد فيديو" | "المدرس حذف Assignment" |
| الهدف | Learning Analytics | Security/Accountability |
| من يكتبه | النظام تلقائيًا لأي مستخدم | Backend عند فعل إداري حساس فقط |
| هل يُعدَّل/يُحذف | لا (لكنه Signal وليس إثباتًا قاطعًا) | **لا أبدًا، حتى من Teacher** |

---

# 9. الإشعارات والتواصل

## 9.1 المبدأ

```text
Database = مصدر الحقيقة  →  Push (Web/Android/iOS) = مجرد وسيلة توصيل
```

Push قد يفشل (Token قديم، إذن مرفوض، ظروف متصفح) — لذلك **In-App Notification أولًا دائمًا**:

```text
Event → Create Notification (DB) → Attempt Push Delivery
```

وليس `Event → Push only`.

## 9.2 نموذج البيانات

`notifications` (المحتوى العام) ← `notification_recipients` (لكل مستخدم، مع `read_at`) ← `user_devices` (لكل جهاز/منصة، يدعم أكثر من جهاز للمستخدم الواحد).

`read_at = NULL` يعني غير مقروء؛ `read_at = timestamp` يعني مقروء ومتى بالضبط.

## 9.3 القنوات الثلاث

```text
In-App Notifications  |  Web Push (Browser)  |  Mobile Push (FCM: Android/iOS)
```

FCM = **بنية توصيل فقط**، وليس مصدر بيانات الإشعار.

## 9.4 أنواع الإشعارات (Whitelist)

```text
new_content • assignment_created • assignment_due • assignment_reviewed •
exam_published • exam_result • attendance_marked • important_announcement
```

## 9.5 مصفوفة الاستقبال

| الحدث | Teacher | Student | Parent |
|---|:---:|:---:|:---:|
| تسجيل طالب جديد | ✅ | — | — |
| اعتماد الطالب | — | ✅ | — |
| محتوى/واجب جديد | — | ✅ | Optional |
| تسليم واجب | ✅ | — | Optional |
| مراجعة واجب | — | ✅ | Optional |
| نشر/نتيجة امتحان | — | ✅ | ✅ (نتيجة فقط) |
| تسجيل حضور | — | ✅ | ✅ |
| إعلان مهم | ✅ | ✅ | ✅ |

## 9.6 الأمان والخصوصية في الإشعارات

- **لا بيانات حساسة** في Push Payload/Title/Body (لا درجات دقيقة على Lock Screen — "نتيجتك متاحة الآن" وليس "حصلت على 92/100").
- `notification.data` يحتوي مرجعًا (`assignment_id` مثلًا) للـDeep Linking، لكن **وجود المرجع لا يمنح صلاحية وصول** — يُعاد التحقق من Authorization عند فتح الشاشة.
- Parent يستقبل فقط ما يخص أبناءه المرتبطين به (`parent_students`)، مفروض Backend/RLS.

## 9.7 منع التكرار (Duplicate Notifications)

عمليات حساسة (تسليم واجب، تسليم امتحان) تعتمد على Idempotency + Unique Constraints + معالجة الأحداث Server-side، لمنع إشعارات مكررة بسبب Network Retry.

## 9.8 فشل الـPush

لو فشل التوصيل: **الإشعار يبقى محفوظًا** في `notifications`/`notification_recipients` ويظهر عند فتح التطبيق لاحقًا — لا يُحذف أبدًا بسبب فشل التوصيل.

## 9.9 طلب إذن الإشعارات (Web)

لا يُطلب الإذن فور فتح الموقع. يُطلب بعد شرح السبب:

```text
"Stay updated — get notified when: new lessons published, homework reviewed,
exam results available." [Enable Notifications] [Not now]
```

## 9.10 ما لا نبنيه في V1

❌ Chat/Messaging بين المستخدمين، ❌ SMS، ❌ Email Marketing، ❌ Quiet Hours، ❌ تفضيلات إشعارات متقدمة، ❌ Notification Analytics Dashboard، ❌ AI-generated notifications.

المدرس يستطيع فقط إرسال **Announcement** (عنوان + نص + استهداف: كل الطلاب أو Group محدد) — وهذا **ليس** Chat.

---

# 10. التحليلات والتقارير (Analytics)

## 10.1 الفرق الجوهري: Activity Events vs Aggregated State

```text
Raw Events (activity_events)  → تاريخ ماذا حدث
Current State (last_activity_at, video_progress, scores, attendance) → الوضع الحالي بسرعة
```

**لا** نحسب كل Dashboard من ملايين الـevents الخام مباشرة — نعتمد على الحقول المجمَّعة/المتخصصة (`video_progress`, `assignment_submissions`, إلخ).

## 10.2 تعريف "Average Progress" (كان غامضًا، الآن محدد)

**لا** معادلة سحرية تجمع (حضور + فيديو + امتحانات + واجبات) في رقم واحد مضلِّل. بدلًا من ذلك:

- **Average Progress** في Dashboard المدرس = متوسط نسبة إكمال المحتوى التعليمي القابل للقياس فقط (فيديوهات بشكل أساسي).
- الأداء الأكاديمي (Attendance / Assignments / Exams / Content Completion) يظهر **منفصلًا دائمًا**، وليس مدموجًا في رقم واحد.

## 10.3 متى نعتبر الفيديو "Completed"؟

**لا** يُعتمد `percentage == 100%` (بسبب Buffering/Seek). يُحدَّد Threshold تقني واضح قريب من نهاية الفيديو أثناء التنفيذ/POC، مع تسجيل Progress دوريًا — الفكرة: معيار تقني واضح، وليس مجرد ضغط Play.

## 10.4 Student 360° View

ملف الطالب الواحد يجمع: Groups، Attendance %، Assignments (مُسلَّم/مُراجَع)، Exams (متوسط)، Video Completion %، Last Activity — بدل أن يتنقل المدرس بين 5 شاشات منفصلة.

## 10.5 Parent Dashboard

ملخص مفهوم فقط (لا Raw Database)، ولا تفاصيل تقنية/أمنية/IDs داخلية.

## 10.6 ما لا نبنيه في V1

❌ AI Risk Score ("الطالب معرّض للفشل بنسبة 83%" بدون نموذج علمي حقيقي) — بدلًا منه Rules-based indicator بسيط اختياري لاحقًا ("Needs Attention" عند غياب نشاط 7 أيام + انخفاض تسليم + حضور منخفض)، وليس أساسيًا في V1.
❌ Video Heatmap متقدم، ❌ Analytics Engine/BI Dashboard كامل، ❌ Excel/PDF Export (مؤجَّل لـV1.1/V2 لكن الـArchitecture لا تمنعه).

## 10.7 الاحتفاظ بالبيانات (Retention) — تمهيد لقسم 13

البيانات الأكاديمية (نتائج، حضور، تسليمات) **لا تُحذف تلقائيًا** أبدًا. `activity_events` قد تحتاج سياسة Retention مستقبلية بعد معرفة الحجم الحقيقي للاستخدام — **لا نحذفها الآن قبل قياس الحجم فعليًا**. (راجع القسم 13 للتفصيل الكامل المتعلق بالخصوصية).

---

# 11. عقد التكامل مع الـBackend (Repository / Edge Functions)

## 11.1 تدفق الطبقات (إلزامي، لا استثناء)

```text
UI (Widget) → Cubit (State فقط) → Repository (Interface) →
DataSource (Supabase تحديدًا) → Supabase
```

**ممنوع تمامًا:** استدعاء Supabase مباشرة داخل Widget أو داخل `build()`.

## 11.2 متى نستخدم Supabase مباشرة (CRUD + RLS)؟

عمليات بسيطة لا تحمل حساسية خاصة ولا خطوات متعددة: قراءة محتوى مصرّح به، قراءة Groups/Students/Notifications، تحديث الملف الشخصي، قراءة Attendance/Video Progress.

## 11.3 متى نستخدم Edge Function / RPC (إلزامي)؟

أي عملية: حساسة، متعددة الخطوات، تحتاج Secret، تتعامل مع خدمة خارجية، أو لا يجب الوثوق فيها بمدخلات العميل:

```text
approve-student  |  start-exam  |  submit-exam  |
video-playback   |  bunny-webhook  |  send-notification  |  record-activity
```

## 11.4 أمثلة تفصيلية

**approve-student:** يتحقق JWT → يحدد Teacher الحقيقي وTenant → يتحقق أن الطالب المستهدف pending ونفس الـTenant → يحدّث الحالة → Audit log → Notification. الطالب لا يُفعَّل نفسه أبدًا.

**submit-exam:** Transaction واحدة (Validate ownership → Validate timing → تحميل الـVersion الدقيقة → التحقق من كل إجابة → حساب الدرجة → حفظ الإجابات → تحديث الـAttempt → Commit). الكل ينجح أو لا شيء يُسجَّل.

**video-playback:** تحقق من (عضوية Group + نشر المحتوى + previous-content policy) → تفويض تشغيل مؤقت من Bunny → لا رابط دائم يعود لـFlutter.

## 11.5 Secrets — لا استثناء

`SUPABASE_SERVICE_ROLE_KEY`, `BUNNY_API_KEY`, `BUNNY_WEBHOOK_SECRET`, `FCM_SERVER_CREDENTIALS` تعيش **فقط** داخل Supabase Edge Function Secrets. **لا تدخل** Flutter/.env داخل الـBuild/GitHub تحت أي ظرف.

## 11.6 معالجة الأخطاء (Error Contract موحّد)

Backend يرجّع فئات أخطاء واضحة (`AUTH_REQUIRED`, `NOT_AUTHORIZED`, `VALIDATION_ERROR`, `EXAM_EXPIRED`, `EXAM_ALREADY_SUBMITTED`, `VIDEO_NOT_READY`...)، تُحوَّل في الـRepository إلى `AppException` نوعية (`AuthException`, `PermissionException`, `ValidationException`...)، ثم Cubit يحوّلها لحالة UI مفهومة — وليس عرض Stack Trace خام للمستخدم.

## 11.7 Idempotency

عمليات حساسة (submit exam, approve student, send notification) يجب ألا تُنتج نتائج مضاعفة عند تكرار الطلب بسبب ضعف الشبكة.

---

# 12. الأمان وتحليل التهديدات (Security & Threat Model)

## 12.1 المبدأ الحاكم

> **Never trust the client.** أي شيء قادم من Flutter/Browser/HTTP Request = غير موثوق افتراضيًا.

## 12.2 طبقات الحماية

```text
HTTPS/TLS → Supabase Auth (JWT Identity) → Tenant Isolation →
RLS → Backend Validation → Business Rules → Database
```

لا نعتمد على طبقة واحدة أبدًا.

## 12.3 مصفوفة التهديدات الأساسية

| التهديد | آلية الدفاع |
|---|---|
| Role Escalation (طالب يدّعي أنه Teacher) | Role يُحدَّد Server-side فقط، RLS يتحقق منه دائمًا |
| Cross-Tenant Access | Tenant Isolation عبر `auth.uid() → users.tenant_id`، لا ثقة بـtenant_id من العميل |
| IDOR (تخمين UUID) | Authorization كاملة عبر سلسلة العضوية، وليس مجرد صحة الـUUID |
| Parent يرى طفلًا غير مرتبط | فرض `parent_students` في كل Policy |
| تسريب محتوى Draft/غير منشور | فحص `status = published` إلزامي في كل Policy/Query |
| سرقة فيديو (رابط دائم) | Playback مؤقت ومفوَّض فقط، لا رابط عام دائم |
| تزوير نتيجة امتحان | حساب Server-side حصري، الطالب لا يرسل الدرجة أبدًا |
| تسريب الإجابة الصحيحة | `is_correct` لا يُعاد للطالب في أي Response |
| التلاعب بالتوقيت (تغيير ساعة الجهاز) | Server time هو المرجع الوحيد للتحقق من الانتهاء |
| تسليم مزدوج (Double Submit) | Idempotency + Atomic Transaction + Unique Constraints |
| فتح تابات متعددة للامتحان (Multi-Tab Exploit) | قيد `one_active_attempt_per_student` (Partial Unique Index) يمنع أي محاولة متزامنة + استئناف إجباري |
| تسليم متزامن من تابات متعددة (Multi-Tab Double Submit) | دالة `submit-exam` كـ Atomic Transaction مع Idempotency؛ أول طلب يقفل الحالة، واللاحق يُرفض فورًا |
| التلاعب بساعة الجهاز في نافذة خاملة (Timer Tampering) | المرجع الزمني حصري لساعة السيرفر (`server_now <= started_at + duration_minutes`)، والتأخير = `EXAM_EXPIRED` |
| تزوير مشاهدات الفيديو بتابات متوازية (Video Multi-Tab Farming) | قيد `UNIQUE(video_id, student_id)` + Throttled Upsert مع فحص التقدم المنطقي الفعلي |
| تسريب Secrets | Secrets داخل Edge Functions فقط، أبدًا داخل Flutter/Git |
| تزوير Activity (إرسال `video_completed` يدويًا) | Activity Events تُعامَل كـ"إشارة تحليلية"، وليست إثباتًا أمنيًا قاطعًا |

## 12.4 قاعدة Draft/Previous-Content

نفس فحوصات قسم 5 و6.4 — يُعاد التأكيد هنا كـThreat: طالب يحاول الوصول لمحتوى Draft أو محتوى سابق ممنوع بالـUUID مباشرة → يجب أن يفشل دائمًا Server-side بغض النظر عن أي إخفاء في الواجهة.

## 12.5 اختبارات أمنية إلزامية قبل الإطلاق (سيناريوهات هجوم فعلية)

```text
Student A → Student B data           ❌ يجب أن يفشل
Student A → Tenant B data            ❌ يجب أن يفشل
Parent A → Child B (غير مرتبط)        ❌ يجب أن يفشل
Student → Draft Content              ❌ يجب أن يفشل
Student → محتوى فيديو غير مصرّح      ❌ يجب أن يفشل
Student → تعديل درجته                 ❌ يجب أن يفشل
Student → رؤية الإجابة الصحيحة قبل التسليم ❌ يجب أن يفشل
Student → عملية إدارية (approve/grade) ❌ يجب أن يفشل
Student → فتح محاولة امتحان ثانية بتاب موازٍ ❌ يجب أن يفشل
---
Student → محتواه الخاص                ✅ يجب أن ينجح
Parent → طفله المرتبط                 ✅ يجب أن ينجح
Teacher → بيانات Tenant الخاص به       ✅ يجب أن ينجح
```

هذه السيناريوهات تُكتب كـTests فعلية (وليس فقط توثيقًا)، قبل أي إصدار Production.

## 12.6 حدود واقعية معلَنة

النظام **لا يدّعي**: منع الغش 100%، منع تصوير الشاشة، أمانًا "مستحيل اختراقه". الهدف الواقعي: كل عملية حساسة محمية في الطبقة التي تملك السلطة الحقيقية عليها.

## 12.7 🔧 [تحصين أمني] حماية التزامن وتعدد النوافذ (Multi-Tab & State Desynchronization Defense)

محاولة الطالب استغلال فتح التطبيق في أكثر من نافذة أو لسان تبويب (Browser Multi-Tabs / Split-Brain Concurrency) هي ناقل هجوم معتاد في المنصات التعليمية. يتم تحصين المنصة ضده بالآتي:

1. **على مستوى قاعدة البيانات (PostgreSQL - خط الدفاع النهائي والملزم):**
   - **منع تعدد المحاولات المتزامنة:** الفهرس الجزئي الفريد:
     ```sql
     CREATE UNIQUE INDEX one_active_attempt_per_student 
     ON exam_attempts (exam_id, student_id) 
     WHERE status = 'in_progress';
     ```
     يمنع فيزيائيًا إنشاء أي محاولة جديدة لنفس الطالب لنفس الامتحان طالما توجد محاولة قائمة، ويرجع خطأ `ATTEMPT_ALREADY_EXISTS` مع توجيه الطالب لاستئناف نفس المحاولة دون أي زيادة في الوقت.
   - **الذرية المطلقة للتسليم (Atomic Submit):** لا يمكن تسليم الامتحان مرتين؛ فحص `status = 'in_progress'` وتحديث السجل إلى `submitted` وحساب الدرجة يتم داخل ترانزاكشن خادمية ذرية واحدة. أي طلب تسليم ثانٍ يصل متأخرًا بأجزاء من الثانية يجد الحالة تغيرت فيتم إسقاطه فورًا بـ `EXAM_ALREADY_SUBMITTED`.
   - **المؤقت الخادمي غير القابل للتلاعب:** انتهاء وقت الامتحان محكوم بـ `now() <= started_at + (duration_minutes * interval '1 minute')` على الخادم، مما يلغي تمامًا أي أثر لإيقاف تشغيل الجافاسكريبت أو تجميد التاب في الخلفية؛ وأي إجابة بعد انقضاء الوقت الخادمي تُرفض وتُسجل كـ `EXAM_EXPIRED`.
   - **منع مزارع المشاهدة (Video Farming):** جدول `video_progress` مقيد بـ `UNIQUE(video_id, student_id)`، مع تحديث دوري مقيد (Throttled Upsert)، ولا تُعتمد ساعات المشاهدة كدرجة أكاديمية تمنح امتيازًا تلقائيًا.

2. **على مستوى واجهة العميل (Flutter Web - UX Guard):**
   - تفعيل آلية مزامنة النوافذ (Tab Synchronization عبر Web BroadcastChannel / LocalStorage Storage Events) لتحذير الطالب فور فتح الامتحان في نافذة أخرى، وتعطيل التفاعل في النافذة القديمة تجنبًا لتشتت الإجابات أو الإرباك.

---

# 13. الخصوصية والاحتفاظ بالبيانات

> **🔧 [إصلاح تجميع] — قسم جديد بالكامل.** لم تكن الوثائق الأصلية تحتوي على معالجة صريحة لخصوصية بيانات القُصَّر رغم أن أغلب المستخدمين طلاب تحت 18 سنة. هذا القسم سد أساسي وليس رأيًا قانونيًا — **يجب مراجعته من محامٍ مختص بقوانين حماية البيانات في مصر/السوق المستهدف قبل الإطلاق التجاري**، فهذه ملاحظات هندسية وليست استشارة قانونية.

## 13.1 لماذا هذا القسم ضروري

المنصة تخزّن أساسًا بيانات طلاب (غالبيتهم قُصَّر): أسماء، بيانات تواصل، درجات، حضور، نشاط، وأحيانًا ملفات (صور حلول واجبات). هذا يستوجب حدًا أدنى من الضوابط الهندسية بغض النظر عن التفاصيل القانونية الدقيقة لكل سوق.

## 13.2 مبادئ هندسية مقترحة (Non-Legal, Technical Baseline)

1. **الحد الأدنى من البيانات (Data Minimization):** لا نجمع بيانات عن الطالب غير الضرورية للتشغيل (لا نطلب مثلًا تفاصيل شخصية زائدة عن full_name/email/phone).
2. **الموافقة عبر ولي الأمر عمليًا:** بما أن الموافقة على تفعيل الطالب تمر أصلًا عبر المدرس (وهو جهة موثوقة تعرف الطالب/ولي أمره)، هذا يوفر طبقة مراجعة بشرية، لكنه **ليس بديلًا** عن مراجعة قانونية لمتطلبات موافقة ولي الأمر الصريحة إن وُجدت في القانون المحلي.
3. **حسابات الطلاب المرفوضة (rejected):** تُحتفَظ بها لغرض تشغيلي (سجل من حاول التسجيل)، لكن يجب تحديد مدة احتفاظ معقولة لاحقًا بدل الاحتفاظ الدائم بلا حد.
4. **حذف/تعطيل عند طلب ولي الأمر أو المدرسة:** لا يوجد حاليًا Flow رسمي لـ"طلب حذف بيانات طالب" (Right to be forgotten-style request). **هذا بند مفتوح** يجب حسمه قبل نمو قاعدة العملاء (راجع قسم 24).
5. **بيانات الفيديو/الصور الخاصة بالطالب:** تخضع لنفس معايير الـPrivate Storage (قسم 6.6) — لا Public Bucket، ولا فهرسة علنية.
6. **الإشعارات:** لا تُعرض بيانات أكاديمية حساسة في Push/Lock Screen (مُطبَّق فعلًا في قسم 9.6).
7. **عدم البيع/المشاركة مع أطراف ثالثة:** بيانات الطلاب لا تُستخدم لأغراض تسويقية أو تُشارَك مع أي طرف ثالث خارج ما يخدم تشغيل المنصة (Bunny للفيديو، FCM للإشعارات، وكلاهما Delivery-only ولا يُعطى بيانات أكثر من اللازم).
8. **الاحتفاظ بـ`activity_events`:** كما ذُكر في قسم 10.7، لا حذف تلقائي الآن، لكن يجب وضع سياسة Retention صريحة (مثال: 12-24 شهرًا) بعد قياس الحجم الفعلي، بدل تركها بلا نهاية.

## 13.3 توصية عملية

قبل توسيع قاعدة العملاء (أكثر من Tenant واحد)، يُنصَح بجلسة مراجعة قانونية قصيرة تحدد: (أ) هل يلزم نص موافقة صريح من ولي الأمر عند تسجيل الطالب، (ب) مدة الاحتفاظ القانونية بالبيانات التعليمية، (ج) آلية طلب حذف البيانات. هذه ليست قرارات هندسية بحتة.

---

# 14. معمارية الـFrontend

## 14.1 إدارة الحالة: Cubit (وليس Riverpod)

**القرار النهائي بعد المقارنة:** `flutter_bloc` + **Cubit**، وليس Riverpod، رغم أن الاثنين كانا مناسبين تقنيًا.

**السبب الحقيقي:** خبرة الفريق الحالية مع Cubit/MVVM، وTimeline المشروع (~شهر) يجعل سرعة التنفيذ وثقة الـDeveloper أهم من اتباع الأحدث تقنيًا. **معظم الشاشات طبيعتها بسيطة** (Load/Display/Action/Reload/Error) وهذا مناسب تمامًا لـCubit، وBloc/Events يُستخدَم فقط عند State Machine معقدة فعليًا (نادر في V1).

**قاعدة عدم الربط:** الـArchitecture لا تُربَط بأداة الـState Management — لو تغيّرنا لاحقًا (Cubit → Riverpod)، الطبقات الأدنى (Repository/DataSource/Supabase) لا تتأثر:

```text
UI → Cubit → (UseCase اختياري) → Repository (Interface) → DataSource → Supabase
```

## 14.2 هيكل المشروع (Feature-First + Pragmatic Clean Architecture)

```text
lib/
├── core/
│   ├── config/  constants/  errors/  extensions/  localization/
│   ├── router/  theme/  utils/  widgets/
├── features/
│   ├── auth/  dashboard/  students/  groups/  content/
│   ├── assignments/  exams/  attendance/  videos/
│   ├── notifications/  parent/  profile/
└── main.dart
```

كل Feature: `data/ (datasources, models, repositories)` + `domain/ (entities, repositories, usecases)` + `presentation/ (cubit, pages, widgets)` — لكن **لا نفرض** UseCase لمجرد الشكل؛ نستخدمه فقط عند عملية Business-heavy تستحق العزل (مثال: `SubmitExamUseCase` مفيد، `GetProfileUseCase` غالبًا لا يضيف شيئًا).

## 14.3 قواعد صارمة

- **لا** Supabase calls داخل Widgets، **لا** داخل `build()`.
- **لا** Cubit واحد ضخم للتطبيق كله (`AppCubit` يدير كل شيء) — Cubit لكل مسؤولية/شاشة.
- Video/Storage/Auth كلها خلف Repository Abstraction — تغيير Bunny أو Supabase لاحقًا لا يعني إعادة كتابة الـFeature.
- Cross-Feature Communication عبر تغييرات الـBackend/Realtime/Notification، وليس Cubit يستدعي Cubit آخر مباشرة.
- Naming: `snake_case` للملفات، `PascalCase` للـClasses، وممنوع أسماء غامضة (`Helper`, `Manager`, `Utils`) بدون مسؤولية واضحة.
- ترتيب بناء الـFeatures: Bootstrap → Theme → Supabase → Auth → Routing → Onboarding → Students → Groups → Content → Assignments → Exams → Attendance → Videos → Notifications → Parent → QA/Production.

---

# 15. الهوية البصرية ونظام التصميم (UI/UX)

## 15.1 الاتجاه البصري: "Modern Mathematical Academic SaaS"

ليس LMS تقليديًا كرتونيًا، وليس Enterprise Admin Panel. الهدف: لو أخذنا Screenshot بدون Logo، يجب أن يقول المستخدم "دي منصة تعليم رياضيات" **دون** كتابة كلمة "Math" صراحة في أي مكان — عبر لغة التصميم نفسها (أرقام بارزة، Grid/Graph خفيف، رموز رياضية شفافة جدًا مثل ∑ π √x f(x)، دقة هندسية، بساطة).

## 15.2 نظام الألوان (Tokens وليس ألوان مباشرة)

Primary (Deep Indigo/Mathematical Blue) • Background (Off-white دافئ) • Surface (أبيض) • Text (Charcoal/Navy) • Accent محدود جدًا لعناصر الـAction • Success/Warning/Error/Info دلالية فقط. **ممنوع** Rainbow UI أو أكثر من 3-4 ألوان أساسية.

## 15.3 مبادئ عامة

- Typography: عناوين هندسية حديثة + Body واضح، مع دعم عربي/إنجليزي وRTL/LTR كاملين من اليوم الأول. الأرقام (`82%`, `03:42`, `10 Students`) تُعامَل كعنصر بصري بارز، وليست نصًا عاديًا.
- Spacing/Radius/Shadows: نظام ثابت (4/8/12/16/20/24/32/40/48/64 للمسافات)، Radius متوسط (8-16)، **Border أفضل من Shadow ثقيل** لإحساس SaaS احترافي.
- Design System موحّد (`AppButton`, `AppTextField`, `AppCard`, `AppLoading`, `AppErrorView`, `AppEmptyView`...) — لا شاشة تخترع Component خاصًا بها.
- Loading = Skeletons (وليس CircularProgressIndicator وحده في كل مكان). Empty/Error States تحمل شخصية المنتج لكن بدون إفراط.
- **Light Theme فقط في V1** (Dark Mode لاحقًا بدون كسر الـTokens). Animation قليلة ووظيفية (لا Parallax/Glassmorphism/Neon).
- Navigation مختلفة تمامًا حسب الدور (Teacher/Student/Parent) — لا Dashboard واحد بشرط `if role ==`.
- **Logo:** لا كليشيهات (لا آلة حاسبة، لا قبعة تخرج، لا حرف M) — شكل هندسي مجرد مستوحى من Graph/∑/نظام إحداثيات.

## 15.4 الأداء كجزء من التصميم

تجنّب الصور الضخمة، إعادة البناء غير الضرورية، الـAnimations الثقيلة. Pagination وLazy Loading وImage Caching جزء من "التصميم الجيد" وليس تفصيلًا تقنيًا منفصلًا.

---

# 16. الأداء والتخزين المؤقت والعمل دون إنترنت

## 16.1 القرار الجوهري: Online-First + Offline-Tolerant (وليس Offline-First)

Supabase/PostgreSQL هو **مصدر الحقيقة دائمًا** (امتحانات، نتائج، حضور، تسليمات، موافقات — كلها بيانات مركزية يجب أن تكون لحظية وصحيحة). لكن التطبيق **لا ينهار** عند انقطاع مؤقت للإنترنت.

## 16.2 لماذا لا Drift/Local DB كامل في V1؟

Drift يضيف: Local DB + Sync Engine + Conflict Resolution + Cache Invalidation + Offline Queues + تعقيد اختبار كبير — **لا يستحقه** مشروع بـTimeline شهر واحد وهذه المتطلبات. يُضاف لاحقًا **Feature-specific فقط** عند حاجة حقيقية مثبتة (مثال مستقبلي: تسجيل حضور 200 طالب بدون إنترنت).

## 16.3 استراتيجية الـCache (3 فئات بيانات)

| الفئة | أمثلة | الاستراتيجية |
|---|---|---|
| قصيرة العمر | Notifications, Activity, Dashboard metrics | شبكة مباشرة، بدون Cache طويل |
| مناسبة للـCache | Groups, Students, Content list, Profile | Memory Cache → عرض فوري → Background Refresh |
| الفيديو | — | **لا Cache كامل داخل التطبيق أبدًا** — Streaming عبر Bunny فقط |

## 16.4 قواعد إلزامية

- **Pagination دائمًا** (20-25 عنصر/طلب) لأي قائمة قد تكبر (طلاب، محتوى، تسليمات، نشاط، إشعارات) — لا `SELECT *` بلا حدود.
- **Search/Filter/Sort على مستوى Database**، وليس تحميل كل البيانات ثم الفلترة في Flutter.
- **Video Progress Throttled** — إرسال دوري (كل عدة ثوانٍ/عند أحداث مهمة)، وليس كل ثانية.
- **Exam Draft محلي فقط** أثناء الأداء (لحماية إجابات الطالب من انقطاع لحظي)، لكن **التسليم النهائي يبقى دائمًا Server-validated** — هذا ليس "امتحان Offline".
- **لا Offline Queue عامة** لكل عمليات النظام — فقط الحالة الخاصة أعلاه (Exam Draft).
- **Realtime انتقائي فقط** (إشعارات، تحديثات حالة مهمة حيّة) — ليس بديلًا عن الاستعلامات، وليس على كل جدول.
- **Retry محدود** (2-3 محاولات مع تأخير) للأخطاء الشبكية فقط، وليس لأخطاء Validation/Auth.
- **Optimistic UI** فقط للعمليات الآمنة تمامًا (مثل "وضع إشعار كمقروء") — **ممنوع** في: تسليم امتحان، تقييم واجب، اعتماد طالب، حضور، نشر امتحان.
- إدارة الذاكرة: Dispose صحيح للـControllers، لا الاحتفاظ بآلاف السجلات في Cubit واحد، التخلص من Video Controller عند مغادرة الشاشة.

---

# 17. البنية التحتية والنشر

## 17.1 المخطط العام

```text
Internet → Cloudflare (DNS/SSL/CDN) → Flutter Web (Cloudflare Pages)
                                    ↘
                                     Supabase (Auth + PostgreSQL/RLS + Storage + Edge Functions)
                                          ↘
                                           Bunny Stream (فيديو)  +  FCM (Push)
```

**لا** VPS، لا Docker Cluster، لا Kubernetes، لا Redis، لا Node.js Server مخصص، لا Microservices في V1 — Managed Services أولًا، والبنية المخصصة فقط عند حاجة نمو حقيقية.

## 17.2 البيئات (Environments)

`Development` و`Production` منفصلتان تمامًا (Supabase مشاريع مختلفة، Bunny بيئات مختلفة) — خطأ تطويري واحد يجب ألا يصل لبيانات العميل الحقيقي. `Staging` تُضاف لاحقًا قبل التوسع التجاري الأوسع، وليست ضرورية من اليوم الأول.

## 17.3 CI/CD

```text
Pull Request → flutter analyze → flutter test → Build → PASS → Merge → main → Deploy
```

فشل الـBuild = Production يبقى على آخر نسخة ناجحة (لا موقع مكسور).

## 17.4 Domain

`app.example.com` للتطبيق نفسه (منفصل مستقبلًا عن Marketing Website على `www.example.com`). Custom domain لكل Tenant **ليس** V1.

## 17.5 قائمة تحقق قبل أي Production Release

Flutter (analyze/test/build/responsive/auth/routing) + Supabase (migrations/RLS/tests/functions/secrets/storage) + Bunny (API/webhook/upload/processing/playback) + Domain (DNS/HTTPS) — ثم **Smoke Test كامل** لكل الـCritical Flows (تسجيل، اعتماد، محتوى، واجب، امتحان، حضور، Parent Dashboard، فيديو، إشعار) قبل اعتبار الإصدار ناجحًا.

## 17.6 Rollback و Disaster Recovery

- Code: Rollback فوري لآخر نسخة ناجحة عبر GitHub/Cloudflare Pages.
- Database: Migrations تدريجية (لا `DROP COLUMN` مباشر)، Backups عبر Supabase Managed Backups.
- أولويات الاستعادة عند كارثة: **P0** (Database/Auth/Academic Records) → **P1** (Assignments/Exams/Attendance/Files) → **P2** (Videos/Activity/Notifications) → **P3** (Analytics/Logs غير الحرجة).

---

# 18. تهيئة المشروع والـPackages

فلسفة الاختيار: **Package تُضاف بسبب مشكلة حقيقية، وليس لأنها موجودة في Tutorial.**

| الحاجة | الاختيار |
|---|---|
| State Management | `flutter_bloc` (Cubit) |
| Backend SDK | `supabase_flutter` |
| Routing | `go_router` |
| JSON/Models | `json_serializable` + `build_runner` |
| Immutability | `equatable` |
| رفع ملفات | `file_picker` |
| صور | `cached_network_image` |
| فيديو | Abstraction خاصة (`AppVideoPlayer`) فوق `video_player` أو حل Bunny المخصص للويب |
| تاريخ/وقت | `intl` |
| لغات | `flutter_localizations` + ARB files (`app_ar.arb`, `app_en.arb`) — **لا** نصوص عربية/إنجليزية مباشرة داخل Widgets |

**Secrets/Config:** Supabase URL + Anon Key فقط داخل Flutter (عبر `AppConfig`/`flutter_dotenv` للإعدادات غير السرية) — **لا** Service Role Key ولا أي Secret خلفي داخل Flutter تحت أي ظرف.

**Git:** `main` / `develop` / `feature/*`، Commit convention (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`). **لا عمل مباشر على main.**

---

# 19. التكلفة والاقتصاديات (Cost & Unit Economics)

## 19.1 هيكل التكلفة

`Base Infrastructure + Storage + Video Delivery + Push + Support` — وليس "تكلفة استضافة" بسيطة. Supabase Pro (~$25/شهر) يغطي البداية، Cloudflare Pages للـStatic مجاني عمليًا في البداية، FCM مجاني كليًا للتوصيل. **الفيديو هو المتغير الحقيقي الأكبر في التكلفة**، وليس Flutter Web أو Database.

## 19.2 القرار الاقتصادي الأهم

**لا** نبيع "Unlimited Everything" (فيديو/تخزين/طلاب بلا حدود) مقابل سعر ثابت — هذا يمكن أن يحوّل أفضل عميل (أكثرهم استخدامًا) إلى أسوأ عميل اقتصاديًا. البديل: **Fair Usage Policy** + تسعير مستقبلي مرتبط بـ**Student Capacity** (Starter/Growth/Pro tiers)، مع مراقبة استهلاك فعلي (`students_count`, `storage_used`, `video_bandwidth_used`) من اليوم الأول لمعرفة التكلفة الحقيقية لكل عميل بدلًا من التخمين.

## 19.3 العميل الحالي

العرض المتفق عليه معه (Setup + شهري، أو سنوي بخصم) **لا يتغيّر** احترامًا للاتفاق، لكن العملاء القادمون يحصلون على النموذج الأفضل (Setup + Subscription + Student Limit + Fair Usage).

---

# 20. النسخ الاحتياطي والمراقبة والتعافي من الكوارث

- **Database:** Supabase Managed Backups + Migration History في Git (لا تعديل يدوي على Production).
- **Storage/Files:** Supabase Storage، مع التمييز الواضح بين ملفات الطلاب (نسخ احتياطي حسب الحاجة) والفيديو (مُدار عند Bunny بالكامل).
- **الكود:** GitHub هو الـSource of Truth — أي جهاز تالف لا يعني فقدان الكود.
- **Secrets:** لا تُخزَّن أبدًا في GitHub/Flutter — فقط في Edge Function Secrets.
- **Monitoring V1 (بسيط، وليس Enterprise Stack):** Supabase Logs + Cloudflare Logs + Flutter Error Reporting، مع إضافة Sentry لاحقًا فقط عند الحاجة الفعلية — ليس من اليوم الأول.
- **Audit Log** منفصل تمامًا عن الـLogging التقني (راجع قسم 8.5) — للأفعال الإدارية الحساسة فقط.
- **Logging مفيد لا شامل:** أحداث مهمة فقط (تسجيل طالب، اعتماد، نشر محتوى، تسليم) — ليس `print()` أو تسجيل كل تفاعل واجهة.

---

# 21. الاختبار وضمان الجودة (Testing & QA)

## 21.1 القاعدة الأساسية

> لا Feature "مكتملة" لمجرد أن الشاشة ظهرت — يجب أن تجتاز معايير قبولها ولا تكسر أي Flow حرج موجود.

## 21.2 المستويات

1. **Static Analysis:** `flutter analyze`.
2. **Unit Tests:** منطق الأعمال المعزول (حساب درجة الامتحان، حالة الحضور، قواعد الوصول للـGroup) — بدون UI.
3. **Repository/Data Layer Tests:** التأكد أن التطبيق يتعامل بشكل صحيح مع Supabase (مثال: طالب في Group A لا يحصل على محتوى Group B) — **لكن اختبار Flutter وحده لا يكفي أمنيًا**، RLS هو خط الدفاع الحقيقي.
4. **RLS Tests:** سيناريوهات الهجوم الكاملة المذكورة في قسم 12.5 — هذه Security Testing بقدر ما هي QA.

## 21.3 الرحلات الحرجة (Critical Flows) الواجب اختبارها End-to-End

تسجيل واعتماد الطالب → إنشاء ونشر محتوى (مع اختبار previous_content_access) → دورة الواجب كاملة → دورة الامتحان كاملة (مع اختبار انتهاء الوقت، تسليم مزدوج، انقطاع إنترنت، محاولة الوصول للإجابة الصحيحة) → رحلة Parent كاملة (مع تأكيد عزل الأبناء غير المرتبطين) → اختبار الفيديو (رفع، معالجة، تشغيل، استئناف من نقطة التوقف، منع تزوير الـProgress بسهولة).

## 21.4 Definition of Done لأي Feature

```text
☑ UI + Responsive  ☑ Loading/Empty/Error states  ☑ Validation
☑ Cubit + Repository  ☑ RLS محقَّقة  ☑ Permission checks
☑ Unit tests للمنطق الحرج  ☑ Critical flow tested
☑ flutter analyze يمر  ☑ flutter test يمر  ☑ Production build ينجح
```

## 21.5 CI/CD Gate

كود لا يمر بالفحوصات (`analyze` + `test` + `build`) **لا يصل Production** — بوابة آلية وليست ثقة يدوية.

---

# 22. الاشتراك ودورة حياة الـTenant

> **⚠️ فجوة موثّقة في هذا التجميع.** أُشير إلى هذا الركن (v1.16 — Subscription & Billing) كـ**مقفول 🔒** في قوائم الحالة ضمن المحادثات الأصلية، لكن **المحتوى التفصيلي الفعلي لهذا الركن لم يكن متوفرًا ضمن النصوص التي تم تجميعها** (القفزة في النص الأصلي انتقلت مباشرة من v1.15 إلى v1.17). لذلك:
>
> - **لا يجوز** اعتبار أي تفاصيل افتراضية هنا كقرار معتمد — هذا القسم *يحتاج إعادة توثيق كاملة* من مصدر v1.16 الأصلي (إن وُجد) أو صياغته من جديد كركن مستقل قبل البدء في تنفيذ أي منطق خاص بالفوترة أو حدود الاشتراك.
> - الشيء الوحيد المؤكد من السياق العام (قسم 19 هنا): التوجه نحو تسعير مرتبط بـ**Student Capacity + Fair Usage Policy** بدل "Unlimited Everything"، وأن العميل الحالي له اتفاق منفصل لا يتغيّر.
> - الركن القادم في التسلسل الأصلي بعد هذه الوثيقة كان بعنوان **"v1.22 — Subscription Enforcement & Tenant Lifecycle"**، والذي كان من المفترض أن يحدد: ماذا يحدث عند انتهاء اشتراك المدرس، ما الذي يتوقف/يبقى متاحًا، وكيف نمنع تجاوز عدد الطلاب المسموح به. **هذا الركن لم يُكتب بعد** ضمن ما وصلني، ويجب إنجازه قبل اعتبار دورة حياة الـTenant التجارية (وليس التقنية فقط في قسم 3.6) مكتملة.

---

# 23. عقد الذكاء الاصطناعي الموحّد (AI Coding Contract)

> هذا القسم يجمع كل قواعد "الذكاء الاصطناعي كمنفّذ" المتفرقة عبر الأركان الأصلية (v1.1, v1.13, v1.15, v1.18, v1.21) في مرجع واحد إلزامي.

## 23.1 المبدأ الأساسي

> **AI is an implementation assistant, not an architect.**

## 23.2 مسموح للـAI

- كتابة الكود، Widgets، Tests، Repositories، تنفيذ SQL المعتمد مسبقًا، إصلاح Bugs — **داخل** الـArchitecture الموجودة فقط.

## 23.3 ممنوع على الـAI (بدون اعتماد صريح موثّق لكل حالة)

**معماريًا:**
- تغيير الـArchitecture العامة، الـDatabase Schema، RLS Policies، الـState Management (استبدال Cubit)، Authentication Flow، Video Architecture، أو إضافة Package جوهرية جديدة.

**أمنيًا (الأخطر):**
- تعطيل RLS، استخدام Service Role Key داخل Flutter، Hard-code أي Secret، تجاوز Authorization، جعل Storage Bucket عامًا لتسهيل الرفع، إرسال Answer Keys للطالب، إضافة صلاحيات Admin "للتجربة"، حذف Security Checks لأنها "تسبب Error" — **إذا واجه الـAI مشكلة، الحل هو إصلاح التنفيذ، لا إلغاء البنية الأمنية**.

**بيانات وتحليلات:**
- Tracking لكل تفاعل UI، إنشاء جداول Analytics بدون حاجة مثبتة، حساب Metrics غير معرَّفة رسميًا، تعديل `activity_events` schema من تلقاء نفسه، اعتبار Logout = Last Activity، اعتبار فتح الفيديو = مشاهدة كاملة، اعتبار Activity Events دليلًا أمنيًا قاطعًا، بناء AI Predictions/Risk Scores في V1.

**أداء:**
- تحميل كل البيانات دفعة واحدة، Supabase queries داخل Widget، طلب API كل ثانية للفيديو، بناء Offline Architecture كاملة، Realtime على كل جدول، Fetch داخل `build()`.

## 23.4 طريقة إعطاء المهام للـAI (نموذج إلزامي)

❌ **خطأ:** "Build an education platform." أو "Build students section."

✅ **صحيح:**
```text
Context: [رابط/اسم القسم ذي الصلة من هذه الوثيقة]
Feature: Implement Teacher Student Approval Flow
Constraints: Use Cubit + Repository. Do not modify schema/RLS/routing/state-management.
Required: loading/error/empty states + tests for approval state transitions.
Acceptance Criteria: [معايير محددة]
```

كل Metric تحليلي جديد يحتاج توثيقًا صريحًا: `Metric Name / Definition / Source / Calculation / UI Location` قبل تنفيذه.

---

# 24. بنود مفتوحة / خارطة الطريق

هذه بنود **متروكة عمدًا** (وليست نسيانًا)، مرتبة حسب الإلحاح:

| البند | الحالة | ملاحظة |
|---|---|---|
| **v1.16 — Subscription & Billing (المحتوى الكامل)** | ⚠️ فجوة توثيقية | يجب استرجاعه/إعادة كتابته — راجع قسم 22 |
| **v1.22 — Subscription Enforcement & Tenant Lifecycle** | 📋 لم يُكتب بعد | التالي منطقيًا في التسلسل الأصلي |
| **Data Deletion Request Flow (خصوصية)** | 📋 مفتوح | راجع قسم 13.2 بند 4 |
| **مراجعة قانونية للخصوصية (قُصَّر)** | 📋 مفتوح | راجع قسم 13.3 |
| Notification Preferences متقدمة (تخصيص لكل نوع) | 📋 مؤجَّل | V1 يدعم ON/OFF عام فقط |
| Quiet Hours للإشعارات | 📋 مؤجَّل | Architecture تسمح بإضافتها لاحقًا |
| Excel/PDF Export للتقارير | 📋 مؤجَّل | V1.1/V2 |
| AI Risk Score / "Needs Attention" indicator | 📋 مؤجَّل | Rules-based بسيط فقط عند الحاجة |
| Custom Domain لكل Tenant | 📋 مستقبلي | البنية تسمح، ليس V1 |
| Staging Environment منفصلة | 📋 قبل التوسع التجاري | ليست ضرورية الآن (Dev + Prod كافية) |
| Chat/Messaging بين المستخدمين | ❌ خارج النطاق | قرار واعٍ، ليس V1 |
| Dark Mode | 📋 مستقبلي | Tokens جاهزة لدعمه لاحقًا |
| Video Provider نهائي (تأكيد Bunny) | 📋 شبه نهائي | يحتاج اختبار عملي فعلي قبل القفل 100% |

---

# 25. سجل التغييرات الكامل لهذا التجميع

| # | الإصلاح/الإضافة | الموقع | السبب |
|---|---|---|---|
| 1 | Partial Unique Index لمنع أكثر من `exam_attempt` نشطة لنفس الطالب/الامتحان + معالجة على مستوى Edge Function | قسم 4.3، 4.2 (exam_attempts) | Race Condition حقيقي عند فتح الامتحان في أكثر من تبويب/جهاز أو ضغط "Start" مرتين على شبكة بطيئة — لم يكن مغطى صراحة في v1.7/v1.14/v1.15 الأصلية |
| 2 | متطلب إلزامي لاختبار أداء RLS (`EXPLAIN ANALYZE`) قبل الإطلاق وعند نمو البيانات | قسم 5.5 | الـPolicies متعددة القفزات (Student→group_members→groups→content) صحيحة أمنيًا لكن أداؤها غير مُختبَر في أي ركن أصلي |
| 3 | تعريف صريح كامل لسلوك `tenant.status = suspended` (تسجيل دخول، Sessions، القراءة/الكتابة، المحتوى، إعادة التفعيل) | قسم 3.6 | كان الحقل معرَّفًا في الـSchema فقط (`active`/`suspended`) بدون أي تعريف للسلوك الفعلي في أي ركن أصلي |
| 4 | قسم كامل جديد للخصوصية والاحتفاظ ببيانات القُصَّر + توصية بمراجعة قانونية | قسم 13 (جديد بالكامل) | غياب أي معالجة صريحة لخصوصية بيانات الطلاب (غالبيتهم قُصَّر) رغم أنها بيانات حساسة تُخزَّن بكثافة في المنصة |
| 5 | ملاحظة هندسية اختيارية لتبسيط `attempt_number` في `assignment_submissions` | قسم 4.2 | التصميم الحالي صحيح لكنه يضيف تعقيدًا (تحديد "أي attempt معتمد") يمكن تبسيطه بدون كسر القرار المعماري |
| 6 | توثيق صريح لفجوة محتوى v1.16 (Subscription & Billing) المفقود من النصوص المصدر | قسم 22 | الركن مذكور كـ"مقفول" في قوائم الحالة لكن محتواه الفعلي غير موجود في أي نص تم تزويدي به — تم تجنّب اختلاق محتوى بديل |
| 7 | توحيد كل قواعد "AI كمنفّذ" المتناثرة عبر 5 أركان مختلفة في عقد واحد شامل | قسم 23 | كانت مكرَّرة وجزئية في v1.1, v1.13, v1.15, v1.18, v1.21 بدون مرجع واحد جامع |
| 8 | حل تعارض `exam_questions` بين v1.3 (مرتبط بـ`exam_id` مباشرة) وv1.7/v1.14 (مرتبط بـ`exam_version_id`) | قسم 4.2 | النسخة الأحدث (v1.14) هي المعتمدة، مع توضيح صريح أنها تُلغي الربط المباشر الأقدم |
| 9 | تجميع "بنود مفتوحة" من كل الأركان في قائمة واحدة موحّدة بدل تفرقها | قسم 24 | كانت متناثرة كملاحظات ختامية في أركان مختلفة |

---

**نهاية الوثيقة المرجعية الموحّدة.**

> أي قرار جديد يخالف ما ورد هنا يجب أن يُوثَّق كمراجعة صريحة (Amendment) وليس تعديلًا صامتًا — بنفس منهجية "الركن الواحد المقفول" المتبعة من البداية.
