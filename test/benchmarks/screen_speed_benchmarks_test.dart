import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';

// Auth
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/auth/domain/repositories/auth_repository.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_state.dart';

// Notifications
import 'package:edu_saas/features/notifications/domain/entities/notification_entity.dart';
import 'package:edu_saas/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:edu_saas/features/notifications/presentation/cubit/notifications_cubit.dart';

// Dashboard
import 'package:edu_saas/features/dashboard/domain/entities/student_dashboard_stats.dart';
import 'package:edu_saas/features/dashboard/domain/repositories/student_dashboard_repository.dart';
import 'package:edu_saas/features/dashboard/presentation/cubit/student_dashboard_cubit.dart';
import 'package:edu_saas/features/dashboard/presentation/pages/student_dashboard_page.dart';
import 'package:edu_saas/features/dashboard/presentation/pages/teacher_dashboard_page.dart';

// Groups
import 'package:edu_saas/features/groups/domain/entities/group_entity.dart';
import 'package:edu_saas/features/groups/domain/entities/group_member_entity.dart';
import 'package:edu_saas/features/groups/domain/repositories/groups_repository.dart';
import 'package:edu_saas/features/groups/presentation/cubit/groups_cubit.dart';

// Students
import 'package:edu_saas/features/students/domain/entities/student_360_entity.dart';
import 'package:edu_saas/features/students/domain/entities/student_academic_report_entity.dart';
import 'package:edu_saas/features/students/domain/entities/student_entity.dart';
import 'package:edu_saas/features/students/domain/repositories/students_repository.dart';
import 'package:edu_saas/features/students/presentation/cubit/students_cubit.dart';
import 'package:edu_saas/features/students/presentation/pages/student_360_page.dart';

// Exams
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_folder_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_parent_dispatch_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:edu_saas/features/exams/presentation/pages/student_exams_page.dart';

// Videos
import 'package:edu_saas/features/videos/domain/entities/library_video_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_folder_entity.dart';
import 'package:edu_saas/features/videos/domain/repositories/video_bank_repository.dart';
import 'package:edu_saas/features/videos/presentation/cubit/video_bank_cubit.dart';
import 'package:edu_saas/features/content/presentation/pages/teacher_video_bank_page.dart';

// ---------------------------------------------------------------------------
// Performance Benchmark Result Model & Logger
// ---------------------------------------------------------------------------
class ScreenBenchmarkMetric {
  final String screenName;
  final int fetchDurationMs;
  final int firstFrameRenderMs;
  final int interactiveSettleMs;
  final int totalEndToEndMs;
  final bool withinPerformanceBudget;
  final String details;

  const ScreenBenchmarkMetric({
    required this.screenName,
    required this.fetchDurationMs,
    required this.firstFrameRenderMs,
    required this.interactiveSettleMs,
    required this.totalEndToEndMs,
    required this.withinPerformanceBudget,
    this.details = '',
  });

  @override
  String toString() {
    return '⏱️ [PERF_BENCHMARK] $screenName | Fetch: ${fetchDurationMs}ms | First Frame: ${firstFrameRenderMs}ms | Settle: ${interactiveSettleMs}ms | Total: ${totalEndToEndMs}ms | Status: ${withinPerformanceBudget ? "✅ OPTIMAL" : "⚠️ SLOW"}';
  }
}

// ---------------------------------------------------------------------------
// Realistic Mock Repositories
// ---------------------------------------------------------------------------
class _BenchAuthRepo implements AuthRepository {
  final UserEntity user;
  _BenchAuthRepo(this.user);

  @override
  Future<Result<UserEntity?>> getCurrentUser() async => Success(user);
  @override
  Future<Result<UserEntity>> signInWithEmail({required String email, required String password}) async => Success(user);
  @override
  Future<Result<UserEntity>> signUpStudent({required String fullName, required String email, required String password, required String phone, String? parentPhone, required String tenantId}) async => Success(user);
  @override
  Future<Result<void>> signOut() async => const Success(null);
  @override
  Future<Result<void>> resetPasswordForEmail(String email) async => const Success(null);
}

class _BenchNotificationsRepo implements NotificationsRepository {
  _BenchNotificationsRepo();

  @override
  Future<Result<List<NotificationEntity>>> getMyNotifications({int limit = 50, int offset = 0}) async {
    return Success(List.generate(
      15,
      (i) => NotificationEntity(
        id: 'notif-$i',
        recipientId: 'recip-$i',
        tenantId: 'tenant-1',
        title: 'إشعار أكاديمي رقم $i',
        body: 'تم رصد درجات امتحان الجبر بنجاح للطالب',
        type: NotificationType.examResult,
        createdAt: DateTime.now().subtract(Duration(minutes: i * 15)),
        readAt: i > 3 ? DateTime.now() : null,
      ),
    ));
  }

