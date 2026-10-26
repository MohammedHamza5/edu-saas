import { AuthenticationCreds, AuthenticationState, BufferJSON, initAuthCreds, SignalKeyStore } from '@whiskeysockets/baileys';
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

  const keys: SignalKeyStore = {
    get: async (type, ids) => {
      const data: Record<string, any> = {};
      for (const id of ids) {
        const key = `${type}-${id}`;
        if (keysStore[key]) {
          data[id] = keysStore[key];
        }
      }
      return data;
    },
    set: async (data) => {
      for (const category in data) {
        for (const id in data[category]) {
          const value = data[category][id];
          const key = `${category}-${id}`;
          if (value) {
            keysStore[key] = value;
          } else {
            delete keysStore[key];
          }
        }
      }

      // Persist keys to Postgres
      const serializedKeys = JSON.parse(JSON.stringify(keysStore, BufferJSON.replacer));
      await supabase
        .from('whatsapp_auth_sessions')
        .update({
          keys: serializedKeys,
          updated_at: new Date().toISOString()
        })
        .eq('id', sessionId);
    }
  };

  const saveCreds = async () => {
    const serializedCreds = JSON.parse(JSON.stringify(creds, BufferJSON.replacer));
    await supabase
      .from('whatsapp_auth_sessions')
      .update({
        creds: serializedCreds,
        updated_at: new Date().toISOString()
      })
      .eq('id', sessionId);
  };

  return {
    state: {
      creds,
      keys
    },
    saveCreds
  };
}
