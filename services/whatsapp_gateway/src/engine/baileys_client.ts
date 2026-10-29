import makeWASocket, {
  DisconnectReason,
  WASocket,
  fetchLatestBaileysVersion,
  Browsers,
  proto,
  WAMessageKey,
  makeCacheableSignalKeyStore
} from '@whiskeysockets/baileys';
import { Boom } from '@hapi/boom';
import { SupabaseClient } from '@supabase/supabase-js';
import pino from 'pino';
import QRCode from 'qrcode';
import { usePostgresAuthState } from '../auth/postgres_auth';
import { AntiBanPacer } from './anti_ban_pacer';

/**
 * In-memory CacheStore to handle message retry counters without infinite loops
 */
class SimpleCacheStore {
  private cache = new Map<string, any>();

  get<T>(key: string): T | undefined {
    return this.cache.get(key);
  }

  set(key: string, value: any): void {
    this.cache.set(key, value);
    if (this.cache.size > 2000) {
      const first = this.cache.keys().next().value;
      if (first) this.cache.delete(first);
    }
  }

  del(key: string): void {
    this.cache.delete(key);
  }

  flushAll(): void {
    this.cache.clear();
  }
}

export class BaileysGatewayClient {
  private sock: WASocket | null = null;
  private supabase: SupabaseClient;
  private sessionId: string;
  private tenantId?: string;
  private pacer: AntiBanPacer;
  private isConnecting: boolean = false;
  private messageStore: Map<string, proto.IMessage> = new Map();
  private retryCache: SimpleCacheStore = new SimpleCacheStore();

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
        logger: pino({ level: 'info' }),
        printQRInTerminal: true,
        auth: {
          creds: state.creds,
          keys: makeCacheableSignalKeyStore(state.keys, pino({ level: 'silent' }))
        },
        browser: Browsers.ubuntu('Chrome'),
        syncFullHistory: false,
        generateHighQualityLinkPreview: false,
        markOnlineOnConnect: true,
        connectTimeoutMs: 60000,
        keepAliveIntervalMs: 25000,
        retryRequestDelayMs: 250,
        maxMsgRetryCount: 5,
        msgRetryCounterCache: this.retryCache as any,
        patchMessageBeforeSending: async (message) => {
          try {
            await this.sock?.uploadPreKeysToServerIfRequired();
          } catch (_) {}
          return message;
        },
        getMessage: async (key: WAMessageKey): Promise<proto.IMessage | undefined> => {
          if (!key.id) return undefined;

          // 1. Check in-memory message store
          const inMem =
            this.messageStore.get(key.id) ||
            (key.remoteJid ? this.messageStore.get(`${key.remoteJid}:${key.id}`) : undefined);
          if (inMem) {
            console.log(`[BaileysClient] 🔄 Fulfilled E2EE retry request from memory for message ID: ${key.id}`);
            return inMem;
          }

          // 2. Fallback: Query Supabase outbox queue
          try {
            const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(key.id);
            let query = this.supabase
              .from('whatsapp_outbox_queue')
              .select('message_body, metadata');

            if (isUuid) {
              query = query.or(`metadata->>message_id.eq.${key.id},id.eq.${key.id}`);
            } else {
              query = query.eq('metadata->>message_id', key.id);
            }

            const { data: row, error: queryErr } = await query.limit(1).maybeSingle();
            if (queryErr) {
              console.warn('[BaileysClient] getMessage DB query warning:', queryErr.message);
            }

            // Return exact cryptographic raw proto message if persisted
            if (row?.metadata?.raw_message) {
              console.log(`[BaileysClient] 🔄 Fulfilled E2EE retry from DB raw_message for ID: ${key.id}`);
              return row.metadata.raw_message as proto.IMessage;
            }

            // Clean fallback for plain text
            if (row?.message_body) {
              console.log(`[BaileysClient] 🔄 Fulfilled E2EE retry fallback for message ID: ${key.id}`);
              return {
                extendedTextMessage: {
                  text: row.message_body
                }
              };
            }
          } catch (e) {
            console.warn('[BaileysClient] getMessage DB fallback warning:', (e as Error).message);
          }

          return undefined;
        }
      });

      // Save credentials on update
      this.sock.ev.on('creds.update', saveCreds);

      // Cache incoming & outgoing messages to handle retries seamlessly
      this.sock.ev.on('messages.upsert', async ({ messages }) => {
        for (const msg of messages) {
          if (msg.key?.id && msg.message) {
            this.messageStore.set(msg.key.id, msg.message);
            if (msg.key.remoteJid) {
              this.messageStore.set(`${msg.key.remoteJid}:${msg.key.id}`, msg.message);
            }
            if (this.messageStore.size > 3000) {
              const first = this.messageStore.keys().next().value;
              if (first) this.messageStore.delete(first);
            }
          }
        }
      });

      this.sock.ev.on('connection.update', async (update) => {
        const { connection, lastDisconnect, qr } = update;

        if (qr) {
          console.log('[BaileysClient] New QR code generated. Updating Postgres session record...');
          try {
            const qrDataUrl = await QRCode.toDataURL(qr, {
              width: 600,
              margin: 2,
              errorCorrectionLevel: 'M',
              scale: 10
            });
            await this.supabase
              .from('whatsapp_auth_sessions')
              .update({
                status: 'qr_ready',
                qr_code: qrDataUrl,
                tenant_id: this.tenantId || null,
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
              tenant_id: this.tenantId || null,
              last_heartbeat_at: new Date().toISOString(),
              updated_at: new Date().toISOString()
            })
            .eq('id', this.sessionId);
        }

        if (connection === 'close') {
          this.isConnecting = false;
          const statusCode = (lastDisconnect?.error as Boom)?.output?.statusCode;
          const isLoggedOut = statusCode === DisconnectReason.loggedOut;

          console.warn(`[BaileysClient] Connection closed with status: ${statusCode}, loggedOut: ${isLoggedOut}`);

          if (isLoggedOut) {
            console.warn('[BaileysClient] WhatsApp session logged out. Wiping session state in DB...');
            await this.supabase
              .from('whatsapp_auth_sessions')
              .update({
                creds: {},
                keys: {},
                status: 'disconnected',
                connected_phone: null,
                qr_code: null,
                tenant_id: this.tenantId || null,
                updated_at: new Date().toISOString()
              })
              .eq('id', this.sessionId);
            setTimeout(() => this.initialize(), 3000);
          } else {
            // Reconnect without wiping credentials
            const reconnectDelay = statusCode === DisconnectReason.restartRequired ? 1000 : 3000;
            console.log(`[BaileysClient] Reconnecting in ${reconnectDelay}ms (Status: ${statusCode})...`);
            setTimeout(() => this.initialize(), reconnectDelay);
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
   * Send a WhatsApp message to a recipient with full anti-ban pacing and E2EE retry fulfillment.
   */
  public async sendTextMessage(
    phone: string,
    text: string,
    queueItemId?: string
  ): Promise<{ success: boolean; messageId?: string }> {
    if (!this.sock || !this.isConnected()) {
      throw new Error('WhatsApp gateway is not connected. Message queued.');
    }

    if (this.pacer.isCircuitTripped()) {
      throw new Error('Circuit breaker tripped. Queue temporarily paused.');
    }

    // Format phone digits
    const cleanDigits = phone.replace(/\D/g, '');
    let targetJid = `${cleanDigits}@s.whatsapp.net`;

    // 1. Verify recipient on WhatsApp & get canonical JID to ensure correct Signal session keys
    try {
      const waResults = await this.sock.onWhatsApp(cleanDigits);
      if (waResults && waResults.length > 0 && waResults[0].exists && waResults[0].jid) {
        // Enforce standard phone number JID (@s.whatsapp.net), never route through raw @lid
        if (waResults[0].jid.endsWith('@s.whatsapp.net')) {
          targetJid = waResults[0].jid;
        }
        console.log(`[BaileysClient] Verified recipient on WhatsApp: ${targetJid}`);
      }
    } catch (checkErr) {
      console.warn('[BaileysClient] onWhatsApp lookup warning:', (checkErr as Error).message);
    }

    // 2. Humanize message text
    const messageToSend = this.pacer.humanizeMessage(text);

    // 3. Pace & simulate human typing
    await this.pacer.paceAndSimulatePresence(this.sock, targetJid);

    // 4. Dispatch message
    try {
      const result = await this.sock.sendMessage(targetJid, { text: messageToSend });
      if (result && result.key && result.key.id) {
        this.pacer.recordSuccess();
        const msgId = result.key.id;
        console.log(`[BaileysClient] ✅ Message dispatched successfully to ${targetJid} (ID: ${msgId})`);

        // Cache message for E2EE retry fulfillment
        if (result.message) {
          this.messageStore.set(msgId, result.message);
          this.messageStore.set(`${targetJid}:${msgId}`, result.message);
        }

        // Link message ID in database queue metadata for cross-restart E2EE fulfillment
        if (queueItemId) {
          try {
            const { data: currentItem } = await this.supabase
              .from('whatsapp_outbox_queue')
              .select('metadata')
              .eq('id', queueItemId)
              .maybeSingle();

            const mergedMetadata = {
              ...(currentItem?.metadata || {}),
              message_id: msgId,
              target_jid: targetJid,
              sent_at: new Date().toISOString(),
              raw_message: result.message
            };

            await this.supabase
              .from('whatsapp_outbox_queue')
              .update({ metadata: mergedMetadata })
              .eq('id', queueItemId);
          } catch (metaErr) {
            console.warn('[BaileysClient] Failed to link message ID to queue row:', (metaErr as Error).message);
          }
        }

        return { success: true, messageId: msgId };
      }
      return { success: false };
    } catch (err) {
      this.pacer.recordFailure();
      console.error(`[BaileysClient] ❌ Failed to dispatch message to ${targetJid}:`, (err as Error).message);
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

  /**
   * Wipe any stale unauthenticated state and force a brand new QR generation
   */
  public async forceRefreshSession(): Promise<void> {
    try {
      this.isConnecting = false;
      if (this.sock) {
        try {
          this.sock.ev.removeAllListeners('connection.update');
          this.sock.ev.removeAllListeners('creds.update');
          this.sock.end(undefined);
        } catch (_) {}
        this.sock = null;
      }

      await this.supabase
        .from('whatsapp_auth_sessions')
        .update({
          creds: {},
          keys: {},
          status: 'disconnected',
          qr_code: null,
          tenant_id: this.tenantId || null,
          updated_at: new Date().toISOString()
        })
        .eq('id', this.sessionId);

      console.log('[BaileysClient] Forced refresh requested. Restarting socket with clean state...');
      await this.initialize();
    } catch (e) {
      console.error('[BaileysClient] Error in forceRefreshSession:', e);
    }
  }
}
