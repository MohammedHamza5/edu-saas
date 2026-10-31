const https = require('node:https');

const SUPABASE_HOST = '104.18.38.10';
const SUPABASE_SNI = 'vfjialpvgorpslqjdqwq.supabase.co';
const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmamlhbHB2Z29ycHNscWpkcXdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MjI3ODQsImV4cCI6MjEwNDI5ODc4NH0.PIJ1KgTGHZBDudhNLhXU4CYYq1cf0cc4XhMSfFGauKY';

function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const headers = {
      'Host': SUPABASE_SNI,
      'apikey': ANON_KEY,
      ...(options.headers || {})
    };

    const req = https.request({
      host: SUPABASE_HOST,
      port: 443,
      path: path,
      method: options.method || 'GET',
      headers: headers,
      servername: SUPABASE_SNI,
      timeout: 10000
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(data) });
        } catch (_) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });

    if (options.body) {
      req.write(typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
    }
    req.end();
  });
}

async function main() {
  console.log('Logging in...');
  const loginRes = await request('/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: { email: 'demo.teacher@edsentre.com', password: 'Demo@2026!' }
  });

  const token = loginRes.data?.access_token;
  if (!token) {
    console.error('Login failed:', loginRes);
    return;
  }
  console.log('Logged in successfully!');

  const authHeaders = {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  };

  console.log('\n--- 1. Recent attempts ---');
  const attempts = await request('/rest/v1/exam_attempts?select=*&order=submitted_at.desc.nullslast&limit=5', {
    headers: authHeaders
  });
  console.log('Attempts:', attempts.data);

  if (attempts.data && attempts.data.length > 0) {
    const latest = attempts.data[0];
    console.log('\n--- 2. Calling enqueue_exam_result_whatsapp on attempt:', latest.id);
    const rpcRes = await request('/rest/v1/rpc/enqueue_exam_result_whatsapp', {
      method: 'POST',
      headers: authHeaders,
      body: { p_attempt_id: latest.id }
    });
    console.log('RPC result:', rpcRes);
  }

  console.log('\n--- 3. Checking outbox queue ---');
  const queue = await request('/rest/v1/whatsapp_outbox_queue?select=*', {
    headers: authHeaders
  });
  console.log('Queue contents:', queue.data);
}

main().catch(console.error);
