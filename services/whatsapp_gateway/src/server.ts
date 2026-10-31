import express, { Request, Response } from 'express';
import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import { BaileysGatewayClient } from './engine/baileys_client';
import { QueueWorker } from './worker/queue_worker';

dotenv.config();

// In-memory debug log buffer (last 200 log messages)
const logBuffer: string[] = [];
export const pushLog = (msg: string) => {
  logBuffer.push(`[${new Date().toISOString()}] ${msg}`);
  if (logBuffer.length > 200) logBuffer.shift();
};

const origLog = console.log;
const origWarn = console.warn;
const origErr = console.error;

console.log = (...args: any[]) => {
  pushLog(args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' '));
  origLog(...args);
};
console.warn = (...args: any[]) => {
  pushLog('[WARN] ' + args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' '));
  origWarn(...args);
};
console.error = (...args: any[]) => {
  pushLog('[ERR] ' + args.map(a => typeof a === 'object' ? JSON.stringify(a) : a).join(' '));
  origErr(...args);
};

const app = express();
app.use(express.json());

// Enable CORS for Flutter Web Frontend
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, x-api-key');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

const PORT = process.env.PORT || 3000;
const SUPABASE_URL = process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || '';
const SESSION_ID = process.env.SESSION_ID || 'session_default';
const TENANT_ID = process.env.TENANT_ID || undefined;
const GATEWAY_API_KEY = process.env.GATEWAY_API_KEY || 'edusaas_secret_key_2026';

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.warn('⚠️ WARNING: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is not defined in environment!');
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false
  }
});

let baileysClient: BaileysGatewayClient;
let queueWorker: QueueWorker;

// Simple API Key Guard
const authMiddleware = (req: Request, res: Response, next: Function) => {
  const authHeader = req.headers['x-api-key'] || req.query.apiKey;
  if (authHeader && authHeader === GATEWAY_API_KEY) {
    return next();
  }
  return res.status(401).json({ error: 'Unauthorized: Invalid or missing API key' });
};

// 1. Health check (Koyeb / Fly.io / Render health probes)
app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'ok',
    uptime: process.uptime(),
    connected: baileysClient ? baileysClient.isConnected() : false,
    timestamp: new Date().toISOString()
  });
});

// 1.1 Live Diagnostic Logs endpoint (Secured)
app.get('/api/debug-logs', authMiddleware, (_req: Request, res: Response) => {
  res.type('text/plain').send(logBuffer.join('\n'));
});

// 2. Gateway Status
app.get('/api/status', authMiddleware, async (_req: Request, res: Response) => {
  const { data: session } = await supabase
    .from('whatsapp_auth_sessions')
    .select('status, connected_phone, connected_name, last_heartbeat_at, auto_dispatch_enabled')
    .eq('id', SESSION_ID)
    .maybeSingle();

  res.json({
    connected: baileysClient ? baileysClient.isConnected() : false,
    sessionStatus: session?.status || 'disconnected',
    connectedPhone: session?.connected_phone || null,
    connectedName: session?.connected_name || null,
    autoDispatchEnabled: session?.auto_dispatch_enabled ?? true,
    lastHeartbeat: session?.last_heartbeat_at || null
  });
});

// 2.1 Direct Live QR endpoint for Flutter Frontend
app.get('/api/live-qr', async (req: Request, res: Response) => {
  const requestedTenantId = req.query.tenantId as string | undefined;

  let query = supabase
    .from('whatsapp_auth_sessions')
    .select('status, qr_code, connected_phone, connected_name, auto_dispatch_enabled, updated_at');

  if (requestedTenantId) {
    query = query.or(`tenant_id.eq.${requestedTenantId},id.eq.${SESSION_ID}`);
  } else {
    query = query.eq('id', SESSION_ID);
  }

  const { data: session } = await query.order('updated_at', { ascending: false }).limit(1).maybeSingle();

  return res.json({
    connected: baileysClient ? baileysClient.isConnected() : false,
    status: session?.status || 'disconnected',
    qrCode: session?.qr_code || null,
    connectedPhone: session?.connected_phone || null,
    connectedName: session?.connected_name || null,
    autoDispatchEnabled: session?.auto_dispatch_enabled ?? true
  });
});

