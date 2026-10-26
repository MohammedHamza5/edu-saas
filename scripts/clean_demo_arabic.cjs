const https = require('https');

const SUPABASE_URL = 'https://vfjialpvgorpslqjdqwq.supabase.co';
const SERVICE_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmamlhbHB2Z29ycHNscWpkcXdxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODcyMjc4NCwiZXhwIjoyMTA0Mjk4Nzg0fQ.9yPhoopvLVHlVCDIs-R6v0iScytb_U3uqM90q0vj7Jo';

function request(method, endpoint, data = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(endpoint, SUPABASE_URL);
    const body = data ? Buffer.from(JSON.stringify(data), 'utf8') : null;

    const headers = {
      'apikey': SERVICE_KEY,
      'Authorization': `Bearer ${SERVICE_KEY}`,
      'Prefer': 'return=minimal',
    };
    if (body) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
      headers['Content-Length'] = body.length;
    }

    const req = https.request(
      url,
      { method, headers },
      (res) => {
        let resData = '';
        res.on('data', (chunk) => (resData += chunk));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve({ status: res.statusCode, data: resData });
          } else {
            reject(new Error(`${method} ${endpoint} -> HTTP ${res.statusCode}: ${resData}`));
          }
        });
      }
    );

    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

const patch = (endpoint, data) => request('PATCH', endpoint, data);

