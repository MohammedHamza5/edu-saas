-- ============================================================================
-- 0022_qb_storage_bucket.sql
-- Create private storage bucket for question bank exam documents
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'qb-documents',
  'qb-documents',
  false,
  52428800, -- 50 MB
  ARRAY['application/pdf', 'image/png', 'image/jpeg', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 52428800,
  allowed_mime_types = ARRAY['application/pdf', 'image/png', 'image/jpeg', 'image/webp'];
