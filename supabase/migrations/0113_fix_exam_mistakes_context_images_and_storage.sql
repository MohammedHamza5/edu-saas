-- ==============================================================================
-- Migration: 0113_fix_exam_mistakes_context_images_and_storage.sql
-- Description:
--   1. Updates get_student_mistakes_questions RPC to fallback to exam_contexts.image_url
--      when a question's diagram or figure is stored in exam_contexts.
--   2. Includes audio_url and audio_duration_seconds in get_student_mistakes_questions.
--   3. Makes 'qb-documents' storage bucket public and allows public read access for crops
--      so that question diagrams and crops render across all browsers and clients.
-- ==============================================================================

-- 1. Update get_student_mistakes_questions RPC
CREATE OR REPLACE FUNCTION public.get_student_mistakes_questions(
  p_student_id UUID,
  p_exam_id UUID DEFAULT NULL,
  p_only_unresolved BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_questions JSONB;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF v_caller != p_student_id AND NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'mistake_id', sm.id,
        'question_id', q.id,
        'question_text', q.question_text,
        'question_type', q.question_type,
        'points', q.points,
        'sort_order', q.sort_order,
        'image_url', COALESCE(q.image_url, ec.image_url),
        'image_meta', COALESCE(q.image_meta, ec.image_meta),
        'audio_url', q.audio_url,
        'audio_duration_seconds', q.audio_duration_seconds,
        'is_resolved', sm.is_resolved,
        'failure_count', sm.failure_count,
        'last_failed_at', sm.last_failed_at,
        'source_exam_id', sm.source_exam_id,
        'source_exam_title', COALESCE(e.title, c.title, 'اختبار'),
        'lesson_title', c.title,
        'last_selected_option_id', sm.selected_option_id,
        'is_skipped', (sm.selected_option_id IS NULL),
        'reflection_reason', sm.reflection_reason,
        'selected_option_text', (
          SELECT opt.option_text 
          FROM public.question_options opt 
          WHERE opt.id = sm.selected_option_id
          LIMIT 1
        ),
        'options', (
          SELECT COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'id', opt.id,
                'option_text', opt.option_text,
                'sort_order', opt.sort_order
              ) ORDER BY opt.sort_order ASC
            ),
            '[]'::jsonb
          )
          FROM public.question_options opt
          WHERE opt.question_id = q.id
        )
      ) ORDER BY sm.is_resolved ASC, sm.last_failed_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_questions
  FROM public.student_mistakes sm
  JOIN public.exam_questions q ON q.id = sm.question_id
  LEFT JOIN public.exam_contexts ec ON ec.id = q.context_id
  JOIN public.exams e ON e.id = sm.source_exam_id
  LEFT JOIN public.content c ON c.id = e.content_id
  WHERE sm.student_id = p_student_id
    AND (p_exam_id IS NULL OR sm.source_exam_id = p_exam_id)
    AND (NOT p_only_unresolved OR sm.is_resolved = false);

  RETURN v_questions;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_student_mistakes_questions(UUID, UUID, BOOLEAN) TO authenticated;

-- 2. Make 'qb-documents' public for question crops & images
UPDATE storage.buckets
SET public = true
WHERE id = 'qb-documents';

-- 3. Storage policy to allow public read of question documents & crops
DROP POLICY IF EXISTS "Allow public read qb-documents" ON storage.objects;
CREATE POLICY "Allow public read qb-documents"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'qb-documents');

-- 4. Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';
