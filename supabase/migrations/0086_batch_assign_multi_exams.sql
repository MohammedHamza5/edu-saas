-- Migration 0086: Multi-Exam Support for Batch Assignment & lesson_exams Sync
-- Enables attaching multiple quizzes per lecture in assign_batch_content_to_group RPC

CREATE OR REPLACE FUNCTION public.assign_batch_content_to_group(
  p_group_id uuid,
  p_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_role text;
  v_caller_tenant uuid;
  v_item jsonb;
  v_content_id uuid;
  v_raw_content_id text;
  v_actual_content_id uuid;
  v_chapter_id uuid;
  v_custom_title text;
  v_file_id uuid;
  v_assoc_exam_id uuid;
  v_is_published boolean;
  v_sort_order int;
  v_lib_video record;
  v_success_count int := 0;
  v_attached_exams jsonb;
  v_exam_elem jsonb;
  v_idx int;
  v_target_exam_id uuid;
  v_target_sort int;
  v_target_req boolean;
BEGIN
  IF NOT public.has_role('teacher') THEN
    RAISE EXCEPTION 'NOT_AUTHORIZED: Only teachers can assign content';
  END IF;

  v_caller_tenant := public.my_tenant_id();

  IF NOT EXISTS (SELECT 1 FROM public.groups WHERE id = p_group_id AND tenant_id = v_caller_tenant) THEN
    RAISE EXCEPTION 'GROUP_NOT_FOUND';
  END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object('success', true, 'count', 0);
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_raw_content_id := v_item->>'content_id';
    IF v_raw_content_id IS NULL OR v_raw_content_id = '' THEN
      CONTINUE;
    END IF;

    v_content_id := v_raw_content_id::uuid;
    v_custom_title := NULLIF(trim(v_item->>'custom_title'), '');
    v_chapter_id := CASE WHEN v_item->>'chapter_id' IS NOT NULL AND (v_item->>'chapter_id') != '' THEN (v_item->>'chapter_id')::uuid ELSE NULL END;
    v_file_id := CASE WHEN v_item->>'file_id' IS NOT NULL AND (v_item->>'file_id') != '' THEN (v_item->>'file_id')::uuid ELSE NULL END;
    v_assoc_exam_id := CASE WHEN v_item->>'associated_exam_id' IS NOT NULL AND (v_item->>'associated_exam_id') != '' THEN (v_item->>'associated_exam_id')::uuid ELSE NULL END;
    v_is_published := COALESCE((v_item->>'is_published')::boolean, true);
    v_attached_exams := v_item->'attached_exams';

    -- If attached_exams is passed, ensure assoc_exam_id points to the first attached exam
    IF v_attached_exams IS NOT NULL AND jsonb_typeof(v_attached_exams) = 'array' AND jsonb_array_length(v_attached_exams) > 0 THEN
      v_assoc_exam_id := ((v_attached_exams->0)->>'exam_id')::uuid;
    ELSIF v_attached_exams IS NOT NULL AND jsonb_typeof(v_attached_exams) = 'array' AND jsonb_array_length(v_attached_exams) = 0 THEN
      v_assoc_exam_id := NULL;
    END IF;

    -- Check if v_content_id is already in public.content
    SELECT id INTO v_actual_content_id
    FROM public.content
    WHERE id = v_content_id AND tenant_id = v_caller_tenant;

    -- If not, check video_library
    IF v_actual_content_id IS NULL THEN
      SELECT * INTO v_lib_video
      FROM public.video_library
      WHERE id = v_content_id AND tenant_id = v_caller_tenant;

      IF v_lib_video.id IS NOT NULL THEN
        SELECT c.id INTO v_actual_content_id
        FROM public.content c
        JOIN public.videos v ON v.content_id = c.id
        WHERE v.library_video_id = v_lib_video.id AND c.tenant_id = v_caller_tenant
        LIMIT 1;

        IF v_actual_content_id IS NULL THEN
          INSERT INTO public.content (
            tenant_id,
            group_id,
            title,
            description,
            type,
            status,
            sort_order
          ) VALUES (
            v_caller_tenant,
            p_group_id,
            COALESCE(v_custom_title, v_lib_video.title),
            v_lib_video.description,
            'video',
            'published',
            0
          ) RETURNING id INTO v_actual_content_id;

          INSERT INTO public.videos (
            content_id,
            library_video_id,
            provider,
            provider_video_id,
            thumbnail_url,
            duration,
            status
          ) VALUES (
            v_actual_content_id,
            v_lib_video.id,
            COALESCE(v_lib_video.provider, 'bunny'),
            v_lib_video.provider_video_id,
            v_lib_video.thumbnail_url,
            v_lib_video.duration,
            'ready'
          );
        END IF;
      END IF;
    END IF;

    IF v_actual_content_id IS NOT NULL THEN
      IF v_chapter_id IS NOT NULL THEN
        SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_sort_order
        FROM public.content_groups
        WHERE group_id = p_group_id AND chapter_id = v_chapter_id;
      ELSE
        SELECT COALESCE(MAX(sort_order), -1) + 1 INTO v_sort_order
        FROM public.content_groups
        WHERE group_id = p_group_id AND chapter_id IS NULL;
      END IF;

      INSERT INTO public.content_groups (
        tenant_id,
        content_id,
        group_id,
        chapter_id,
        file_id,
        associated_exam_id,
        sort_order,
        custom_title,
        is_published
      ) VALUES (
        v_caller_tenant,
        v_actual_content_id,
        p_group_id,
        v_chapter_id,
        v_file_id,
        v_assoc_exam_id,
        v_sort_order,
        v_custom_title,
        v_is_published
      )
      ON CONFLICT (content_id, group_id) DO UPDATE SET
        chapter_id = EXCLUDED.chapter_id,
        file_id = COALESCE(EXCLUDED.file_id, content_groups.file_id),
        associated_exam_id = EXCLUDED.associated_exam_id,
        sort_order = EXCLUDED.sort_order,
        custom_title = COALESCE(EXCLUDED.custom_title, content_groups.custom_title),
        is_published = EXCLUDED.is_published;

      -- Sync lesson_exams for multi-exam support
      IF v_attached_exams IS NOT NULL AND jsonb_typeof(v_attached_exams) = 'array' THEN
        DELETE FROM public.lesson_exams
        WHERE group_id = p_group_id AND content_id = v_actual_content_id;

        v_idx := 0;
        FOR v_exam_elem IN SELECT * FROM jsonb_array_elements(v_attached_exams)
        LOOP
          v_target_exam_id := (v_exam_elem->>'exam_id')::uuid;
          v_target_sort := COALESCE((v_exam_elem->>'sort_order')::int, v_idx);
          v_target_req := COALESCE((v_exam_elem->>'is_required')::boolean, true);

          IF v_target_exam_id IS NOT NULL THEN
            INSERT INTO public.lesson_exams (
              tenant_id,
              group_id,
              content_id,
              exam_id,
              sort_order,
              is_required
            ) VALUES (
              v_caller_tenant,
              p_group_id,
              v_actual_content_id,
              v_target_exam_id,
              v_target_sort,
              v_target_req
            )
            ON CONFLICT (group_id, content_id, exam_id)
            DO UPDATE SET
              sort_order = EXCLUDED.sort_order,
              is_required = EXCLUDED.is_required,
              updated_at = now();
          END IF;
          v_idx := v_idx + 1;
        END LOOP;
      ELSIF v_assoc_exam_id IS NOT NULL THEN
        INSERT INTO public.lesson_exams (
          tenant_id,
          group_id,
          content_id,
          exam_id,
          sort_order,
          is_required
        ) VALUES (
          v_caller_tenant,
          p_group_id,
          v_actual_content_id,
          v_assoc_exam_id,
          0,
          true
        )
        ON CONFLICT (group_id, content_id, exam_id) DO NOTHING;
      END IF;

      IF v_custom_title IS NOT NULL THEN
        UPDATE public.content
        SET title = v_custom_title,
            updated_at = now()
        WHERE id = v_actual_content_id;
      END IF;

      v_success_count := v_success_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'count', v_success_count
  );
END;
$$;
