-- ============================================================================
-- Migration: 0070_rls_perf_and_covering_indexes.sql
-- Purpose:
-- 1. Add covering indexes for high-frequency unindexed foreign keys
--    (assignments, attendance, exam_attempts, files, student_mistakes, etc.)
-- 2. Optimize RLS policies across core tables to use (SELECT auth.uid())
--    to prevent expensive per-row re-evaluation (resolves auth_rls_initplan warnings)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Covering Indexes for Foreign Keys
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_assignments_tenant_id 
  ON public.assignments(tenant_id);

CREATE INDEX IF NOT EXISTS idx_attendance_tenant_id 
  ON public.attendance(tenant_id);

CREATE INDEX IF NOT EXISTS idx_attendance_marked_by 
  ON public.attendance(marked_by);

CREATE INDEX IF NOT EXISTS idx_exam_attempts_exam_version_id 
  ON public.exam_attempts(exam_version_id);

CREATE INDEX IF NOT EXISTS idx_files_tenant_id 
  ON public.files(tenant_id);

CREATE INDEX IF NOT EXISTS idx_files_content_id 
  ON public.files(content_id);

CREATE INDEX IF NOT EXISTS idx_assignment_submissions_reviewed_by 
  ON public.assignment_submissions(reviewed_by);

CREATE INDEX IF NOT EXISTS idx_notification_recipients_notification_id 
  ON public.notification_recipients(notification_id);

CREATE INDEX IF NOT EXISTS idx_student_mistakes_question_id 
  ON public.student_mistakes(question_id);

CREATE INDEX IF NOT EXISTS idx_student_mistakes_source_attempt_id 
  ON public.student_mistakes(source_attempt_id);

CREATE INDEX IF NOT EXISTS idx_submission_files_submission_id 
  ON public.submission_files(submission_id);

CREATE INDEX IF NOT EXISTS idx_user_devices_user_id 
  ON public.user_devices(user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant_id 
  ON public.audit_logs(tenant_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_user_id 
  ON public.audit_logs(actor_user_id);

CREATE INDEX IF NOT EXISTS idx_manual_lesson_unlocks_unlocked_by 
  ON public.manual_lesson_unlocks(unlocked_by);


-- ----------------------------------------------------------------------------
-- 2. Optimize RLS Policies: Wrap auth.uid() in (SELECT auth.uid())
-- ----------------------------------------------------------------------------

-- A. Users
DROP POLICY IF EXISTS users_own_read ON public.users;
CREATE POLICY users_own_read ON public.users
  FOR SELECT TO authenticated
  USING (id = (SELECT auth.uid()));

DROP POLICY IF EXISTS users_own_update ON public.users;
CREATE POLICY users_own_update ON public.users
  FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid()))
  WITH CHECK (id = (SELECT auth.uid()));

DROP POLICY IF EXISTS users_parent_read_children ON public.users;
CREATE POLICY users_parent_read_children ON public.users
  FOR SELECT TO authenticated
  USING (has_role('parent') AND tenant_is_active() AND is_parent_of_student((SELECT auth.uid()), id));

-- B. Group Members
DROP POLICY IF EXISTS gm_student_read_own ON public.group_members;
CREATE POLICY gm_student_read_own ON public.group_members
  FOR SELECT TO authenticated
  USING (student_id = (SELECT auth.uid()) AND tenant_is_active());

DROP POLICY IF EXISTS gm_parent_read_children ON public.group_members;
CREATE POLICY gm_parent_read_children ON public.group_members
  FOR SELECT TO authenticated
  USING (has_role('parent') AND tenant_is_active() AND is_parent_of_student((SELECT auth.uid()), student_id));

-- C. Parent Students
DROP POLICY IF EXISTS ps_parent_read_own ON public.parent_students;
CREATE POLICY ps_parent_read_own ON public.parent_students
  FOR SELECT TO authenticated
  USING (parent_id = (SELECT auth.uid()) AND tenant_is_active());

DROP POLICY IF EXISTS ps_student_read_own ON public.parent_students;
CREATE POLICY ps_student_read_own ON public.parent_students
  FOR SELECT TO authenticated
  USING (student_id = (SELECT auth.uid()) AND tenant_is_active());

-- D. Groups
DROP POLICY IF EXISTS groups_student_read_member ON public.groups;
CREATE POLICY groups_student_read_member ON public.groups
  FOR SELECT TO authenticated
  USING (
    has_role('student') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = groups.id AND gm.student_id = (SELECT auth.uid()) AND gm.status = 'active'
    )
  );

