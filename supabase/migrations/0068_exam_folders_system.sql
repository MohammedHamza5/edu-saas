-- Migration 0068: Exam Folders System for scalable organization
-- Supports categorizing 100+ exams into folders / units / chapters

CREATE TABLE IF NOT EXISTS public.exam_folders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    name text NOT NULL,
    description text,
    color text NOT NULL DEFAULT '#5B4FE0',
    icon text NOT NULL DEFAULT 'folder',
    sort_order int NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Index for tenant sorting
CREATE INDEX IF NOT EXISTS idx_exam_folders_tenant ON public.exam_folders(tenant_id, sort_order);

-- Enable RLS
ALTER TABLE public.exam_folders ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS exam_folders_teacher_all ON public.exam_folders;
DROP POLICY IF EXISTS exam_folders_student_read ON public.exam_folders;
DROP POLICY IF EXISTS exam_folders_parent_read ON public.exam_folders;

-- Policies
CREATE POLICY exam_folders_teacher_all ON public.exam_folders FOR ALL TO authenticated
  USING (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id())
  WITH CHECK (public.has_role('teacher') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id());

CREATE POLICY exam_folders_student_read ON public.exam_folders FOR SELECT TO authenticated
  USING (public.has_role('student') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id());

CREATE POLICY exam_folders_parent_read ON public.exam_folders FOR SELECT TO authenticated
  USING (public.has_role('parent') AND public.tenant_is_active() AND tenant_id = public.my_tenant_id());

-- Add folder_id to exams table
ALTER TABLE public.exams ADD COLUMN IF NOT EXISTS folder_id uuid REFERENCES public.exam_folders(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_exams_folder ON public.exams(folder_id);
CREATE INDEX IF NOT EXISTS idx_exams_tenant_folder ON public.exams(tenant_id, folder_id);

-- Helper RPC to safely move/assign exam to folder
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
BEGIN
    IF NOT (public.has_role('teacher') AND public.tenant_is_active()) THEN
        RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
    END IF;

    v_tenant_id := public.my_tenant_id();

    -- Verify exam belongs to teacher's tenant
    IF NOT EXISTS (SELECT 1 FROM public.exams WHERE id = p_exam_id AND tenant_id = v_tenant_id) THEN
        RAISE EXCEPTION 'Exam not found or does not belong to tenant' USING ERRCODE = 'P0002';
    END IF;

    -- If folder provided, verify folder belongs to same tenant
    IF p_folder_id IS NOT NULL THEN
        SELECT tenant_id INTO v_folder_tenant_id FROM public.exam_folders WHERE id = p_folder_id;
        IF v_folder_tenant_id IS NULL OR v_folder_tenant_id != v_tenant_id THEN
            RAISE EXCEPTION 'Folder not found or does not belong to tenant' USING ERRCODE = 'P0002';
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
