import { AuthenticationCreds, AuthenticationState, BufferJSON, initAuthCreds, SignalKeyStore, proto } from '@whiskeysockets/baileys';
import { SupabaseClient } from '@supabase/supabase-js';

/**
 * Enterprise-grade PostgreSQL-backed Auth State for Baileys Multi-Device.
 * Stores credentials and cryptographic keys in Supabase, making the gateway 100% stateless.
 */
export async function usePostgresAuthState(
  supabase: SupabaseClient,
  sessionId: string,
  tenantId?: string
): Promise<{ state: AuthenticationState; saveCreds: () => Promise<void> }> {
  // 1. Fetch current session record
  const { data: sessionRow, error: fetchError } = await supabase
    .from('whatsapp_auth_sessions')
    .select('creds, keys')
    .eq('id', sessionId)
    .maybeSingle();

  if (fetchError) {
    console.error('[PostgresAuth] Database connection error fetching session:', fetchError.message);
    throw new Error(`[PostgresAuth] Fatal error fetching session from Supabase: ${fetchError.message}`);
  }

  let creds: AuthenticationCreds;
  let keysStore: Record<string, any> = {};

  if (sessionRow && sessionRow.creds && Object.keys(sessionRow.creds).length > 0) {
    try {
      const rawCreds = JSON.stringify(sessionRow.creds);
      creds = JSON.parse(rawCreds, BufferJSON.reviver);
    } catch {
      creds = initAuthCreds();
    }
    if (sessionRow.keys) {
      try {
        const rawKeys = JSON.stringify(sessionRow.keys);
        keysStore = JSON.parse(rawKeys, BufferJSON.reviver);
      } catch {
        keysStore = {};
      }
    }
  } else {
    creds = initAuthCreds();
    // Initialize session record in DB with error check
    const { error: initError } = await supabase.from('whatsapp_auth_sessions').upsert({
      id: sessionId,
      tenant_id: tenantId || null,
      creds: JSON.parse(JSON.stringify(creds, BufferJSON.replacer)),
      keys: {},
      status: 'disconnected',
      updated_at: new Date().toISOString()
    });
    if (initError) {
      throw new Error(`[PostgresAuth] Failed to initialize session in DB: ${initError.message}`);
    }
  }

  /**
   * Strictly sequential write queue (Mutex) to ensure all Signal keys & credentials
   * are persisted in exact chronological order without race conditions or overwriting.
   */
  let writeQueue: Promise<void> = Promise.resolve();
  const enqueueWrite = (fn: () => Promise<void>): Promise<void> => {
    writeQueue = writeQueue.then(async () => {
      await fn();
    }).catch((err) => {
      console.error('[PostgresAuth] Queue write failure:', err.message);
      throw err;
    });
    return writeQueue;
  };

  const flushKeys = (): Promise<void> => {
    return enqueueWrite(async () => {
      const serializedKeys = JSON.parse(JSON.stringify(keysStore, BufferJSON.replacer));
      const { data, error } = await supabase
        .from('whatsapp_auth_sessions')
        .update({
          keys: serializedKeys,
          updated_at: new Date().toISOString()
        })
        .eq('id', sessionId)
        .select('id')
        .single();

      if (error) {
        throw new Error(`[PostgresAuth] Supabase error persisting keys: ${error.message}`);
      }
      if (!data) {
        throw new Error('[PostgresAuth] Auth session record not found during key flush');
      }
      console.log('[PostgresAuth] ✅ Signal keys persisted to DB (ordered & verified).');
    });
  };

  const keys: SignalKeyStore = {
    get: async (type, ids) => {
      const data: Record<string, any> = {};
      for (const id of ids) {
        const key = `${type}-${id}`;
        let value = keysStore[key];
        if (type === 'app-state-sync-key' && value) {
          value = proto.Message.AppStateSyncKeyData.fromObject(value);
        }
        if (value) {
          data[id] = value;
        }
      }
      return data;
    },
    set: async (data: any) => {
      const dataObj = data as Record<string, Record<string, any>>;

      for (const category in dataObj) {
        for (const id in dataObj[category]) {
          const value = dataObj[category][id];
          const key = `${category}-${id}`;
          if (value) {
            keysStore[key] = value;
          } else {
            delete keysStore[key];
          }
        }
      }

      // Persist all key updates sequentially through verified queue
      await flushKeys();
    }
  };

  const saveCreds = async () => {
    return enqueueWrite(async () => {
      const serializedCreds = JSON.parse(JSON.stringify(creds, BufferJSON.replacer));
      const serializedKeys = JSON.parse(JSON.stringify(keysStore, BufferJSON.replacer));
      const { data, error } = await supabase
        .from('whatsapp_auth_sessions')
        .update({
          creds: serializedCreds,
          keys: serializedKeys,
          updated_at: new Date().toISOString()
        })
        .eq('id', sessionId)
        .select('id')
        .single();

      if (error) {
        throw new Error(`[PostgresAuth] Supabase error saving credentials: ${error.message}`);
      }
      if (!data) {
        throw new Error('[PostgresAuth] Auth session record not found during creds save');
      }
      console.log('[PostgresAuth] ✅ Credentials saved to DB (ordered & verified).');
    });
  };

  return {
    state: {
      creds,
      keys
    },
    saveCreds
  };
}