// 2.2 Force Refresh / Reset QR Endpoint (Accessible for Frontend Pairing)
app.all('/api/refresh-qr', async (req: Request, res: Response) => {
  const force = req.query.force === 'true' || req.body?.force === true;
  if (baileysClient) {
    console.log('[Server] /api/refresh-qr called. Forcing fresh session & QR generation...');
    await baileysClient.forceRefreshSession();
    return res.json({ success: true, message: 'Session refreshed and clean QR generated' });
  }
  return res.json({ success: false, message: 'Baileys client not initialized' });
});

// 2.3 Unlink / Logout WhatsApp Session
app.all('/api/logout', async (_req: Request, res: Response) => {
  if (baileysClient) {
    console.log('[Server] /api/logout called. Wiping credentials and generating fresh QR...');
    await baileysClient.forceRefreshSession();
  }
  return res.json({ success: true, message: 'WhatsApp session logged out and reset' });
});

// 3. Web View for QR Code Pairing
app.get('/api/qr', async (req: Request, res: Response) => {
  const key = req.query.apiKey || req.headers['x-api-key'];
  if (key !== GATEWAY_API_KEY) {
    return res.status(401).send('<h3>Unauthorized. Provide ?apiKey=YOUR_KEY</h3>');
  }

  const { data: session } = await supabase
    .from('whatsapp_auth_sessions')
    .select('status, qr_code, connected_phone')
    .eq('id', SESSION_ID)
    .maybeSingle();

  if (session?.status === 'connected') {
    return res.send(`
      <!DOCTYPE html>
      <html dir="rtl">
      <head>
        <meta charset="utf-8">
        <title>EduSaaS WhatsApp Gateway</title>
        <style>
          body { font-family: -apple-system, sans-serif; text-align: center; padding: 40px; background: #f8fafc; color: #1e293b; }
          .card { background: white; max-width: 480px; margin: 0 auto; padding: 30px; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
          .badge { background: #dcfce7; color: #15803d; padding: 8px 16px; border-radius: 999px; font-weight: bold; display: inline-block; }
        </style>
      </head>
      <body>
        <div class="card">
          <h2>بوابة واتساب منصة EduSaaS 🟢</h2>
          <div class="badge">متصل بنجاح</div>
          <p style="margin-top: 20px; font-size: 18px;">الرقم المتصل: <strong>${session.connected_phone || 'نشط'}</strong></p>
          <p style="color: #64748b; font-size: 14px;">يتم إرسال نتائج الامتحانات تلقائياً لأولياء الأمور فور تسليمها.</p>
        </div>
      </body>
      </html>
    `);
  }

  if (session?.status === 'qr_ready' && session.qr_code) {
    return res.send(`
      <!DOCTYPE html>
      <html dir="rtl">
      <head>
        <meta charset="utf-8">
        <title>EduSaaS WhatsApp Gateway - ربط الهاتف</title>
        <meta http-equiv="refresh" content="20">
        <style>
          body { font-family: -apple-system, sans-serif; text-align: center; padding: 40px; background: #f8fafc; color: #1e293b; }
          .card { background: white; max-width: 480px; margin: 0 auto; padding: 30px; border-radius: 16px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); }
          img { width: 280px; height: 280px; margin: 20px 0; border: 1px solid #e2e8f0; border-radius: 12px; }
        </style>
      </head>
      <body>
        <div class="card">
          <h2>ربط واتساب المنصة بالهاتف 📱</h2>
          <p style="color: #64748b;">افتح واتساب على هاتفك > الأجهزة المرتبطة > امسح الرمز أدناه:</p>
          <img src="${session.qr_code}" alt="WhatsApp QR Code" />
          <p style="font-size: 12px; color: #94a3b8;">يتم تحديث الرمز تلقائياً كل 20 ثانية حتى يتم الربط.</p>
        </div>
      </body>
      </html>
    `);
  }

  return res.send(`
    <!DOCTYPE html>
    <html dir="rtl">
    <head>
      <meta charset="utf-8">
      <meta http-equiv="refresh" content="5">
      <title>جاري التهيئة...</title>
      <style>body { font-family: -apple-system, sans-serif; text-align: center; padding: 50px; }</style>
    </head>
    <body>
      <h3>جاري تجهيز رمز الاستجابة السريعة (QR Code)...</h3>
      <p>ستحدث الصفحة تلقائياً خلال ثوانٍ.</p>
    </body>
    </html>
  `);
});

