const fs = require('fs');
const path = require('path');

const routerPath = path.join(__dirname, '..', 'lib', 'core', 'router', 'app_router.dart');
let content = fs.readFileSync(routerPath, 'utf8');

// 1. Remove `deferred as [lib_name];` and clean comments
content = content.replace(/\s+deferred as \w+;/g, ';');
content = content.replace("import '../widgets/deferred_widget.dart';\n", "");

// 2. Remove all library prefixes like `login_lib.`, `teacher_dash_lib.`, etc.
const prefixes = [
  'login_lib', 'register_lib', 'pending_lib', 'suspended_lib',
  'splash_lib', 'teacher_dash_lib', 'student_dash_lib', 'parent_dash_lib',
  'groups_list_lib', 'group_detail_lib', 'teacher_attendance_lib', 'student_attendance_lib',
  'students_list_lib', 'pending_students_lib', 'student_360_lib', 'assign_groups_lib',
  'teacher_content_lib', 'teacher_lesson_lib', 'teacher_materials_lib', 'student_content_lib',
  'course_progress_lib', 'teacher_assignments_lib', 'student_assignments_lib',
  'teacher_exams_lib', 'student_exams_lib', 'student_mistakes_lib', 'mistakes_practice_lib',
  'saved_questions_lib', 'anki_drill_lib', 'exam_dispatch_lib', 'teacher_videos_lib',
  'video_player_lib', 'notifications_lib', 'announcement_lib', 'onboarding_lib',
  'teacher_settings_lib', 'student_profile_lib', 'question_bank_lib', 'manual_question_lib',
  'doc_questions_lib', 'review_console_lib'
];

for (const p of prefixes) {
  const regex = new RegExp(`\\b${p}\\.`, 'g');
  content = content.replace(regex, '');
}

// 3. Remove preloadTeacherBundles and preloadStudentBundles
const preloadIdx = content.indexOf('/// Preloads the most frequently visited teacher bundles');
if (preloadIdx !== -1) {
  content = content.substring(0, preloadIdx).trimRight() + '\n}\n';
}

fs.writeFileSync(routerPath, content, 'utf8');
console.log('Successfully updated imports and removed preloader methods.');
