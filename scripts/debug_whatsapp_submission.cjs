const SUPABASE_URL = 'https://vfjialpvgorpslqjdqwq.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmamlhbHB2Z29ycHNscWpkcXdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MjI3ODQsImV4cCI6MjEwNDI5ODc4NH0.PIJ1KgTGHZBDudhNLhXU4CYYq1cf0cc4XhMSfFGauKY';

async function main() {
  console.log('--- Logging in as Teacher ---');
  const authRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      'apikey': ANON_KEY,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      email: 'demo.teacher@edsentre.com',
      password: 'Demo@2026!'
    })
  });

  const authData = await authRes.json();
  if (!authData.access_token) {
    console.error('Failed to log in:', authData);
    return;
  }
  const token = authData.access_token;
  console.log('Logged in successfully! User ID:', authData.user?.id);

  const headers = {
    'apikey': ANON_KEY,
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  };

  console.log('\n--- 1. Checking recent exams ---');
  const examsRes = await fetch(`${SUPABASE_URL}/rest/v1/exams?select=id,title,status,tenant_id,created_at&order=created_at.desc&limit=5`, { headers });
  const exams = await examsRes.json();
  console.log('Recent exams:', exams);

  console.log('\n--- 2. Checking recent exam_attempts ---');
  const attemptsRes = await fetch(`${SUPABASE_URL}/rest/v1/exam_attempts?select=id,exam_id,student_id,status,score,max_score,percentage,tenant_id,submitted_at,created_at&order=created_at.desc&limit=5`, { headers });
  const attempts = await attemptsRes.json();
  console.log('Recent attempts:', attempts);

  console.log('\n--- 3. Checking whatsapp_outbox_queue ---');
  const queueRes = await fetch(`${SUPABASE_URL}/rest/v1/whatsapp_outbox_queue?select=*&order=created_at.desc&limit=5`, { headers });
  const queue = await queueRes.json();
  console.log('Queue rows:', queue);

  console.log('\n--- 4. Checking student users ---');
  const studentsRes = await fetch(`${SUPABASE_URL}/rest/v1/users?select=id,full_name,email,phone,parent_phone,role,status&role=eq.student&order=created_at.desc&limit=5`, { headers });
  const students = await studentsRes.json();
  console.log('Students:', students);

  console.log('\n--- 5. Checking whatsapp_auth_sessions ---');
  const sessionsRes = await fetch(`${SUPABASE_URL}/rest/v1/whatsapp_auth_sessions?select=id,tenant_id,status,connected_phone,auto_dispatch_enabled,updated_at`, { headers });
  const sessions = await sessionsRes.json();
  console.log('Sessions:', sessions);
}

main().catch(console.error);
