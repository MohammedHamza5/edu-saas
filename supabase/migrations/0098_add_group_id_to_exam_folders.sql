-- Migration 0098: Add group_id to exam_folders for group-scoped folder organization
-- Allows teachers to organize exams into folders per group and students to view folders strictly scoped to their enrolled groups.

-- 1. Add group_id column referencing public.groups
ALTER TABLE public.exam_folders 
ADD COLUMN IF NOT EXISTS group_id uuid REFERENCES public.groups(id) ON DELETE CASCADE;

-- 2. Index for high-performance scoped lookups (tenant + group + sort)
CREATE INDEX IF NOT EXISTS idx_exam_folders_tenant_group 
ON public.exam_folders(tenant_id, group_id, sort_order);

-- 3. Update Student RLS policy for exam_folders
-- Students can only read folders belonging to their active groups or general folders (group_id IS NULL)
DROP POLICY IF EXISTS exam_folders_student_read ON public.exam_folders;

CREATE POLICY exam_folders_student_read ON public.exam_folders FOR SELECT TO authenticated
  USING (
    public.has_role('student') 
    AND public.tenant_is_active() 
    AND tenant_id = public.my_tenant_id()
    AND (
      group_id IS NULL 
      OR group_id IN (
        SELECT gm.group_id 
        FROM public.group_members gm 
        WHERE gm.student_id = auth.uid() 
          AND gm.status = 'active'
      )
    )
  );

-- 4. Update Parent RLS policy for exam_folders
-- Parents can only read folders belonging to groups of their active linked students
DROP POLICY IF EXISTS exam_folders_parent_read ON public.exam_folders;

CREATE POLICY exam_folders_parent_read ON public.exam_folders FOR SELECT TO authenticated
  USING (
    public.has_role('parent') 
    AND public.tenant_is_active() 
    AND tenant_id = public.my_tenant_id()
    AND (
      group_id IS NULL 
      OR group_id IN (
        SELECT gm.group_id 
        FROM public.group_members gm 
        JOIN public.parent_students ps ON ps.student_id = gm.student_id
        WHERE ps.parent_id = auth.uid() 
          AND gm.status = 'active'
      )
    )
  );

-- 5. Update move_exam_to_folder RPC with group consistency validation
CREATE OR REPLACE FUNCTION public.move_exam_to_folder(
    p_exam_id uuid,
    p_folder_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_tenant_id uuid;
    v_folder_tenant_id uuid;
    v_folder_group_id uuid;
    v_exam_group_id uuid;
BEGIN
    IF NOT (public.has_role('teacher') AND public.tenant_is_active()) THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    v_tenant_id := public.my_tenant_id();

    -- Verify exam belongs to teacher's tenant and get its group_id
    SELECT c.group_id INTO v_exam_group_id
    FROM public.exams e
    JOIN public.content c ON c.id = e.content_id
    WHERE e.id = p_exam_id AND e.tenant_id = v_tenant_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Exam not found or does not belong to tenant' USING ERRCODE = 'P0002';
    END IF;

    -- If folder provided, verify folder belongs to same tenant and matches group if scoped
    IF p_folder_id IS NOT NULL THEN
        SELECT tenant_id, group_id INTO v_folder_tenant_id, v_folder_group_id 
        FROM public.exam_folders 
        WHERE id = p_folder_id;

        IF v_folder_tenant_id IS NULL OR v_folder_tenant_id != v_tenant_id THEN
            RAISE EXCEPTION 'Folder not found or does not belong to tenant' USING ERRCODE = 'P0002';
        END IF;

        -- If folder is group-scoped and exam is group-scoped, verify match
        IF v_folder_group_id IS NOT NULL AND v_exam_group_id IS NOT NULL AND v_folder_group_id != v_exam_group_id THEN
            RAISE EXCEPTION 'Folder belongs to a different group than the exam' USING ERRCODE = '22000';
        END IF;
    END IF;

    UPDATE public.exams
    SET folder_id = p_folder_id,
        updated_at = now()
    WHERE id = p_exam_id AND tenant_id = v_tenant_id;

    RETURN jsonb_build_object(
        'success', true,
        'exam_id', p_exam_id,
        'folder_id', p_folder_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.move_exam_to_folder(uuid, uuid) TO authenticated;
