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
    console.error('[PostgresAuth] Error fetching session:', fetchError.message);
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
    // Initialize session record in DB
    await supabase.from('whatsapp_auth_sessions').upsert({
      id: sessionId,
      tenant_id: tenantId || null,
      creds: JSON.parse(JSON.stringify(creds, BufferJSON.replacer)),
      keys: {},
      status: 'disconnected',
      updated_at: new Date().toISOString()
    });
  }

  /**
   * Flush all in-memory keys to Supabase immediately (synchronous write).
   * Called without debounce for cryptographically critical key categories.
   */
  const flushKeys = async (): Promise<void> => {
    try {
      const serializedKeys = JSON.parse(JSON.stringify(keysStore, BufferJSON.replacer));
      await supabase
        .from('whatsapp_auth_sessions')
        .update({
          keys: serializedKeys,
          updated_at: new Date().toISOString()
        })
        .eq('id', sessionId);
      console.log('[PostgresAuth] ✅ Critical Signal keys flushed to DB immediately.');
    } catch (err) {
      console.warn('[PostgresAuth] flushKeys error:', (err as Error).message);
    }
  };

  let keysSaveTimeout: NodeJS.Timeout | null = null;
  const debouncedSaveKeys = () => {
    if (keysSaveTimeout) clearTimeout(keysSaveTimeout);
    keysSaveTimeout = setTimeout(async () => {
      try {
        const serializedKeys = JSON.parse(JSON.stringify(keysStore, BufferJSON.replacer));
        await supabase
          .from('whatsapp_auth_sessions')
          .update({
            keys: serializedKeys,
            updated_at: new Date().toISOString()
          })
          .eq('id', sessionId);
      } catch (err) {
        console.warn('[PostgresAuth] Debounced save warning:', (err as Error).message);
      }
    }, 400);
  };

  /**
   * Critical key categories that must be persisted immediately (no debounce).
   * These are used during E2EE session establishment and replay protection.
   */
  const CRITICAL_KEY_CATEGORIES = new Set(['session', 'pre-key', 'signed-pre-key', 'sender-key', 'sender-key-memory']);

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
      let hasCriticalCategory = false;

      for (const category in dataObj) {
        if (CRITICAL_KEY_CATEGORIES.has(category)) hasCriticalCategory = true;
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

      // Persist critical E2EE keys immediately to prevent session loss across restarts
      if (hasCriticalCategory) {
        await flushKeys();
      } else {
        debouncedSaveKeys();
      }
    }
  };

  const saveCreds = async () => {
    try {
      if (keysSaveTimeout) clearTimeout(keysSaveTimeout);
      const serializedCreds = JSON.parse(JSON.stringify(creds, BufferJSON.replacer));
      const serializedKeys = JSON.parse(JSON.stringify(keysStore, BufferJSON.replacer));
      await supabase
        .from('whatsapp_auth_sessions')
        .update({
          creds: serializedCreds,
          keys: serializedKeys,
          updated_at: new Date().toISOString()
        })
        .eq('id', sessionId);
    } catch (err) {
      console.error('[PostgresAuth] Error saving creds & keys:', err);
    }
  };

  return {
    state: {
      creds,
      keys
    },
    saveCreds
  };
}
