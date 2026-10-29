import { SupabaseClient } from '@supabase/supabase-js';
import { BaileysGatewayClient } from '../engine/baileys_client';

export interface QueueItem {
  id: string;
  tenant_id: string;
  recipient_phone: string;
  student_name: string;
  exam_title: string;
  message_body: string;
  retry_count: number;
}

export class QueueWorker {
  private supabase: SupabaseClient;
  private client: BaileysGatewayClient;
  private isProcessing: boolean = false;
  private pollTimer: NodeJS.Timeout | null = null;
  private heartbeatTimer: NodeJS.Timeout | null = null;
  private pollIntervalMs: number;

  constructor(
    supabase: SupabaseClient,
    client: BaileysGatewayClient,
    pollIntervalMs: number = 5000
  ) {
    this.supabase = supabase;
    this.client = client;
    this.pollIntervalMs = pollIntervalMs;
  }

  public start(): void {
    console.log('[QueueWorker] 🚀 Outbox Queue Worker started.');
    this.pollTimer = setInterval(() => this.processNextBatch(), this.pollIntervalMs);
    this.heartbeatTimer = setInterval(() => this.client.sendHeartbeat(), 30000);
  }

  public stop(): void {
    if (this.pollTimer) clearInterval(this.pollTimer);
    if (this.heartbeatTimer) clearInterval(this.heartbeatTimer);
    console.log('[QueueWorker] ⏹️ Outbox Queue Worker stopped.');
  }

  public async triggerPoll(): Promise<void> {
    if (!this.isProcessing) {
      await this.processNextBatch();
    }
  }

  private async processNextBatch(): Promise<void> {
    if (this.isProcessing) return;

    // Only process if WhatsApp connection is active
    if (!this.client.isConnected()) {
      return;
    }

    if (this.client.getPacer().isCircuitTripped()) {
      return;
    }

    this.isProcessing = true;

    try {
      // 1. Fetch next batch with DB row lock (FOR UPDATE SKIP LOCKED)
      const { data: batch, error } = await this.supabase.rpc('fetch_next_whatsapp_queue_batch', {
        p_batch_size: 5
      });

      if (error) {
        console.error('[QueueWorker] Error fetching outbox batch:', error.message);
        this.isProcessing = false;
        return;
      }

      const items = (batch as QueueItem[]) || [];
      if (items.length === 0) {
        this.isProcessing = false;
        return;
      }

      console.log(`[QueueWorker] Processing ${items.length} pending message(s)...`);

      // 2. Process items sequentially with human pacing
      for (const item of items) {
        try {
          console.log(`[QueueWorker] Dispatching exam result to ${item.recipient_phone} (Student: ${item.student_name})...`);
          
          await this.client.sendTextMessage(item.recipient_phone, item.message_body, item.id);

          // 3. Mark as sent
          await this.supabase.rpc('update_whatsapp_queue_status', {
            p_id: item.id,
            p_status: 'sent',
            p_error: null
          });
          console.log(`[QueueWorker] Result for ${item.student_name} marked as SENT.`);
        } catch (itemErr) {
          const errMsg = (itemErr as Error).message;
          console.error(`[QueueWorker] Failed to dispatch item ${item.id}:`, errMsg);

          // Mark as failed or dead_letter with backoff
          await this.supabase.rpc('update_whatsapp_queue_status', {
            p_id: item.id,
            p_status: 'failed',
            p_error: errMsg
          });
        }
      }
    } catch (batchErr) {
      console.error('[QueueWorker] Unexpected batch worker error:', batchErr);
    } finally {
      this.isProcessing = false;
    }
  }
}
