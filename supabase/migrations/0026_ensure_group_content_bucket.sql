-- ============================================================================
-- 0026_ensure_group_content_bucket.sql
-- Ensure group-content and submission-files storage buckets exist in Supabase
-- ============================================================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  (
    'group-content',
    'group-content',
    false,
    52428800, -- 50 MB
    ARRAY['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'application/pdf']
  ),
  (
    'submission-files',
    'submission-files',
    false,
    52428800, -- 50 MB
    ARRAY['application/pdf', 'image/png', 'image/jpeg', 'image/webp']
  )
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 52428800,
  allowed_mime_types = EXCLUDED.allowed_mime_types;