DROP POLICY IF EXISTS groups_parent_read_children ON public.groups;
CREATE POLICY groups_parent_read_children ON public.groups
  FOR SELECT TO authenticated
  USING (
    has_role('parent') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.group_members gm
      JOIN public.parent_students ps ON ps.student_id = gm.student_id AND ps.parent_id = (SELECT auth.uid())
      WHERE gm.group_id = groups.id
    )
  );

-- E. Video Progress
DROP POLICY IF EXISTS vp_student_own_all ON public.video_progress;
CREATE POLICY vp_student_own_all ON public.video_progress
  FOR ALL TO authenticated
  USING (student_id = (SELECT auth.uid()) AND tenant_is_active())
  WITH CHECK (student_id = (SELECT auth.uid()) AND tenant_is_active());

DROP POLICY IF EXISTS vp_parent_read_children ON public.video_progress;
CREATE POLICY vp_parent_read_children ON public.video_progress
  FOR SELECT TO authenticated
  USING (
    has_role('parent') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.parent_students ps 
      WHERE ps.parent_id = (SELECT auth.uid()) AND ps.student_id = video_progress.student_id
    )
  );

-- F. Exam Attempts
DROP POLICY IF EXISTS attempts_student_own ON public.exam_attempts;
CREATE POLICY attempts_student_own ON public.exam_attempts
  FOR SELECT TO authenticated
  USING (student_id = (SELECT auth.uid()) AND tenant_is_active());

DROP POLICY IF EXISTS attempts_parent_read_children ON public.exam_attempts;
CREATE POLICY attempts_parent_read_children ON public.exam_attempts
  FOR SELECT TO authenticated
  USING (
    has_role('parent') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.parent_students ps 
      WHERE ps.parent_id = (SELECT auth.uid()) AND ps.student_id = exam_attempts.student_id
    )
  );

-- G. Exam Answers
DROP POLICY IF EXISTS answers_student_own ON public.exam_answers;
CREATE POLICY answers_student_own ON public.exam_answers
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.exam_attempts a 
      WHERE a.id = exam_answers.attempt_id AND a.student_id = (SELECT auth.uid())
    )
  );

-- H. Attendance
DROP POLICY IF EXISTS attendance_student_read_own ON public.attendance;
CREATE POLICY attendance_student_read_own ON public.attendance
  FOR SELECT TO authenticated
  USING (student_id = (SELECT auth.uid()) AND tenant_is_active());

DROP POLICY IF EXISTS attendance_parent_read_children ON public.attendance;
CREATE POLICY attendance_parent_read_children ON public.attendance
  FOR SELECT TO authenticated
  USING (
    has_role('parent') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.parent_students ps 
      WHERE ps.parent_id = (SELECT auth.uid()) AND ps.student_id = attendance.student_id
    )
  );

-- I. Activity Events
DROP POLICY IF EXISTS activity_user_own ON public.activity_events;
CREATE POLICY activity_user_own ON public.activity_events
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) AND tenant_is_active());

DROP POLICY IF EXISTS activity_parent_read_children ON public.activity_events;
CREATE POLICY activity_parent_read_children ON public.activity_events
  FOR SELECT TO authenticated
  USING (
    has_role('parent') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.parent_students ps 
      WHERE ps.parent_id = (SELECT auth.uid()) AND ps.student_id = activity_events.user_id
    )
  );

-- J. Notification Recipients & Notifications
DROP POLICY IF EXISTS nr_own ON public.notification_recipients;
CREATE POLICY nr_own ON public.notification_recipients
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) AND tenant_is_active());

DROP POLICY IF EXISTS nr_own_update_read ON public.notification_recipients;
CREATE POLICY nr_own_update_read ON public.notification_recipients
  FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()) AND tenant_is_active())
  WITH CHECK (user_id = (SELECT auth.uid()) AND tenant_is_active());

DROP POLICY IF EXISTS notif_recipient_related ON public.notifications;
CREATE POLICY notif_recipient_related ON public.notifications
  FOR SELECT TO authenticated
  USING (
    tenant_is_active() AND (
      created_by = (SELECT auth.uid()) OR EXISTS (
        SELECT 1 FROM public.notification_recipients nr
        WHERE nr.notification_id = notifications.id AND nr.user_id = (SELECT auth.uid())
      )
    )
  );

