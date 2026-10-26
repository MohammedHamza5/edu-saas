import makeWASocket, {
  DisconnectReason,
  WASocket,
  fetchLatestBaileysVersion
} from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { SupabaseClient } from '@supabase/supabase-js';
import pino from 'pino';
import QRCode from 'qrcode';
import { usePostgresAuthState } from '../auth/postgres_auth';
import { AntiBanPacer } from './anti_ban_pacer';

export class BaileysGatewayClient {
  private sock: WASocket | null = null;
  private supabase: SupabaseClient;
  private sessionId: string;
  private tenantId?: string;
  private pacer: AntiBanPacer;
  private isConnecting: boolean = false;

  constructor(supabase: SupabaseClient, sessionId: string = 'session_default', tenantId?: string) {
    this.supabase = supabase;
    this.sessionId = sessionId;
    this.tenantId = tenantId;
    this.pacer = new AntiBanPacer();
  }

  public getPacer(): AntiBanPacer {
    return this.pacer;
  }

  public isConnected(): boolean {
    return this.sock !== null && (this.sock as any).user !== undefined;
  }

  public getSocket(): WASocket | null {
    return this.sock;
  }

  public async initialize(): Promise<void> {
    if (this.isConnecting) return;
    this.isConnecting = true;

    try {
      const { version } = await fetchLatestBaileysVersion();
      console.log(`[BaileysClient] Starting WhatsApp Gateway with WA version v${version.join('.')}`);

      const { state, saveCreds } = await usePostgresAuthState(
        this.supabase,
        this.sessionId,
        this.tenantId
      );

      this.sock = makeWASocket({
        version,
        logger: pino({ level: 'silent' }),
        printQRInTerminal: true,
        auth: state,
        browser: ['EduSaaS Academic Portal', 'Chrome', '124.0.0'],
        syncFullHistory: false,
        generateHighQualityLinkPreview: false,
        markOnlineOnConnect: true,
        connectTimeoutMs: 60000,
        keepAliveIntervalMs: 25000
      });

      this.sock.ev.on('creds.update', saveCreds);

      this.sock.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (qr) {
          console.log('[BaileysClient] New QR code generated. Updating Postgres session record...');
          try {
            const qrDataUrl = await QRCode.toDataURL(qr);
            await this.supabase
              .from('whatsapp_auth_sessions')
              .update({
                status: 'qr_ready',
                qr_code: qrDataUrl,
                updated_at: new Date().toISOString()
              })
              .eq('id', this.sessionId);
          } catch (qrErr) {
            console.error('[BaileysClient] QR generation error:', qrErr);
          }
        }

        if (connection === 'open') {
          this.isConnecting = false;
          const userJid = this.sock?.user?.id || '';
          const phone = userJid.split(':')[0] || userJid.split('@')[0];
          const name = this.sock?.user?.name || 'EduSaaS WhatsApp Gateway';

          console.log(`[BaileysClient] 🟢 Connected successfully! Phone: ${phone}`);

          await this.supabase
            .from('whatsapp_auth_sessions')
            .update({
              status: 'connected',
              connected_phone: phone,
              connected_name: name,
              qr_code: null,
              last_heartbeat_at: new Date().toISOString(),
              updated_at: new Date().toISOString()
            })
            .eq('id', this.sessionId);
        }

        if (connection === 'close') {
          this.isConnecting = false;
          const statusCode = (lastDisconnect?.error as Boom)?.output?.statusCode;
          const shouldReconnect = statusCode !== DisconnectReason.loggedOut;

          console.warn(`[BaileysClient] Connection closed. Status Code: ${statusCode}, Reconnecting: ${shouldReconnect}`);

          await this.supabase
            .from('whatsapp_auth_sessions')
            .update({
              status: 'disconnected',
              qr_code: null,
              updated_at: new Date().toISOString()
            })
            .eq('id', this.sessionId);

          if (shouldReconnect) {
            console.log('[BaileysClient] Attempting automatic reconnection in 5 seconds...');
            setTimeout(() => this.initialize(), 5000);
          } else {
            console.error('[BaileysClient] ❌ Device was logged out. A new QR code scan is required.');
            // Clear creds in DB to generate fresh QR on next start
            await this.supabase
              .from('whatsapp_auth_sessions')
              .update({
                creds: {},
                keys: {},
                status: 'disconnected',
                connected_phone: null,
                qr_code: null
              })
              .eq('id', this.sessionId);
            setTimeout(() => this.initialize(), 3000);
          }
        }
      });
    } catch (err) {
      this.isConnecting = false;
      console.error('[BaileysClient] Fatal initialization error:', err);
      setTimeout(() => this.initialize(), 10000);
    }
  }

  /**
   * Send a WhatsApp message to a recipient with full anti-ban pacing and presence simulation.
   */
  public async sendTextMessage(phone: string, text: string): Promise<boolean> {
    if (!this.sock || !this.isConnected()) {
      throw new Error('WhatsApp gateway is not connected. Message queued.');
    }

    if (this.pacer.isCircuitTripped()) {
      throw new Error('Circuit breaker tripped. Queue temporarily paused.');
    }

    // Format JID: e.g. 201012345678@s.whatsapp.net
    const cleanDigits = phone.replace(/\D/g, '');
    const jid = `${cleanDigits}@s.whatsapp.net`;

    // 1. Humanize message text
    const messageToSend = this.pacer.humanizeMessage(text);

    // 2. Pace & simulate human typing
    await this.pacer.paceAndSimulatePresence(this.sock, jid);

    // 3. Dispatch message
    try {
      const result = await this.sock.sendMessage(jid, { text: messageToSend });
      if (result && result.key) {
        this.pacer.recordSuccess();
        console.log(`[BaileysClient] ✅ Message dispatched successfully to ${jid}`);
        return true;
      }
      return false;
    } catch (err) {
      this.pacer.recordFailure();
      console.error(`[BaileysClient] ❌ Failed to dispatch message to ${jid}:`, (err as Error).message);
      throw err;
    }
  }

  /**
   * Send heartbeat to keep last_heartbeat_at fresh in Supabase
   */
  public async sendHeartbeat(): Promise<void> {
    if (this.isConnected()) {
      await this.supabase
        .from('whatsapp_auth_sessions')
        .update({
          last_heartbeat_at: new Date().toISOString()
        })
        .eq('id', this.sessionId);
    }
  }
}