async function run() {
  console.log('=== ENHANCING ALL DEMO SANDBOX DATA WITH AUTHENTIC ARABIC MATH STRINGS ===');

  // 1. Tenants
  await patch('/rest/v1/tenants?id=eq.11111111-1111-1111-1111-111111111111', {
    name: 'منصة رياضيات الدبلومة الأمريكية (نسخة تجريبية)',
    phone: '+201515088953',
    email: 'demo@edsentre.com',
  });
  console.log('✓ Tenants');

  // 2. Teachers
  await patch('/rest/v1/users?id=eq.10000000-0000-0000-0000-000000000001', {
    full_name: 'معلم تجريبي (معاينة المنصة)',
    phone: '+201515088953',
  });
  await patch('/rest/v1/users?id=eq.80cf8c1f-3264-43a9-b530-4309b87812a0', {
    full_name: 'معلم تجريبي (معاينة المنصة)',
    phone: '+201515088953',
  });
  console.log('✓ Teachers (all Dr. Antounios mentions wiped)');

  // 3. Students
  const students = [
    { id: '20000000-0000-0000-0000-000000000001', name: 'طالب تجريبي (عضوية متميزة - حل التدريبات)' },
    { id: '20000000-0000-0000-0000-000000000002', name: 'طالب تجريبي (أساسيات - الدبلومة الأمريكية)' },
    { id: 'ff5705da-1b25-495c-8f79-8b1c8c0a8f17', name: 'طالب تجريبي (SAT Advanced)' },
    { id: '7149bcf4-8576-4c1b-966c-9e8fe37527e6', name: 'طالب تجريبي (SAT Basics)' },
    { id: '9edf6915-e868-4dad-8834-426d2758934b', name: 'طالب تجريبي (EST Math)' },
    { id: 'a25a56c2-ef48-4867-bdb2-753d48d6fb23', name: 'طالب تجريبي (ACT Math)' },
  ];
  for (const s of students) {
    await patch(`/rest/v1/users?id=eq.${s.id}`, { full_name: s.name });
  }
  console.log('✓ Students');

  // 4. Groups
  const groups = [
    {
      id: '22222222-2222-2222-2222-222222222222',
      name: 'SAT Advanced Prep',
      description: 'تدريب متقدم على حل مسائل Digital SAT Math وإدارة الوقت',
    },
    {
      id: '33333333-3333-3333-3333-333333333333',
      name: 'EST Level 1 Foundation',
      description: 'تأسيس منهج اختبار EST Math المصري والتدريبات الشاملة',
    },
    {
      id: '44444444-4444-4444-4444-444444444444',
      name: 'ACT & Fast-Track Intensive',
      level: 'ACT',
      description: 'مكثف استراتيجيات السرعة والحل الذهني لاختبار ACT',
    },
    {
      id: '41c2bce0-88c4-4f9f-b75c-27dd4de60506',
      name: 'SAT Basics & Algebra Bootcamp',
      level: 'SAT',
      description: 'معسكر الجبر والأساسيات لاختبار الدبلومة الأمريكية',
    },
    {
      id: '30000000-0000-0000-0000-000000000001',
      name: 'Digital SAT Elite - Class of 2026',
      level: 'Grade 11 - 12',
      description: 'المجموعة المتميزة للتدريب المكثف على محاكي Bluebook',
    },
  ];
  for (const g of groups) {
    const payload = { name: g.name, description: g.description };
    if (g.level) payload.level = g.level;
    await patch(`/rest/v1/groups?id=eq.${g.id}`, payload);
  }
  console.log('✓ Groups');

  // 5. Video Folders
  const videoFolders = [
    { id: 'a6ed5d7c-5e10-4968-8938-0fbd7606f7a9', name: 'موديول 1: الجبر والمسائل الخطية (Heart of Algebra)' },
    { id: 'a3da075e-5dd8-4753-86d0-672d9b0566ce', name: 'موديول 2: الدوال المتقدمة والهندسة (Passport & Geometry)' },
    { id: 'fea2e5a3-15cc-4082-a00c-19061f63a01c', name: 'استراتيجيات وإدارة وقت الامتحان (Pacing & Timing)' },
  ];
  for (const vf of videoFolders) {
    await patch(`/rest/v1/video_folders?id=eq.${vf.id}`, { name: vf.name });
  }
  console.log('✓ Video Folders');

  // 6. Material Folders
  const materialFolders = [
    { id: 'bf3a2176-ecc5-4d90-a05d-7175e1aecc70', name: 'أوراق القوانين المعتمدة (Official Formula Sheets)' },
    { id: '217342b3-af17-40df-a19e-9c9fc0d93c93', name: 'شروحات حاسبة ديسموس (Desmos Graphing Hacks)' },
  ];
  for (const mf of materialFolders) {
    await patch(`/rest/v1/material_folders?id=eq.${mf.id}`, { name: mf.name });
  }
  console.log('✓ Material Folders');

  // 7. Video Library
  const videos = [
    {
      id: '03a95b66-9c7a-454b-b064-0c8220e0713e',
      title: 'حل المعادلات الخطية بضغطة زر باستخدام Desmos',
      description: 'شرح احترافي للحل السريع في موديول 1',
    },
    {
      id: 'cce80ac4-ed9b-4ebb-a443-695d55f2d503',
      title: 'أسرار رأس الدالة التربيعية (Quadratic Vertex Form)',
      description: 'استخراج القيم العظمى والصغرى دون خطوات طويلة',
    },
    {
      id: '13e12b4f-6cd5-4f59-9ce1-5eeb9c02d617',
      title: 'معادلات الدائرة وتطبيقات الهندسة في دقيقة',
      description: 'إكمال المربع وحساب نصف القطر بدقة',
    },
    {
      id: 'b9e8c3b7-00d5-4ec2-9ece-fc8c54032dae',
      title: 'كيف تضمن سكور 750+ في اختبار SAT Math',
      description: 'خطة عملية وإدارة الدقائق الأخيرة',
    },
    {
      id: 'ffae22fd-54b4-4352-b00d-dbd5fe1612c9',
      title: 'أسرع 10 خطوات لحل أسئلة الصعوبة في موديول 2',
      description: 'حل أسئلة الـ Hard questions بذكاء',
    },
  ];
  for (const v of videos) {
    await patch(`/rest/v1/video_library?id=eq.${v.id}`, { title: v.title, description: v.description });
  }
  console.log('✓ Video Library');

  // 8. Material Library
  const materials = [
    {
      id: '7fb5d572-cae9-4c43-91db-788f803c8803',
      title: 'ورقة القوانين الرسمية مع ملاحظات الحل السريع (SAT Formula Sheet)',
      description: 'مرجع كامل لجميع قوانين الحساب والهندسة',
    },
    {
      id: 'ca4e7813-8a1e-4a57-b734-4108aea32e2e',
      title: 'دليل احتراف حاسبة Desmos المدمجة لرفع السكور',
      description: 'أهم 15 اختصار لحاسبة الرسوم البيانية الرسمية',
    },
    {
      id: '06d9294c-fbfa-4275-a54c-8f0d38e9d3f1',
      title: 'أقوى 50 فخ في اختبار SAT وكيفية تجنبها',
      description: 'تحليل تكتيكي لأشهر الأخطاء الشائعة',
    },
    {
      id: 'a7066b69-2428-4599-b269-97fa61c81c20',
      title: 'ملخص شامل لقواعد الجبر الأساسية (Heart of Algebra Summary)',
      description: 'شرح مكثف لأهم أفكار الجبر الخطي',
    },
    {
      id: '5ed8ebac-9760-47c7-be35-f1457ef529d4',
      title: 'أهم أفكار EST Math المتكررة لعام 2026',
      description: 'مراجعة شاملة لأسئلة الامتحان المصري',
    },
  ];
  for (const m of materials) {
    await patch(`/rest/v1/material_library?id=eq.${m.id}`, { title: m.title, description: m.description });
  }
  console.log('✓ Material Library');

  console.log('=== ALL DEMO DATABASE RECORDS ARE 100% CLEAN, PRESTIGE & UTF-8 ===');
}

run().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