-- K. User Devices
DROP POLICY IF EXISTS devices_own_all ON public.user_devices;
CREATE POLICY devices_own_all ON public.user_devices
  FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid()) AND tenant_is_active())
  WITH CHECK (user_id = (SELECT auth.uid()) AND tenant_is_active());

-- L. Student Mistakes
DROP POLICY IF EXISTS student_mistakes_student_own ON public.student_mistakes;
CREATE POLICY student_mistakes_student_own ON public.student_mistakes
  FOR SELECT TO authenticated
  USING (student_id = (SELECT auth.uid()) AND tenant_is_active());

-- M. Content & Content Groups
DROP POLICY IF EXISTS content_student_read_published ON public.content;
CREATE POLICY content_student_read_published ON public.content
  FOR SELECT TO authenticated
  USING (
    has_role('student') AND tenant_is_active() AND status = 'published' AND tenant_id = my_tenant_id() AND (
      group_id IS NULL OR EXISTS (
        SELECT 1 FROM public.group_members gm
        WHERE gm.student_id = (SELECT auth.uid())
          AND gm.group_id = content.group_id
          AND gm.status = 'active'
          AND (content.published_at IS NULL OR gm.joined_at <= content.published_at OR (
            SELECT g.previous_content_access FROM public.groups g WHERE g.id = content.group_id
          ) = 'allow')
      ) OR EXISTS (
        SELECT 1 FROM public.content_groups cg
        JOIN public.group_members gm ON gm.group_id = cg.group_id
        WHERE cg.content_id = content.id
          AND gm.student_id = (SELECT auth.uid())
          AND gm.status = 'active'
          AND (content.published_at IS NULL OR gm.joined_at <= content.published_at OR (
            SELECT g.previous_content_access FROM public.groups g WHERE g.id = cg.group_id
          ) = 'allow')
      )
    )
  );

DROP POLICY IF EXISTS content_parent_read_children ON public.content;
CREATE POLICY content_parent_read_children ON public.content
  FOR SELECT TO authenticated
  USING (
    has_role('parent') AND tenant_is_active() AND status = 'published' AND EXISTS (
      SELECT 1 FROM public.group_members gm
      JOIN public.parent_students ps ON ps.student_id = gm.student_id AND ps.parent_id = (SELECT auth.uid())
      WHERE gm.group_id = content.group_id
    )
  );

-- N. Exams
DROP POLICY IF EXISTS exams_student_read_published ON public.exams;
CREATE POLICY exams_student_read_published ON public.exams
  FOR SELECT TO authenticated
  USING (
    has_role('student') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.content c
      WHERE c.id = exams.content_id AND c.status = 'published' AND c.tenant_id = my_tenant_id() AND (
        c.group_id IS NULL OR EXISTS (
          SELECT 1 FROM public.group_members gm
          WHERE gm.student_id = (SELECT auth.uid())
            AND gm.group_id = c.group_id
            AND gm.status = 'active'
            AND (c.published_at IS NULL OR gm.joined_at <= c.published_at OR (
              SELECT g.previous_content_access FROM public.groups g WHERE g.id = c.group_id
            ) = 'allow')
        ) OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          JOIN public.group_members gm ON gm.group_id = cg.group_id
          WHERE (cg.content_id = c.id OR cg.associated_exam_id = exams.id)
            AND gm.student_id = (SELECT auth.uid())
            AND gm.status = 'active'
            AND (c.published_at IS NULL OR gm.joined_at <= c.published_at OR (
              SELECT g.previous_content_access FROM public.groups g WHERE g.id = cg.group_id
            ) = 'allow')
        )
      )
    )
  );

DROP POLICY IF EXISTS exams_parent_read_children ON public.exams;
CREATE POLICY exams_parent_read_children ON public.exams
  FOR SELECT TO authenticated
  USING (
    has_role('parent') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.content c
      JOIN public.group_members gm ON gm.group_id = c.group_id
      JOIN public.parent_students ps ON ps.student_id = gm.student_id AND ps.parent_id = (SELECT auth.uid())
      WHERE c.id = exams.content_id
    )
  );