  @override
  Future<Result<int>> getUnreadCount() async => const Success(3);
  @override
  Future<Result<void>> markAsRead(String recipientId) async => const Success(null);
  @override
  Future<Result<void>> markAllAsRead() async => const Success(null);
  @override
  Future<Result<void>> sendAnnouncement({required String title, required String body, String? groupId}) async => const Success(null);
  @override
  Future<Result<void>> dispatchNotification({required String title, required String body, required NotificationType type, String? groupId, String? userId, Map<String, dynamic>? data}) async => const Success(null);
}

class _BenchStudentDashboardRepo implements StudentDashboardRepository {
  _BenchStudentDashboardRepo();

  @override
  Future<Result<StudentDashboardStats>> getStudentDashboardStats(String studentId, {bool forceRefresh = false}) async {
    return Success(
      StudentDashboardStats(
        attendancePercentage: 96,
        examAverage: 91.5,
        assignmentsSubmitted: 14,
        videoCompletionPercentage: 88,
        activeGroupName: 'SAT Math Advanced Masters',
        activeGroupLevel: 'SAT Exam Prep',
        continueLearningItem: const ContinueLearningItem(
          videoId: 'vid-sat-1',
          contentId: 'cnt-sat-1',
          title: 'Quadratic Equations & Complex Roots Deep-Dive',
          groupName: 'SAT Math Advanced Masters',
          progressSeconds: 1450,
          durationSeconds: 1800,
          percentage: 80.5,
        ),
        urgentTasks: [
          UrgentTaskItem(
            id: 'task-1',
            title: 'SAT Practice Test 4 — Math Module 1',
            groupName: 'SAT Math Advanced Masters',
            taskType: 'exam',
            status: 'pending',
            dueAt: DateTime.now().add(const Duration(hours: 18)),
            maxScore: 100,
          ),
          UrgentTaskItem(
            id: 'task-2',
            title: 'Homework 08: Radical Functions Equations',
            groupName: 'SAT Math Advanced Masters',
            taskType: 'assignment',
            status: 'pending',
            dueAt: DateTime.now().add(const Duration(days: 2)),
          ),
        ],
      ),
    );
  }
}

class _BenchGroupsRepo implements GroupsRepository {
  _BenchGroupsRepo();

  @override
  Future<Result<List<GroupEntity>>> getGroups() async {
    return Success([
      GroupEntity(
        id: 'group-sat',
        tenantId: 'tenant-1',
        name: 'SAT Math Advanced Masters',
        level: 'SAT',
        membersCount: 38,
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        updatedAt: DateTime.now(),
      ),
      GroupEntity(
        id: 'group-est',
        tenantId: 'tenant-1',
        name: 'EST I & II Math Intensive',
        level: 'EST',
        membersCount: 24,
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now(),
      ),
      GroupEntity(
        id: 'group-act',
        tenantId: 'tenant-1',
        name: 'ACT Math Speed & Strategy',
        level: 'ACT',
        membersCount: 19,
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        updatedAt: DateTime.now(),
      ),
    ]);
  }

  @override
  Future<Result<GroupEntity>> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  }) async => Success(GroupEntity(
    id: 'grp-new',
    tenantId: 'tenant-1',
    name: name,
    level: level,
    description: description,
    previousContentAccess: previousContentAccess,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ));

  @override
  Future<Result<GroupEntity>> updateGroup({
    required String id,
    String? name,
    String? level,
    String? description,
    String? previousContentAccess,
    String? status,
    bool? enforceSequentialLearning,
    int? defaultPassingScore,
  }) async => Success(GroupEntity(
    id: id,
    tenantId: 'tenant-1',
    name: name ?? 'Updated Group',
    level: level ?? 'SAT',
    description: description,
    previousContentAccess: previousContentAccess ?? 'deny',
    status: status ?? 'active',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ));

  @override
  Future<Result<List<GroupMemberEntity>>> getGroupMembers(
    String groupId, {
    int page = 0,
    int pageSize = 25,
  }) async => const Success([]);

  @override
  Future<Result<GroupMemberEntity>> addMemberToGroup({
    required String groupId,
    required String studentId,
  }) async => Success(GroupMemberEntity(
    id: 'gm-1',
    groupId: groupId,
    studentId: studentId,
    studentName: 'طالب اختباري',
    joinedAt: DateTime.now(),
  ));

  @override
  Future<Result<void>> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  }) async => const Success(null);

  @override
  Future<Result<void>> deleteGroup(String groupId) async => const Success(null);
}

class _BenchStudentsRepo implements StudentsRepository {
  _BenchStudentsRepo();