// 4. Instant trigger wake-up from Supabase Webhook
app.post('/api/webhook/wake', authMiddleware, async (_req: Request, res: Response) => {
  queueWorker.triggerPoll();
  res.json({ ok: true, message: 'Worker poll triggered' });
});

// 5. Manual Direct Dispatch (for testing)
app.post('/api/send', authMiddleware, async (req: Request, res: Response) => {
  const { phone, message } = req.body;
  if (!phone || !message) {
    return res.status(400).json({ error: 'Missing required fields: phone, message' });
  }

  try {
    await baileysClient.sendTextMessage(phone, message);
    return res.json({ success: true, phone });
  } catch (err) {
    return res.status(500).json({ success: false, error: (err as Error).message });
  }
});



// Self-KeepAlive for Free Cloud Instances (e.g. Render / Always-On)
const KEEP_ALIVE_URL = process.env.RENDER_EXTERNAL_URL || process.env.KEEP_ALIVE_URL;
if (KEEP_ALIVE_URL) {
  console.log(`[KeepAlive] Configured self-ping to ${KEEP_ALIVE_URL} every 10 minutes to stay awake 24/7.`);
  setInterval(async () => {
    try {
      await fetch(`${KEEP_ALIVE_URL}/health`);
      console.log('[KeepAlive] Self-ping successful, container active 24/7.');
    } catch (e) {
      console.warn('[KeepAlive] Ping warning:', (e as Error).message);
    }
  }, 10 * 60 * 1000);
}

// Start application
const startServer = async () => {
  let activeTenantId = TENANT_ID;
  if (!activeTenantId) {
    try {
      const { data: tenant } = await supabase.from('tenants').select('id').limit(1).maybeSingle();
      if (tenant?.id) {
        activeTenantId = tenant.id;
        console.log(`[Server] Auto-resolved active Tenant ID: ${activeTenantId}`);
        // Backfill any unassociated session
        await supabase
          .from('whatsapp_auth_sessions')
          .update({ tenant_id: activeTenantId })
          .is('tenant_id', null);
      }
    } catch (e) {
      console.warn('[Server] Failed to auto-resolve tenant:', (e as Error).message);
    }
  }

  baileysClient = new BaileysGatewayClient(supabase, SESSION_ID, activeTenantId);
  queueWorker = new QueueWorker(supabase, baileysClient, 5000);

  app.listen(PORT, () => {
    console.log(`[Server] WhatsApp Gateway running on port ${PORT}`);
  });

  // Start Baileys connection and worker
  await baileysClient.initialize();
  queueWorker.start();
};

startServer().catch((err) => {
  console.error('[Server] Fatal bootstrap error:', err);
});

// Graceful termination
const handleShutdown = (signal: string) => {
  console.log(`[Server] Received ${signal}, shutting down gracefully...`);
  queueWorker.stop();
  process.exit(0);
};

process.on('SIGINT', () => handleShutdown('SIGINT'));
process.on('SIGTERM', () => handleShutdown('SIGTERM'));
