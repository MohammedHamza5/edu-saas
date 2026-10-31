const SUPABASE_URL = 'https://vfjialpvgorpslqjdqwq.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmamlhbHB2Z29ycHNscWpkcXdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MjI3ODQsImV4cCI6MjEwNDI5ODc4NH0.PIJ1KgTGHZBDudhNLhXU4CYYq1cf0cc4XhMSfFGauKY';

async function main() {
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
  const token = authData.access_token;

  const headers = {
    'apikey': ANON_KEY,
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  };

  const res = await fetch(`${SUPABASE_URL}/rest/v1/whatsapp_auth_sessions?select=id,tenant_id,status,connected_phone,connected_name,updated_at,last_heartbeat_at`, { headers });
  const data = await res.json();
  console.log('Sessions in DB:', JSON.stringify(data, null, 2));
}

main().catch(console.error);