  @override
  Future<Result<List<StudentEntity>>> getStudents({String? status, String? searchQuery, int page = 0, int pageSize = 25}) async {
    return Success(List.generate(
      50,
      (i) => StudentEntity(
        id: 'student-$i',
        tenantId: 'tenant-1',
        fullName: 'طالب اختباري رقم ${i + 1}',
        email: 'student_$i@testacademy.com',
        phone: '010123456$i',
        parentPhone: '012123456$i',
        status: 'active',
        createdAt: DateTime.now().subtract(Duration(days: i * 2)),
      ),
    ));
  }

  @override
  Future<Result<List<StudentEntity>>> getPendingStudents({int page = 0, int pageSize = 20}) async => const Success([]);

  @override
  Future<Result<StudentEntity>> changeStudentStatus({required String studentId, required String action}) async => Success(StudentEntity(
    id: studentId,
    tenantId: 'tenant-1',
    fullName: 'Student $studentId',
    email: 's@test.com',
    status: action == 'approve' ? 'active' : 'suspended',
    createdAt: DateTime.now(),
  ));

  @override
  Future<Result<Student360Entity>> getStudent360(String studentId) async {
    return Success(Student360Entity(
      studentId: studentId,
      attendancePercentage: 93,
      assignmentsSubmitted: 15,
      assignmentsReviewed: 15,
      examAverage: 92.4,
      videoCompletionPercentage: 87.0,
      todayActiveSeconds: 4200,
      todayIdleSeconds: 300,
      firstSeenToday: DateTime.now().subtract(const Duration(hours: 3)),
      lastSeenToday: DateTime.now().subtract(const Duration(minutes: 10)),
      totalActiveSeconds7d: 36000,
      totalIdleSeconds7d: 2400,
      groups: [
        StudentGroupInfo(
          groupId: 'group-sat',
          groupName: 'SAT Math Advanced Masters',
          groupLevel: 'SAT Prep',
          joinedAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ],
      recentActivities: List.generate(
        10,
        (i) => StudentActivityItem(
          id: 'act-$i',
          eventType: i % 2 == 0 ? 'exam_submitted' : 'video_completed',
          createdAt: DateTime.now().subtract(Duration(days: i)),
          contentTitle: i % 2 == 0 ? 'Digital SAT Module ${i + 1}' : 'Lesson $i: Calculus Fundamentals',
          groupName: 'SAT Math Advanced Masters',
          metadata: {'percentage': 85 + (i % 15)},
        ),
      ),
      videoInsights: List.generate(
        8,
        (i) => StudentVideoInsight(
          videoId: 'vid-$i',
          videoTitle: 'Lecture $i: Advanced Trigonometry',
          durationSeconds: 1500,
          progressSeconds: 1450,
          actualWatchSeconds: 1400,
          percentage: 96.6,
          completed: true,
          isSkipped: false,
          lastWatchedAt: DateTime.now().subtract(Duration(days: i)),
        ),
      ),
    ));
  }

  @override
  Future<Result<StudentEntity>> getStudent(String studentId) async => Success(StudentEntity(
    id: studentId,
    tenantId: 'tenant-1',
    fullName: 'أحمد محمود الشرقاوي',
    email: 'ahmed.sharkawy@sat.com',
    phone: '01099887766',
    parentPhone: '01299887766',
    status: 'active',
    createdAt: DateTime.now(),
  ));

  @override
  Future<Result<void>> assignStudentToGroup({
    required String studentId,
    required String groupId,
    required bool add,
  }) async => const Success(null);

  @override
  Future<Result<List<StudentGroupInfo>>> getAvailableGroupsForStudent(String studentId) async => const Success([]);

  @override
  Future<Result<void>> deleteStudent(String studentId) async => const Success(null);

  @override
  Future<Result<StudentAcademicReportEntity>> getStudentAcademicReport(String studentId, {int? days}) async => throw UnimplementedError();
}

class _BenchExamsRepo implements ExamsRepository {
  _BenchExamsRepo();

