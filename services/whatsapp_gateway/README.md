# EduSaaS Self-Hosted WhatsApp Gateway 🚀
## بوابة إرسال نتائج الامتحانات تلقائياً إلى واتساب أولياء الأمور

بوابة إرسال آلي تعتمد على بروتوكول `@whiskeysockets/baileys` المباشر، مدعومة بمحرك الحماية من الحظر (Anti-Ban Engine)، وحفظ الجلسات في قاعدة بيانات Supabase (PostgreSQL) لتكون الخدمة عديمة الحالة (Stateless).

---

## 🌟 المميزات
1. **مجانية 100% للأبد ($0):** لا تدفع أي اشتراكات أو رسوم لميتا.
2. **إرسال تلقائي وفوري:** فور تسليم الطالب للاختبار، يُدرج الإشعار في طابور `whatsapp_outbox_queue` ويُرسل فوراً.
3. **مقاومة الحظر (Anti-Ban Heuristics):**
   - تأخير عشوائي بشري (4-8 ثوانٍ) بين الرسائل.
   - محاكاة حالة الكتابة الطبيعية (Composing Presence).
   - استراحة ذكية بعد كل 10 رسائل متتالية.
4. **تخزين الجلسة سحابياً (Stateless):** إعادة تشغيل السيرفر لا تفقد الجلسة إطلاقاً ولا تطلب مسح الـ QR Code مجدداً.

---

## 🛠️ خيارات النشر السحابي المجاني (100% Free Forever)

### 🔹 الخيار 1: النشر على Koyeb (سهل وسريع جداً بنقرة واحدة)
1. افتح حساباً مجانياً على [koyeb.com](https://www.koyeb.com).
2. اختر **Create App** > **GitHub Repo** (أو Dockerfile).
3. حدد المجلد `services/whatsapp_gateway`.
4. أضف متغيرات البيئة (Environment Variables):
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `GATEWAY_API_KEY`
5. اضغط **Deploy**. سيمنحك Koyeb رابطاً آمناً بصيغة `https://your-app.koyeb.app`.
6. افتح الرابط: `https://your-app.koyeb.app/api/qr?apiKey=YOUR_KEY` لمسح الـ QR Code لمرة واحدة من هاتف المنصة!

---

### 🔹 الخيار 2: النشر على Oracle Cloud Always Free (أقوى أداء دائم)
1. افتح حساب Oracle Cloud المجاني وأنشئ VM من نوع Ubuntu (ARM أو AMD مجاناً للأبد).
2. ثبّت Docker:
   ```bash
   curl -fsSL https://get.docker.com | sh
   ```
3. انسخ مجلد `services/whatsapp_gateway` وشغّل الحاوية:
   ```bash
   docker compose up -d --build
   ```

---

### 🔹 الخيار 3: التشغيل المحلي على جهاز السنتر مع Cloudflare Tunnel
إذا أردت تشغيل الخدمة على كمبيوتر السنتر/المدرس:
```bash
cd services/whatsapp_gateway
npm install
npm run build
npm start
```
ولإعطائه رابط HTTPS خارجي مجاني بدون فتح بورتات:
```bash
cloudflared tunnel --url http://localhost:3000
```
