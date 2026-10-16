-- Migration 0090: Clean up deprecated overloaded database functions
-- Removes redundant older signatures that caused PostgREST ambiguous function errors,
-- leaving the modern, canonical implementations intact.

-- 1. Remove old assign_content_to_groups(uuid, uuid[])
-- The canonical version is assign_content_to_groups(uuid, uuid[], jsonb)
DROP FUNCTION IF EXISTS public.assign_content_to_groups(uuid, uuid[]);

-- 2. Remove old create_chapter(uuid, text)
-- The canonical version is create_chapter(uuid, text, boolean)
DROP FUNCTION IF EXISTS public.create_chapter(uuid, text);

-- 3. Remove old get_video_bank_contents(uuid)
-- The canonical version is get_video_bank_contents(uuid, text)
DROP FUNCTION IF EXISTS public.get_video_bank_contents(uuid);