  @override
  Future<Result<List<ExamEntity>>> getStudentExams({int page = 0, int pageSize = 15}) async {
    return Success(List.generate(
      20,
      (i) => ExamEntity(
        id: 'exam-sat-$i',
        contentId: 'cnt-exam-$i',
        tenantId: 'tenant-1',
        groupId: 'group-sat',
        title: 'SAT Practice Exam ${i + 1}: Passport to Advanced Math',
        durationMinutes: 45,
        maxScore: 100,
        passingScore: 70,
        shuffleQuestions: true,
        showResult: true,
        allowRetake: i % 2 == 0,
        folderName: 'Digital SAT Tests 2026',
        folderColor: '#5B4FE0',
        createdAt: DateTime.now().subtract(Duration(days: i * 3)),
        updatedAt: DateTime.now(),
        activeVersion: ExamVersionEntity(
          id: 'v-$i',
          examId: 'exam-sat-$i',
          versionNumber: 1,
          status: ExamStatus.published,
          createdAt: DateTime.now(),
          questions: List.generate(
            10,
            (q) => ExamQuestionEntity(
              id: 'q-$i-$q',
              examVersionId: 'v-$i',
              questionText: 'If f(x) = 2x² - 5x + c has a root at x = 3, what is the value of c?',
              questionType: QuestionType.multipleChoice,
              points: 10,
              sortOrder: q + 1,
              options: [
                QuestionOptionEntity(id: 'opt-$q-1', questionId: 'q-$i-$q', optionText: '-3', sortOrder: 1),
                QuestionOptionEntity(id: 'opt-$q-2', questionId: 'q-$i-$q', optionText: '3', sortOrder: 2),
                QuestionOptionEntity(id: 'opt-$q-3', questionId: 'q-$i-$q', optionText: '-9', sortOrder: 3),
                QuestionOptionEntity(id: 'opt-$q-4', questionId: 'q-$i-$q', optionText: '9', sortOrder: 4),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  @override
  Future<Result<List<ExamEntity>>> getGroupExams(String groupId, {int page = 0, int pageSize = 15}) async => getStudentExams();
  @override
  Future<Result<ExamEntity>> getExamDetails(String examId) async => (await getStudentExams()).dataOrNull!.first.let((e) => Success(e));
  @override
  Future<Result<ExamEntity>> createExam({String? groupId, required String title, int durationMinutes = 60, int maxScore = 100, int? passingScore, bool shuffleQuestions = false, bool showResult = true, bool allowRetake = false, DateTime? startAt, DateTime? endAt, bool isPublished = false, String? pdfFileId, required List<ExamQuestionEntity> initialQuestions}) async => throw UnimplementedError();
  @override
  Future<Result<ExamEntity>> updateExam({required String examId, required String title, int? durationMinutes, int? maxScore, int? passingScore, bool? shuffleQuestions, bool? showResult, bool? allowRetake, DateTime? startAt, DateTime? endAt, bool? isPublished, String? pdfFileId, bool clearPdfFile = false}) async => throw UnimplementedError();
  @override
  Future<Result<ExamEntity>> updateDraftExamQuestions({required String examId, required String title, int? durationMinutes, int? maxScore, int? passingScore, bool? shuffleQuestions, bool? showResult, bool? allowRetake, DateTime? startAt, DateTime? endAt, bool? isPublished, String? pdfFileId, bool clearPdfFile = false, required List<ExamQuestionEntity> questions}) async => throw UnimplementedError();
  @override
  Future<Result<ExamVersionEntity>> publishExamVersion(String versionId) async => throw UnimplementedError();
  @override
  Future<Result<void>> unpublishExamVersion({required String examId, required String versionId}) async => const Success(null);
  @override
  Future<Result<ExamVersionEntity>> createNewExamVersion(String examId) async => throw UnimplementedError();
  @override
  Future<Result<ExamAttemptEntity>> startExam(String examId) async => throw UnimplementedError();
  @override
  Future<Result<ExamAttemptEntity>> submitExam({required String attemptId, required Map<String, String> answers, ExamSubmissionReason reason = ExamSubmissionReason.studentSubmitted}) async => throw UnimplementedError();
  @override
  Future<Result<void>> syncExamAnswers({required String attemptId, required Map<String, String> answers}) async => const Success(null);
  @override
  Future<Result<ExamAttemptEntity>> getAttemptDetails(String attemptId) async => throw UnimplementedError();
  @override
  Future<Result<List<ExamAttemptEntity>>> getExamAttempts(String examId, {int page = 0, int pageSize = 50}) async => const Success([]);
  @override
  Future<Result<MistakeSummaryEntity>> getStudentMistakesSummary(String studentId) async => const Success(MistakeSummaryEntity(totalMistakes: 5, unresolvedCount: 3, resolvedCount: 2, sources: []));
  @override
  Future<Result<List<MistakeQuestionEntity>>> getStudentMistakesQuestions(String studentId, {String? examId, bool onlyUnresolved = true}) async => const Success([]);
  @override
  Future<Result<MistakePracticeResultEntity>> submitMistakesPractice(List<Map<String, String>> answers) async => throw UnimplementedError();
  @override
  Future<Result<void>> convertExamType({required String examId, required String contentId, required bool toLectureExam, required String groupId}) async => const Success(null);
  @override
  Future<Result<bool>> deleteExam({required String examId, bool force = false}) async => const Success(true);
  @override
  Future<Result<ExamParentDispatchRosterEntity>> getExamParentDispatchRoster(String examId) async => throw UnimplementedError();
  @override
  Future<Result<bool>> updateStudentParentPhone({required String studentId, required String parentPhone}) async => const Success(true);
  @override
  Future<Result<List<ExamFolderEntity>>> getExamFolders({String? groupId}) async => const Success([]);
  @override
  Future<Result<ExamFolderEntity>> createExamFolder({required String name, String? groupId, String? color, String? icon, String? description}) async => throw UnimplementedError();
  @override
  Future<Result<ExamFolderEntity>> updateExamFolder({required String folderId, required String name, String? color, String? icon, String? description}) async => throw UnimplementedError();
  @override
  Future<Result<bool>> deleteExamFolder(String folderId) async => const Success(true);
  @override
  Future<Result<bool>> moveExamToFolder({required String examId, String? folderId}) async => const Success(true);
  @override
  Future<Result<List<Map<String, dynamic>>>> getGroupLessons(String groupId) async => const Success([]);
  @override
  Future<Result<String>> getSignedPdfUrl(String storagePath) async => const Success('https://storage.supabase.co/file.pdf');
  @override
  Future<Result<void>> linkExamToLesson({required String examId, required String lessonId, required String groupId}) async => const Success(null);
  @override
  Future<Result<void>> unlinkExamFromLesson({required String examId, required String groupId, bool makeGeneralExam = false}) async => const Success(null);
}

class _BenchVideoBankRepo implements VideoBankRepository {
  _BenchVideoBankRepo();

  @override
  Future<Result<List<VideoFolderEntity>>> getFolders({String? parentId}) async => Success([
    VideoFolderEntity(id: 'vf-1', tenantId: 'tenant-1', name: 'Digital SAT 2026 Lectures', color: '#5B4FE0', createdAt: DateTime.now(), updatedAt: DateTime.now()),
    VideoFolderEntity(id: 'vf-2', tenantId: 'tenant-1', name: 'EST Intensive Problem Solving', color: '#00897B', createdAt: DateTime.now(), updatedAt: DateTime.now()),
  ]);

  @override
  Future<Result<List<VideoFolderEntity>>> getAllFolders() async => getFolders();

  @override
  Future<Result<List<LibraryVideoEntity>>> getVideos({String? folderId, String? search, int page = 0, int pageSize = 24}) async {
    return Success(List.generate(
      25,
      (i) => LibraryVideoEntity(
        id: 'vid-bank-$i',
        tenantId: 'tenant-1',
        title: 'Masterclass $i: Polynomials, Rational & Radical Expressions',
        duration: 1800 + (i * 60),
        status: VideoStatus.ready,
        providerVideoId: 'bunny-guid-$i',
        folderId: i % 2 == 0 ? 'vf-1' : 'vf-2',
        createdAt: DateTime.now().subtract(Duration(days: i)),
        updatedAt: DateTime.now(),
      ),
    ));
  }

  @override
  Future<Result<VideoFolderEntity>> createFolder({required String name, String? parentId, String? color}) async => throw UnimplementedError();
  @override
  Future<Result<VideoFolderEntity>> updateFolder({required String id, required String name, String? color}) async => throw UnimplementedError();
  @override
  Future<Result<VideoFolderEntity>> updateFolderColor({required String id, String? color}) async => throw UnimplementedError();
  @override
  Future<Result<void>> deleteFolder(String id) async => const Success(null);
  @override
  Future<Result<LibraryVideoEntity>> updateVideo({required String id, required String title, String? description}) async => throw UnimplementedError();
  @override
  Future<Result<LibraryVideoEntity>> moveVideo({required String id, String? targetFolderId}) async => throw UnimplementedError();
  @override
  Future<Result<void>> deleteVideo(String id) async => const Success(null);
  @override
  Future<Result<LibraryVideoEntity>> syncVideoStatus(String libraryVideoId) async => Success(LibraryVideoEntity(
    id: libraryVideoId,
    tenantId: 'tenant-1',
    title: 'Synced Video',
    status: VideoStatus.ready,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ));
  @override
  Future<Result<String>> getPlaybackUrl(String libraryVideoId) async => const Success('https://video.bunnycdn.com/play');
  @override
  Future<Result<void>> linkToLectureContent({required String libraryVideoId, required String contentId, required String title}) async => const Success(null);
  @override
  Future<Result<LibraryVideoEntity>> getVideoById(String id) async => throw UnimplementedError();
  @override
  Future<Result<LibraryVideoEntity>> uploadVideo({
    required String title,
    String? description,
    String? folderId,
    required List<int> videoBytes,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async => throw UnimplementedError();
  @override
  void cancelActiveUpload() {}
  @override
  Future<Result<Map<String, dynamic>>> assignFolderAsChapter({
    required String folderId,
    required String groupId,
    String? chapterTitle,
  }) async => const Success({'chapter_id': 'chap-1', 'lessons_count': 1});
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) op) => op(this);
}

// ---------------------------------------------------------------------------
// Performance Benchmark Test Suite
// ---------------------------------------------------------------------------
void main() {
  const testStudent = UserEntity(
    id: 'student-bench-01',
    email: 'student.sat@platform.com',
    fullName: 'ياسين أحمد المنسي',
    role: UserRole.student,
    status: UserStatus.active,
    tenantId: 'tenant-1',
  );

  const testTeacher = UserEntity(
    id: 'teacher-bench-01',
    email: 'dr.antounios@platform.com',
    fullName: 'د. أنطونيوس أشرف',
    role: UserRole.teacher,
    status: UserStatus.active,
    tenantId: 'tenant-1',
  );

  final List<ScreenBenchmarkMetric> benchmarkResults = [];

  setUp(() {
    AppCache.clearAll();
  });

  tearDownAll(() {
    // Print comprehensive benchmarking summary
    debugPrint('\n================================================================================');
    debugPrint('📊 PLATFORM END-TO-END SCREEN SPEED & RENDER BENCHMARKS REPORT');
    debugPrint('================================================================================');
    for (final b in benchmarkResults) {
      debugPrint(b.toString());
    }
    debugPrint('================================================================================\n');
  });

  Widget buildBenchmarkApp({
    required Widget child,
    required AuthCubit authCubit,
    required NotificationsCubit notificationsCubit,
    GroupsCubit? groupsCubit,
    StudentsCubit? studentsCubit,
    StudentDashboardCubit? studentDashboardCubit,
    ExamsCubit? examsCubit,
    VideoBankCubit? videoBankCubit,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<NotificationsCubit>.value(value: notificationsCubit),
        if (groupsCubit != null) BlocProvider<GroupsCubit>.value(value: groupsCubit),
        if (studentsCubit != null) BlocProvider<StudentsCubit>.value(value: studentsCubit),
        if (studentDashboardCubit != null) BlocProvider<StudentDashboardCubit>.value(value: studentDashboardCubit),
        if (examsCubit != null) BlocProvider<ExamsCubit>.value(value: examsCubit),
        if (videoBankCubit != null) BlocProvider<VideoBankCubit>.value(value: videoBankCubit),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        locale: const Locale('ar'),
        home: child,
      ),
    );
  }

  group('🚀 [Screen Speed Benchmarks: Fetch-to-Render Latency Under Scale]', () {
    testWidgets(
      'BENCHMARK: StudentDashboardPage cold start vs warm cache Stale-While-Revalidate speedup',
      (tester) async {
        final authCubit = AuthCubit(repository: _BenchAuthRepo(testStudent));
        final notifCubit = NotificationsCubit(repository: _BenchNotificationsRepo());
        final groupsCubit = GroupsCubit(repository: _BenchGroupsRepo());
        final dashCubit = StudentDashboardCubit(repository: _BenchStudentDashboardRepo());

        // Authenticate student
        AppCache.setCurrentUser(testStudent.id);
        authCubit.emit(const AuthAuthenticated(testStudent));

        // Benchmark Cold Start (Fetch -> Render -> Settle)
        final stopwatch = Stopwatch()..start();

        // 1. Data Fetch
        final fetchWatch = Stopwatch()..start();
        await dashCubit.loadDashboardStats(testStudent.id);
        await groupsCubit.loadGroups();
        AppCache.groups.put(AppCache.userKey('groups'), [
          GroupEntity(
            id: 'group-sat',
            tenantId: 'tenant-1',
            name: 'SAT Math Advanced Masters',
            level: 'SAT',
            membersCount: 38,
            createdAt: DateTime.now().subtract(const Duration(days: 90)),
            updatedAt: DateTime.now(),
          ),
        ]);
        fetchWatch.stop();

        // 2. First Frame Render
        final renderWatch = Stopwatch()..start();
        await tester.pumpWidget(
          buildBenchmarkApp(
            child: const StudentDashboardPage(),
            authCubit: authCubit,
            notificationsCubit: notifCubit,
            groupsCubit: groupsCubit,
            studentDashboardCubit: dashCubit,
          ),
        );
        await tester.pump();
        renderWatch.stop();

        // 3. Interactive Settle (full layout & frame transitions complete)
        final settleWatch = Stopwatch()..start();
        await tester.pumpAndSettle();
        settleWatch.stop();
        stopwatch.stop();

        expect(tester.takeException(), isNull);
        expect(find.byType(StudentDashboardPage), findsOneWidget);

        final coldMetric = ScreenBenchmarkMetric(
          screenName: 'StudentDashboardPage (Cold Start)',
          fetchDurationMs: fetchWatch.elapsedMilliseconds,
          firstFrameRenderMs: renderWatch.elapsedMilliseconds,
          interactiveSettleMs: settleWatch.elapsedMilliseconds,
          totalEndToEndMs: stopwatch.elapsedMilliseconds,
          withinPerformanceBudget: stopwatch.elapsedMilliseconds < 2500,
          details: 'Fetched fresh stats and rendered continue learning cards',
        );
        benchmarkResults.add(coldMetric);

        expect(coldMetric.withinPerformanceBudget, isTrue,
            reason: 'Cold start should complete well under 2500ms budget');

        // Warm Cache Benchmark (Second visit: Stale-While-Revalidate instant render)
        final warmStopwatch = Stopwatch()..start();
        await tester.pumpWidget(
          buildBenchmarkApp(
            child: const StudentDashboardPage(),
            authCubit: authCubit,
            notificationsCubit: notifCubit,
            groupsCubit: groupsCubit,
            studentDashboardCubit: dashCubit,
          ),
        );
        await tester.pump();
        warmStopwatch.stop();

        final warmMetric = ScreenBenchmarkMetric(
          screenName: 'StudentDashboardPage (Warm Cache SWR)',
          fetchDurationMs: 0,
          firstFrameRenderMs: warmStopwatch.elapsedMilliseconds,
          interactiveSettleMs: 0,
          totalEndToEndMs: warmStopwatch.elapsedMilliseconds,
          withinPerformanceBudget: warmStopwatch.elapsedMilliseconds < 400,
          details: 'Cached state rendered with zero network lag',
        );
        benchmarkResults.add(warmMetric);

        expect(warmMetric.withinPerformanceBudget, isTrue);
      },
    );

    testWidgets(
      'BENCHMARK: TeacherDashboardPage high-density cohort metrics render budget',
      (tester) async {
        final authCubit = AuthCubit(repository: _BenchAuthRepo(testTeacher));
        final notifCubit = NotificationsCubit(repository: _BenchNotificationsRepo());
        final groupsCubit = GroupsCubit(repository: _BenchGroupsRepo());
        final studentsCubit = StudentsCubit(repository: _BenchStudentsRepo());

        AppCache.setCurrentUser(testTeacher.id);
        authCubit.emit(const AuthAuthenticated(testTeacher));

        final stopwatch = Stopwatch()..start();
        final fetchWatch = Stopwatch()..start();
        await groupsCubit.loadGroups();
        await studentsCubit.loadStudents();
        fetchWatch.stop();

        final renderWatch = Stopwatch()..start();
        await tester.pumpWidget(
          buildBenchmarkApp(
            child: const TeacherDashboardPage(),
            authCubit: authCubit,
            notificationsCubit: notifCubit,
            groupsCubit: groupsCubit,
            studentsCubit: studentsCubit,
          ),
        );
        await tester.pump();
        renderWatch.stop();

        final settleWatch = Stopwatch()..start();
        await tester.pumpAndSettle();
        settleWatch.stop();
        stopwatch.stop();

        expect(tester.takeException(), isNull);
        expect(find.byType(TeacherDashboardPage), findsOneWidget);

        final metric = ScreenBenchmarkMetric(
          screenName: 'TeacherDashboardPage (50 Students + 3 Groups Cohort)',
          fetchDurationMs: fetchWatch.elapsedMilliseconds,
          firstFrameRenderMs: renderWatch.elapsedMilliseconds,
          interactiveSettleMs: settleWatch.elapsedMilliseconds,
          totalEndToEndMs: stopwatch.elapsedMilliseconds,
          withinPerformanceBudget: stopwatch.elapsedMilliseconds < 2000,
          details: 'Calculated and laid out attendance rate, groups and pending tasks',
        );
        benchmarkResults.add(metric);

        expect(metric.withinPerformanceBudget, isTrue);
      },
    );

    testWidgets(
      'BENCHMARK: Student360Page deep academic passport (historical metrics, radar, video insights)',
      (tester) async {
        final authCubit = AuthCubit(repository: _BenchAuthRepo(testTeacher));
        final notifCubit = NotificationsCubit(repository: _BenchNotificationsRepo());
        final studentsCubit = StudentsCubit(repository: _BenchStudentsRepo());

        AppCache.setCurrentUser(testTeacher.id);
        authCubit.emit(const AuthAuthenticated(testTeacher));

        final stopwatch = Stopwatch()..start();
        final fetchWatch = Stopwatch()..start();
        await studentsCubit.loadStudent360('student-bench-01');
        fetchWatch.stop();

        final renderWatch = Stopwatch()..start();
        await tester.pumpWidget(
          buildBenchmarkApp(
            child: const Student360Page(studentId: 'student-bench-01'),
            authCubit: authCubit,
            notificationsCubit: notifCubit,
            studentsCubit: studentsCubit,
          ),
        );
        await tester.pump();
        renderWatch.stop();

        final settleWatch = Stopwatch()..start();
        await tester.pumpAndSettle();
        settleWatch.stop();
        stopwatch.stop();

        expect(tester.takeException(), isNull);
        expect(find.byType(Student360Page), findsOneWidget);

        final metric = ScreenBenchmarkMetric(
          screenName: 'Student360Page (Multi-Tab Deep Passport)',
          fetchDurationMs: fetchWatch.elapsedMilliseconds,
          firstFrameRenderMs: renderWatch.elapsedMilliseconds,
          interactiveSettleMs: settleWatch.elapsedMilliseconds,
          totalEndToEndMs: stopwatch.elapsedMilliseconds,
          withinPerformanceBudget: stopwatch.elapsedMilliseconds < 1500,
          details: 'Rendered radar metrics, attendance logs, and video watch insights',
        );
        benchmarkResults.add(metric);

        expect(metric.withinPerformanceBudget, isTrue);
      },
    );

    testWidgets(
      'BENCHMARK: StudentExamsPage high-volume exam catalog rendering speed',
      (tester) async {
        final authCubit = AuthCubit(repository: _BenchAuthRepo(testStudent));
        final notifCubit = NotificationsCubit(repository: _BenchNotificationsRepo());
        final examsCubit = ExamsCubit(repository: _BenchExamsRepo());

        AppCache.setCurrentUser(testStudent.id);
        authCubit.emit(const AuthAuthenticated(testStudent));

        final stopwatch = Stopwatch()..start();
        final fetchWatch = Stopwatch()..start();
        await examsCubit.loadStudentExams();
        fetchWatch.stop();

        final renderWatch = Stopwatch()..start();
        await tester.pumpWidget(
          buildBenchmarkApp(
            child: const StudentExamsPage(),
            authCubit: authCubit,
            notificationsCubit: notifCubit,
            examsCubit: examsCubit,
          ),
        );
        await tester.pump();
        renderWatch.stop();

        final settleWatch = Stopwatch()..start();
        await tester.pumpAndSettle();
        settleWatch.stop();
        stopwatch.stop();

        expect(tester.takeException(), isNull);
        expect(find.byType(StudentExamsPage), findsOneWidget);

        final metric = ScreenBenchmarkMetric(
          screenName: 'StudentExamsPage (20 Multi-Folder Exams)',
          fetchDurationMs: fetchWatch.elapsedMilliseconds,
          firstFrameRenderMs: renderWatch.elapsedMilliseconds,
          interactiveSettleMs: settleWatch.elapsedMilliseconds,
          totalEndToEndMs: stopwatch.elapsedMilliseconds,
          withinPerformanceBudget: stopwatch.elapsedMilliseconds < 2500,
          details: 'Catalog loaded, categorized into folders with active badges',
        );
        benchmarkResults.add(metric);

        expect(metric.withinPerformanceBudget, isTrue);
      },
    );

    testWidgets(
      'BENCHMARK: TeacherVideoBankPage video library and CDN status rendering speed',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final authCubit = AuthCubit(repository: _BenchAuthRepo(testTeacher));
        final notifCubit = NotificationsCubit(repository: _BenchNotificationsRepo());
        final groupsCubit = GroupsCubit(repository: _BenchGroupsRepo());
        final videoBankCubit = VideoBankCubit(repository: _BenchVideoBankRepo());

        AppCache.setCurrentUser(testTeacher.id);
        authCubit.emit(const AuthAuthenticated(testTeacher));

        final stopwatch = Stopwatch()..start();
        final fetchWatch = Stopwatch()..start();
        await videoBankCubit.loadFolder();
        fetchWatch.stop();

        final renderWatch = Stopwatch()..start();
        await tester.pumpWidget(
          buildBenchmarkApp(
            child: const TeacherVideoBankPage(),
            authCubit: authCubit,
            notificationsCubit: notifCubit,
            groupsCubit: groupsCubit,
            videoBankCubit: videoBankCubit,
          ),
        );
        await tester.pump();
        renderWatch.stop();

        final settleWatch = Stopwatch()..start();
        await tester.pumpAndSettle();
        settleWatch.stop();
        stopwatch.stop();

        expect(tester.takeException(), isNull);
        expect(find.byType(TeacherVideoBankPage), findsOneWidget);

        final metric = ScreenBenchmarkMetric(
          screenName: 'TeacherVideoBankPage (25 CDN Videos & Folders)',
          fetchDurationMs: fetchWatch.elapsedMilliseconds,
          firstFrameRenderMs: renderWatch.elapsedMilliseconds,
          interactiveSettleMs: settleWatch.elapsedMilliseconds,
          totalEndToEndMs: stopwatch.elapsedMilliseconds,
          withinPerformanceBudget: stopwatch.elapsedMilliseconds < 2000,
          details: 'Processed library video cards with status chips and duration badges',
        );
        benchmarkResults.add(metric);

        expect(metric.withinPerformanceBudget, isTrue);
      },
    );
  });
}
