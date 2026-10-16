-- ============================================================================
-- Migration: 0097_composite_query_performance_indexes.sql
-- Description: Targeted composite, covering, and partial indexes for high-frequency
--              queries across Notifications, Assignments, Question Bank, and
--              Student Dashboard Video Progress.
-- Impact: Eliminates sequential scans & in-memory sorts on large tables.
-- ============================================================================

-- 1. Notification Recipients
-- Satisfies: .from('notification_recipients').eq('user_id', ...).order('created_at', ascending: false).range(...)
CREATE INDEX IF NOT EXISTS idx_notif_recipients_user_created 
  ON public.notification_recipients (user_id, created_at DESC);

-- Satisfies: .from('notification_recipients').eq('user_id', ...).isFilter('read_at', null)
-- Partial index: Extremely compact and fast for unread counter and mark-all-read queries
CREATE INDEX IF NOT EXISTS idx_notif_recipients_unread 
  ON public.notification_recipients (user_id) 
  WHERE read_at IS NULL;

-- 2. Assignment Submissions
-- Satisfies batch teacher query: .inFilter('assignment_id', assignmentIds).select('assignment_id, status')
CREATE INDEX IF NOT EXISTS idx_assignment_submissions_assignment_status 
  ON public.assignment_submissions (assignment_id, status);

-- Satisfies: .eq('assignment_id', assignmentId).order('submitted_at', ascending: false)
CREATE INDEX IF NOT EXISTS idx_assignment_submissions_assignment_submitted 
  ON public.assignment_submissions (assignment_id, submitted_at DESC);

-- Satisfies student query: .eq('student_id', studentId).inFilter('assignment_id', assignmentIds)
CREATE INDEX IF NOT EXISTS idx_assignment_submissions_student_assignment 
  ON public.assignment_submissions (student_id, assignment_id);

-- 3. Question Bank
-- Satisfies: .eq('status', statusFilter).order('created_at', ascending: false)
CREATE INDEX IF NOT EXISTS idx_qb_questions_status_created 
  ON public.qb_questions (status, created_at DESC);

-- Satisfies: .eq('question_id', questionId).order('rev_no', ascending: false).limit(1)
CREATE INDEX IF NOT EXISTS idx_qb_question_revisions_question_rev 
  ON public.qb_question_revisions (question_id, rev_no DESC);

-- 4. Video Progress (Student Continue Watching on Dashboard)
-- Satisfies: .eq('student_id', studentId).eq('completed', false).gt('progress_seconds', 0).order('last_watched_at', ascending: false)
CREATE INDEX IF NOT EXISTS idx_video_progress_active_uncompleted 
  ON public.video_progress (student_id, last_watched_at DESC) 
  WHERE completed = false;