-- O. Videos
DROP POLICY IF EXISTS videos_student_read_ready ON public.videos;
CREATE POLICY videos_student_read_ready ON public.videos
  FOR SELECT TO authenticated
  USING (
    has_role('student') AND tenant_is_active() AND status = 'ready' AND EXISTS (
      SELECT 1 FROM public.content c
      WHERE c.id = videos.content_id AND c.status = 'published' AND c.tenant_id = my_tenant_id() AND (
        c.group_id IS NULL OR EXISTS (
          SELECT 1 FROM public.group_members gm
          WHERE gm.student_id = (SELECT auth.uid())
            AND gm.group_id = c.group_id
            AND gm.status = 'active'
            AND (c.published_at IS NULL OR gm.joined_at <= c.published_at OR (
              SELECT g.previous_content_access FROM public.groups g WHERE g.id = c.group_id
            ) = 'allow')
        ) OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          JOIN public.group_members gm ON gm.group_id = cg.group_id
          WHERE cg.content_id = c.id
            AND gm.student_id = (SELECT auth.uid())
            AND gm.status = 'active'
            AND (c.published_at IS NULL OR gm.joined_at <= c.published_at OR (
              SELECT g.previous_content_access FROM public.groups g WHERE g.id = cg.group_id
            ) = 'allow')
        )
      )
    )
  );

-- P. Assignments & Submissions
DROP POLICY IF EXISTS assignments_student_read_group ON public.assignments;
CREATE POLICY assignments_student_read_group ON public.assignments
  FOR SELECT TO authenticated
  USING (
    has_role('student') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.content c
      WHERE c.id = assignments.content_id AND c.status = 'published' AND EXISTS (
        SELECT 1 FROM public.group_members gm
        WHERE gm.student_id = (SELECT auth.uid()) AND gm.group_id = c.group_id
      )
    )
  );

DROP POLICY IF EXISTS assignments_parent_read_children ON public.assignments;
CREATE POLICY assignments_parent_read_children ON public.assignments
  FOR SELECT TO authenticated
  USING (
    has_role('parent') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.content c
      JOIN public.group_members gm ON gm.group_id = c.group_id
      JOIN public.parent_students ps ON ps.student_id = gm.student_id AND ps.parent_id = (SELECT auth.uid())
      WHERE c.id = assignments.content_id
    )
  );

DROP POLICY IF EXISTS subs_student_own_all ON public.assignment_submissions;
CREATE POLICY subs_student_own_all ON public.assignment_submissions
  FOR ALL TO authenticated
  USING (student_id = (SELECT auth.uid()) AND tenant_is_active())
  WITH CHECK (student_id = (SELECT auth.uid()) AND tenant_is_active());

DROP POLICY IF EXISTS subs_parent_read_children ON public.assignment_submissions;
CREATE POLICY subs_parent_read_children ON public.assignment_submissions
  FOR SELECT TO authenticated
  USING (
    has_role('parent') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.parent_students ps 
      WHERE ps.parent_id = (SELECT auth.uid()) AND ps.student_id = assignment_submissions.student_id
    )
  );

DROP POLICY IF EXISTS subfiles_student_own ON public.submission_files;
CREATE POLICY subfiles_student_own ON public.submission_files
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.assignment_submissions s 
      WHERE s.id = submission_files.submission_id AND s.student_id = (SELECT auth.uid())
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.assignment_submissions s 
      WHERE s.id = submission_files.submission_id AND s.student_id = (SELECT auth.uid())
    )
  );

-- Q. Files
DROP POLICY IF EXISTS files_student_read_authorized ON public.files;
CREATE POLICY files_student_read_authorized ON public.files
  FOR SELECT TO authenticated
  USING (
    has_role('student') AND tenant_is_active() AND EXISTS (
      SELECT 1 FROM public.content c
      WHERE c.id = files.content_id AND c.status = 'published' AND c.tenant_id = my_tenant_id() AND (
        c.group_id IS NULL OR EXISTS (
          SELECT 1 FROM public.group_members gm
          WHERE gm.student_id = (SELECT auth.uid())
            AND gm.group_id = c.group_id
            AND gm.status = 'active'
        ) OR EXISTS (
          SELECT 1 FROM public.content_groups cg
          JOIN public.group_members gm ON gm.group_id = cg.group_id
          WHERE cg.content_id = c.id
            AND gm.student_id = (SELECT auth.uid())
            AND gm.status = 'active'
        )
      )
    )
  );

-- R. Notifications
DROP POLICY IF EXISTS notif_recipient_related ON public.notifications;
CREATE POLICY notif_recipient_related ON public.notifications
  FOR SELECT TO authenticated
  USING (tenant_is_active() AND user_has_notification(id, (SELECT auth.uid())));

