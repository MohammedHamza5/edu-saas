-- Migration 0108: Add processing_started_at column to whatsapp_outbox_queue
-- Resolves Postgres error 42703 (column "processing_started_at" does not exist)
-- This column was referenced in fetch_next_whatsapp_queue_batch (migration 0107) for outbox processing timestamps.

ALTER TABLE public.whatsapp_outbox_queue 
ADD COLUMN IF NOT EXISTS processing_started_at TIMESTAMPTZ;

-- Index for worker recovery of stuck in-flight processing records
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_processing_started 
  ON public.whatsapp_outbox_queue(status, processing_started_at) 
  WHERE status = 'processing';
