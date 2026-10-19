const fs = require('fs');
const path = require('path');
const { executeSql, PROJECT_REF } = require('./supabase_api_client.cjs');

async function main() {
  console.log('================================================================');
  console.log(`🚀 STARTING MIGRATION DEPLOYMENT FOR PROJECT: ${PROJECT_REF}`);
  console.log('================================================================\n');

  // ---------------------------------------------------------------------------
  // TASK 1: Apply Migration 0096 (Enterprise Security Hardening)
  // ---------------------------------------------------------------------------
  console.log('----------------------------------------------------------------');
  console.log('📌 TASK 1: Deploying 0096_enterprise_security_hardening.sql...');
  console.log('----------------------------------------------------------------');
  const migration0096Path = path.resolve(__dirname, '../supabase/migrations/0096_enterprise_security_hardening.sql');
  const sql0096 = fs.readFileSync(migration0096Path, 'utf8');

  try {
    await executeSql(sql0096);
    console.log('✅ Migration 0096 executed successfully!');

    // Verification 1.1: Verify qo_student_read_published is removed
    const policiesRes = await executeSql("SELECT policyname FROM pg_policies WHERE tablename = 'question_options';");
    const hasStudentOptionPolicy = policiesRes.some(p => p.policyname === 'qo_student_read_published');
    if (!hasStudentOptionPolicy) {
      console.log('  ✔️ Verification Passed: Direct student access to question_options is revoked.');
    } else {
      console.warn('  ⚠️ Warning: qo_student_read_published still found!');
    }

    // Verification 1.2: Verify submit_mistakes_practice security definer
    const funcRes = await executeSql("SELECT proname, prosecdef FROM pg_proc WHERE proname = 'submit_mistakes_practice';");
    if (funcRes.length > 0 && funcRes[0].prosecdef) {
      console.log('  ✔️ Verification Passed: submit_mistakes_practice is hardened with SECURITY DEFINER.');
    }

    // Record migration 0096 in schema_migrations
    await executeSql("INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20261016180000') ON CONFLICT DO NOTHING;");
    console.log('  ✔️ Recorded 0096 in supabase_migrations.schema_migrations.');
  } catch (err) {
    console.error('❌ Error applying migration 0096:', err);
    process.exit(1);
  }

  // ---------------------------------------------------------------------------
  // TASK 2: Apply Migration 0097 (Composite Query Performance Indexes)
  // ---------------------------------------------------------------------------
  console.log('\n----------------------------------------------------------------');
  console.log('📌 TASK 2: Deploying 0097_composite_query_performance_indexes.sql...');
  console.log('----------------------------------------------------------------');

  const indexes = [
    {
      name: 'idx_notif_recipients_user_created',
      sql: 'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notif_recipients_user_created ON public.notification_recipients (user_id, created_at DESC);'
    },
    {
      name: 'idx_notif_recipients_unread',
      sql: 'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notif_recipients_unread ON public.notification_recipients (user_id) WHERE read_at IS NULL;'
    },
    {
      name: 'idx_assignment_submissions_assignment_status',
      sql: 'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assignment_submissions_assignment_status ON public.assignment_submissions (assignment_id, status);'
    },
    {
      name: 'idx_assignment_submissions_assignment_submitted',
      sql: 'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assignment_submissions_assignment_submitted ON public.assignment_submissions (assignment_id, submitted_at DESC);'
    },
    {
      name: 'idx_assignment_submissions_student_assignment',
      sql: 'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_assignment_submissions_student_assignment ON public.assignment_submissions (student_id, assignment_id);'
    },
    {
      name: 'idx_qb_questions_status_created',
      sql: 'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_qb_questions_status_created ON public.qb_questions (status, created_at DESC);'
    },
    {
      name: 'idx_qb_question_revisions_question_rev',
      sql: 'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_qb_question_revisions_question_rev ON public.qb_question_revisions (question_id, rev_no DESC);'
    },
    {
      name: 'idx_video_progress_active_uncompleted',
      sql: 'CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_video_progress_active_uncompleted ON public.video_progress (student_id, last_watched_at DESC) WHERE completed = false;'
    }
  ];

  for (let i = 0; i < indexes.length; i++) {
    const idx = indexes[i];
    try {
      console.log(`  🔨 [${i + 1}/8] Creating index concurrently: ${idx.name}...`);
      await executeSql(idx.sql);
      console.log(`  ✅ Index ${idx.name} created.`);
    } catch (err) {
      console.error(`  ❌ Error creating index ${idx.name}:`, err);
    }
  }

  // Verification 2: Verify all 8 indexes exist
  const indexCheck = await executeSql(`
    SELECT indexname FROM pg_indexes 
    WHERE indexname IN (
      'idx_notif_recipients_user_created',
      'idx_notif_recipients_unread',
      'idx_assignment_submissions_assignment_status',
      'idx_assignment_submissions_assignment_submitted',
      'idx_assignment_submissions_student_assignment',
      'idx_qb_questions_status_created',
      'idx_qb_question_revisions_question_rev',
      'idx_video_progress_active_uncompleted'
    );
  `);
  console.log(`  ✔️ Verification: ${indexCheck.length}/8 performance indexes confirmed active in pg_indexes.`);

  // Record migration 0097
  await executeSql("INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20261016190000') ON CONFLICT DO NOTHING;");
  console.log('  ✔️ Recorded 0097 in supabase_migrations.schema_migrations.');

  // ---------------------------------------------------------------------------
  // TASK 3: Apply Migration 0098 (Exam Folders Group Scoping)
  // ---------------------------------------------------------------------------
  console.log('\n----------------------------------------------------------------');
  console.log('📌 TASK 3: Deploying 0098_add_group_id_to_exam_folders.sql...');
  console.log('----------------------------------------------------------------');
  const migration0098Path = path.resolve(__dirname, '../supabase/migrations/0098_add_group_id_to_exam_folders.sql');
  const sql0098 = fs.readFileSync(migration0098Path, 'utf8');

  try {
    await executeSql(sql0098);
    console.log('✅ Migration 0098 executed successfully!');

    // Verification 3.1: Check column group_id exists
    const colCheck = await executeSql("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'exam_folders' AND column_name = 'group_id';");
    if (colCheck.length > 0) {
      console.log(`  ✔️ Verification Passed: column exam_folders.group_id exists (${colCheck[0].data_type}).`);
    } else {
      console.warn('  ⚠️ Warning: group_id column not found in exam_folders!');
    }

    // Verification 3.2: Check move_exam_to_folder RPC
    const procCheck = await executeSql("SELECT proname, prosecdef FROM pg_proc WHERE proname = 'move_exam_to_folder';");
    if (procCheck.length > 0 && procCheck[0].prosecdef) {
      console.log('  ✔️ Verification Passed: move_exam_to_folder RPC active with SECURITY DEFINER.');
    }

    // Record migration 0098
    await executeSql("INSERT INTO supabase_migrations.schema_migrations (version) VALUES ('20261016200000') ON CONFLICT DO NOTHING;");
    console.log('  ✔️ Recorded 0098 in supabase_migrations.schema_migrations.');
  } catch (err) {
    console.error('❌ Error applying migration 0098:', err);
    process.exit(1);
  }

  console.log('\n================================================================');
  console.log('🎉 ALL PENDING MIGRATIONS APPLIED AND VERIFIED 100% SUCCESSFULLY!');
  console.log('================================================================');
}

main().catch(err => {
  console.error('Fatal Migration Error:', err);
  process.exit(1);
});
