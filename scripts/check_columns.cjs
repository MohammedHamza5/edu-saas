const SUPABASE_URL = 'https://vfjialpvgorpslqjdqwq.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmamlhbHB2Z29ycHNscWpkcXdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MjI3ODQsImV4cCI6MjEwNDI5ODc4NH0.PIJ1KgTGHZBDudhNLhXU4CYYq1cf0cc4XhMSfFGauKY';

async function main() {
  const authRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'demo.teacher@edsentre.com', password: 'Demo@2026!' })
  });
  const { access_token: token } = await authRes.json();
  const headers = { 'apikey': ANON_KEY, 'Authorization': `Bearer ${token}` };

  console.log('--- 1. Single exam row ---');
  const ex = await (await fetch(`${SUPABASE_URL}/rest/v1/exams?limit=1`, { headers })).json();
  console.log('Exam columns:', Object.keys(ex[0] || {}));
  console.log('Exam sample:', ex[0]);

  console.log('\n--- 2. Single attempt row ---');
  const att = await (await fetch(`${SUPABASE_URL}/rest/v1/exam_attempts?limit=1`, { headers })).json();
  console.log('Attempt columns:', Object.keys(att[0] || {}));
  console.log('Attempt sample:', att[0]);

  console.log('\n--- 3. All sessions in whatsapp_auth_sessions ---');
  const ses = await (await fetch(`${SUPABASE_URL}/rest/v1/whatsapp_auth_sessions`, { headers })).json();
  console.log('All sessions:', ses);
}

main().catch(console.error);
