import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/core/utils/whatsapp_report_generator.dart';

// Domain Entities
import 'package:edu_saas/features/students/domain/entities/student_entity.dart';
import 'package:edu_saas/features/groups/domain/entities/group_entity.dart';
import 'package:edu_saas/features/groups/domain/entities/group_member_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_folder_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_parent_dispatch_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';

// Repositories & Cubits
import 'package:edu_saas/features/students/domain/repositories/students_repository.dart';
import 'package:edu_saas/features/students/presentation/cubit/students_cubit.dart';
import 'package:edu_saas/features/students/presentation/cubit/students_state.dart';
import 'package:edu_saas/features/groups/domain/repositories/groups_repository.dart';
import 'package:edu_saas/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:edu_saas/features/groups/presentation/cubit/groups_state.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:edu_saas/features/students/domain/entities/student_360_entity.dart';
import 'package:edu_saas/features/students/domain/entities/student_academic_report_entity.dart';

// ---------------------------------------------------------------------------
// High-Capacity In-Memory Simulated Backend Store
// ---------------------------------------------------------------------------
class _SimulatedCohortBackend {
  final Map<String, StudentEntity> students = {};
  final Map<String, GroupEntity> groups = {};
  final List<GroupMemberEntity> groupMembers = [];
  final Map<String, ExamEntity> exams = {};
  final List<Map<String, dynamic>> auditLogs = [];

  void recordAudit(String action, String targetId, Map<String, dynamic> metadata) {
    auditLogs.add({
      'action': action,
      'target_id': targetId,
      'metadata': metadata,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}

// ---------------------------------------------------------------------------
// Realistic Mock Repositories Hooked to In-Memory Backend Store
// ---------------------------------------------------------------------------
class _CohortStudentsRepo implements StudentsRepository {
  final _SimulatedCohortBackend backend;
  _CohortStudentsRepo(this.backend);

  @override
  Future<Result<List<StudentEntity>>> getStudents({
    String? status,
    String? searchQuery,
    int page = 0,
    int pageSize = 25,
  }) async {
    var list = backend.students.values.toList();
    if (status != null && status.isNotEmpty) {
      list = list.where((s) => s.status == status).toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      list = list.where((s) => s.fullName.contains(searchQuery) || s.email.contains(searchQuery)).toList();
    }
    return Success(list);
  }

  @override
  Future<Result<List<StudentEntity>>> getPendingStudents({int page = 0, int pageSize = 20}) async {
    final pending = backend.students.values.where((s) => s.status == 'pending').toList();
    return Success(pending);
  }

  @override
  Future<Result<StudentEntity>> changeStudentStatus({
    required String studentId,
    required String action, // 'approve' | 'reject' | 'suspend'
  }) async {
    final existing = backend.students[studentId];
    if (existing == null) {
      return const FailureResult(ServerFailure('Student does not exist', code: 'STUDENT_NOT_FOUND'));
    }

    final newStatus = switch (action) {
      'approve' => 'active',
      'reject' => 'rejected',
      'suspend' => 'suspended',
      _ => 'active',
    };

    final updated = StudentEntity(
      id: existing.id,
      tenantId: existing.tenantId,
      fullName: existing.fullName,
      email: existing.email,
      phone: existing.phone,
      parentPhone: existing.parentPhone,
      status: newStatus,
      createdAt: existing.createdAt,
    );

    backend.students[studentId] = updated;
    backend.recordAudit('student.status_changed', studentId, {'old_status': existing.status, 'new_status': newStatus});
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteStudent(String studentId) async {
    // Under Section 3.2, permanent deletion of academic users is prohibited
    return const FailureResult(ServerFailure(
      'Permanent deletion is prohibited under academic compliance. Use suspend or reject instead.',
      code: 'PROHIBITED_ACTION',
    ));
  }

  @override
  Future<Result<Student360Entity>> getStudent360(String studentId) async {
    final student = backend.students[studentId];
    if (student == null) {
      return const FailureResult(ServerFailure('Student 360 not found', code: 'NOT_FOUND'));
    }
    return Success(Student360Entity(
      studentId: studentId,
      attendancePercentage: 92.5,
      assignmentsSubmitted: 18,
      assignmentsReviewed: 17,
      examAverage: 88.0,
      videoCompletionPercentage: 84.5,
      todayActiveSeconds: 3600,
      todayIdleSeconds: 200,
      firstSeenToday: DateTime.now().subtract(const Duration(hours: 4)),
      lastSeenToday: DateTime.now().subtract(const Duration(minutes: 15)),
      totalActiveSeconds7d: 28800,
      totalIdleSeconds7d: 1500,
      groups: [],
      recentActivities: [],
    ));
  }

  @override
  Future<Result<StudentAcademicReportEntity>> getStudentAcademicReport(String studentId, {int? days}) async =>
      throw UnimplementedError();

  @override
  Future<Result<StudentEntity>> getStudent(String studentId) async =>
      Success(backend.students[studentId] ?? StudentEntity(
        id: studentId,
        tenantId: 'tenant-1',
        fullName: 'Student $studentId',
        email: 's@test.com',
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
}

class _CohortGroupsRepo implements GroupsRepository {
  final _SimulatedCohortBackend backend;
  _CohortGroupsRepo(this.backend);

  @override
  Future<Result<List<GroupEntity>>> getGroups() async {
    return Success(backend.groups.values.toList());
  }

  @override
  Future<Result<GroupEntity>> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  }) async {
    final group = GroupEntity(
      id: 'grp-${backend.groups.length + 1}',
      tenantId: 'tenant-1',
      name: name,
      level: level,
      description: description,
      previousContentAccess: previousContentAccess,
      membersCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    backend.groups[group.id] = group;
    return Success(group);
  }

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
  }) async {
    final existing = backend.groups[id];
    if (existing == null) {
      return const FailureResult(ServerFailure('Group not found', code: 'GROUP_NOT_FOUND'));
    }
    final updated = GroupEntity(
      id: existing.id,
      tenantId: existing.tenantId,
      name: name ?? existing.name,
      level: level ?? existing.level,
      description: description ?? existing.description,
      previousContentAccess: previousContentAccess ?? existing.previousContentAccess,
      membersCount: existing.membersCount,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    backend.groups[id] = updated;
    return Success(updated);
  }

  @override
  @override
  Future<Result<GroupMemberEntity>> addMemberToGroup({required String groupId, required String studentId}) async {
    final student = backend.students[studentId];
    final member = GroupMemberEntity(
      id: 'gm-${backend.groupMembers.length + 1}',
      groupId: groupId,
      studentId: studentId,
      studentName: student?.fullName ?? 'Student $studentId',
      joinedAt: DateTime.now(),
    );
    backend.groupMembers.add(member);
    final group = backend.groups[groupId];
    if (group != null) {
      backend.groups[groupId] = GroupEntity(
        id: group.id,
        tenantId: group.tenantId,
        name: group.name,
        level: group.level,
        description: group.description,
        previousContentAccess: group.previousContentAccess,
        membersCount: group.membersCount + 1,
        createdAt: group.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    return Success(member);
  }

  @override
  Future<Result<List<GroupMemberEntity>>> getGroupMembers(String groupId, {int page = 0, int pageSize = 25}) async {
    final members = backend.groupMembers.where((gm) => gm.groupId == groupId).toList();
    return Success(members);
  }

  @override
  Future<Result<void>> removeMemberFromGroup({required String groupId, required String studentId}) async {
    backend.groupMembers.removeWhere((gm) => gm.groupId == groupId && gm.studentId == studentId);
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteGroup(String groupId) async => const Success(null);
}

class _CohortExamsRepo implements ExamsRepository {
  final _SimulatedCohortBackend backend;
  _CohortExamsRepo(this.backend);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Result<ExamEntity>> createExam({
    String? groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = true,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    bool isPublished = false,
    String? pdfFileId,
    required List<ExamQuestionEntity> initialQuestions,
  }) async {
    final exam = ExamEntity(
      id: 'exam-${backend.exams.length + 1}',
      contentId: 'cnt-exam-${backend.exams.length + 1}',
      tenantId: 'tenant-1',
      groupId: groupId ?? 'grp-1',
      title: title,
      durationMinutes: durationMinutes,
      maxScore: maxScore,
      passingScore: passingScore,
      shuffleQuestions: shuffleQuestions,
      showResult: showResult,
      allowRetake: allowRetake,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    backend.exams[exam.id] = exam;
    return Success(exam);
  }

  @override
  Future<Result<void>> linkExamToLesson({
    required String examId,
    required String lessonId,
    required String groupId,
  }) async {
    final exam = backend.exams[examId];
    if (exam == null) return const FailureResult(ServerFailure('Exam not found', code: 'NOT_FOUND'));
    backend.exams[examId] = ExamEntity(
      id: exam.id,
      contentId: exam.contentId,
      tenantId: exam.tenantId,
      groupId: exam.groupId,
      title: exam.title,
      durationMinutes: exam.durationMinutes,
      maxScore: exam.maxScore,
      passingScore: exam.passingScore,
      shuffleQuestions: exam.shuffleQuestions,
      showResult: exam.showResult,
      allowRetake: exam.allowRetake,
      linkedLessonId: lessonId,
      createdAt: exam.createdAt,
      updatedAt: DateTime.now(),
    );
    backend.recordAudit('exam.linked_to_lesson', examId, {'lesson_id': lessonId});
    return const Success(null);
  }

  @override
  Future<Result<void>> unlinkExamFromLesson({
    required String examId,
    required String groupId,
    bool makeGeneralExam = false,
  }) async {
    final exam = backend.exams[examId];
    if (exam == null) return const FailureResult(ServerFailure('Exam not found', code: 'NOT_FOUND'));
    backend.exams[examId] = ExamEntity(
      id: exam.id,
      contentId: exam.contentId,
      tenantId: exam.tenantId,
      groupId: exam.groupId,
      title: exam.title,
      durationMinutes: exam.durationMinutes,
      maxScore: exam.maxScore,
      passingScore: exam.passingScore,
      shuffleQuestions: exam.shuffleQuestions,
      showResult: exam.showResult,
      allowRetake: exam.allowRetake,
      linkedLessonId: null, // Unlinked
      createdAt: exam.createdAt,
      updatedAt: DateTime.now(),
    );
    backend.recordAudit('exam.unlinked_from_lesson', examId, {'make_general': makeGeneralExam});
    return const Success(null);
  }

  // Stubs for interface completeness
  @override
  Future<Result<List<ExamEntity>>> getStudentExams({int page = 0, int pageSize = 15}) async => const Success([]);
  @override
  Future<Result<List<ExamEntity>>> getGroupExams(String groupId, {int page = 0, int pageSize = 15}) async => const Success([]);
  @override
  Future<Result<ExamEntity>> getExamDetails(String examId) async => throw UnimplementedError();
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
  Future<Result<bool>> deleteExam({required String examId, bool force = false}) async => const Success(true);
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
  Future<Result<ExamParentDispatchRosterEntity>> getExamParentDispatchRoster(String examId) async =>
      const Success(ExamParentDispatchRosterEntity(
        exam: ExamDispatchMetaEntity(id: 'exam-1', title: 'Exam', maxScore: 100),
        stats: ExamDispatchStatsEntity(),
        students: [],
      ));
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
  Future<Result<bool>> updateMistakeReflection({
    required String mistakeId,
    required String? reflectionReason,
  }) async => const Success(true);
  @override
  Future<Result<bool>> moveExamToFolder({required String examId, String? folderId}) async => const Success(true);
  @override
  Future<Result<List<Map<String, dynamic>>>> getGroupLessons(String groupId) async => const Success([]);
  @override
  Future<Result<String>> getSignedPdfUrl(String storagePath, {String? storageProvider}) async => const Success('https://storage.mock.pdf');
}

// ---------------------------------------------------------------------------
// TEST SUITE: Teacher High-Capacity Cohort Simulation
// ---------------------------------------------------------------------------
void main() {
  late _SimulatedCohortBackend backend;
  late _CohortStudentsRepo studentsRepo;
  late _CohortGroupsRepo groupsRepo;
  late _CohortExamsRepo examsRepo;

  late StudentsCubit studentsCubit;
  late GroupsCubit groupsCubit;
  late ExamsCubit examsCubit;

  setUp(() {
    AppCache.clearAll();
    backend = _SimulatedCohortBackend();
    studentsRepo = _CohortStudentsRepo(backend);
    groupsRepo = _CohortGroupsRepo(backend);
    examsRepo = _CohortExamsRepo(backend);

    studentsCubit = StudentsCubit(repository: studentsRepo);
    groupsCubit = GroupsCubit(repository: groupsRepo);
    examsCubit = ExamsCubit(repository: examsRepo);
  });

  tearDown(() {
    studentsCubit.close();
    groupsCubit.close();
    examsCubit.close();
    AppCache.clearAll();
  });

  group('🏫 [Simulation: Teacher High-Capacity Cohort Operations]', () {
    test('SCENARIO 1: Admissions Pipeline — Mass approval and rejection preserves immutability & audit log', () async {
      // 1. Seed 20 pending registrations with mixed Egyptian, Gulf, and international phones
      for (int i = 1; i <= 20; i++) {
        final phone = i % 2 == 0 ? '010123456$i' : '٠١١٩٨٧٦٥٤$i';
        final parentPhone = i % 2 == 0 ? '012345678$i' : '+9665012345$i';
        backend.students['std-$i'] = StudentEntity(
          id: 'std-$i',
          tenantId: 'tenant-1',
          fullName: 'Student Cohort Applicant #$i',
          email: 'applicant$i@satprep.academy',
          phone: phone,
          parentPhone: parentPhone,
          status: 'pending',
          createdAt: DateTime.now().subtract(Duration(hours: 24 - i)),
        );
      }

      // Verify initial pending count
      await studentsCubit.loadPendingStudents();
      expect(studentsCubit.state, isA<PendingStudentsLoaded>());
      var loadedState = studentsCubit.state as PendingStudentsLoaded;
      expect(loadedState.pending.length, equals(20));

      // 2. Teacher approves the first 15 students
      for (int i = 1; i <= 15; i++) {
        await studentsCubit.changeStatus(studentId: 'std-$i', action: 'approve');
      }

      // 3. Teacher rejects the remaining 5 students (e.g. invalid credentials or spam)
      for (int i = 16; i <= 20; i++) {
        await studentsCubit.changeStatus(studentId: 'std-$i', action: 'reject');
      }

      // 4. Assert Pending Queue is now completely drained
      await studentsCubit.loadPendingStudents();
      loadedState = studentsCubit.state as PendingStudentsLoaded;
      expect(loadedState.pending.length, equals(0), reason: 'All pending applicants processed');

      // 5. CRITICAL ARCHITECTURAL ASSERTION (§3.2 & §13 Privacy):
      // Rejected students are NEVER deleted from the DB! Their records persist as 'rejected'
      expect(backend.students.length, equals(20), reason: 'Zero data deletion for auditability');
      for (int i = 16; i <= 20; i++) {
        expect(backend.students['std-$i']!.status, equals('rejected'));
      }

      // Verify that permanent deletion is explicitly blocked by repository
      final deleteAttempt = await studentsRepo.deleteStudent('std-16');
      expect(deleteAttempt.isFailure, isTrue);
      expect(deleteAttempt.failureOrNull?.code, equals('PROHIBITED_ACTION'));

      // 6. Assert Audit Trail integrity
      expect(backend.auditLogs.length, equals(20));
      final approvedLogs = backend.auditLogs.where((l) => l['metadata']['new_status'] == 'active');
      final rejectedLogs = backend.auditLogs.where((l) => l['metadata']['new_status'] == 'rejected');
      expect(approvedLogs.length, equals(15));
      expect(rejectedLogs.length, equals(5));
    });

    test('SCENARIO 2: Multi-Group Management & Content Access Policy configuration', () async {
      // 1. Teacher creates two specialized cohorts with differing previousContentAccess policies
      await groupsCubit.createGroup(
        name: 'SAT Advanced 1500+ Masters',
        level: 'SAT',
        description: 'Deep problem solving and full-length simulated exams',
        previousContentAccess: 'none', // Strictly from join date
      );

      await groupsCubit.createGroup(
        name: 'EST Math Fundamentals Intensive',
        level: 'EST',
        description: 'Comprehensive curriculum with access to entire library archive',
        previousContentAccess: 'all', // Full archive access
      );

      await groupsCubit.loadGroups();
      expect(groupsCubit.state, isA<GroupsLoaded>());
      final groups = (groupsCubit.state as GroupsLoaded).groups;
      expect(groups.length, equals(2));

      final satGroup = groups.firstWhere((g) => g.name.contains('SAT'));
      final estGroup = groups.firstWhere((g) => g.name.contains('EST'));

      expect(satGroup.previousContentAccess, equals('none'));
      expect(estGroup.previousContentAccess, equals('all'));

      // 2. Add approved students into both cohorts
      for (int i = 1; i <= 10; i++) {
        await groupsCubit.addMember(groupId: satGroup.id, studentId: 'std-$i');
      }
      for (int i = 5; i <= 15; i++) {
        // Students 5..10 belong to BOTH groups concurrently (multi-group membership)
        await groupsCubit.addMember(groupId: estGroup.id, studentId: 'std-$i');
      }

      // Verify members count in backend
      final satMembers = backend.groupMembers.where((m) => m.groupId == satGroup.id).toList();
      final estMembers = backend.groupMembers.where((m) => m.groupId == estGroup.id).toList();

      expect(satMembers.length, equals(10));
      expect(estMembers.length, equals(11));

      // Student 7 is enrolled in both cohorts
      final std7Memberships = backend.groupMembers.where((m) => m.studentId == 'std-7').toList();
      expect(std7Memberships.length, equals(2), reason: 'Multi-tenant architecture allows multi-group student enrollment');
    });

    test('SCENARIO 3: Curriculum Exam Linking & Lifecycle Immutability', () async {
      // 1. Teacher publishes an exam for SAT Group
      final createRes = await examsRepo.createExam(
        groupId: 'grp-1',
        title: 'Diagnostic Test: Advanced Polynomial Operations',
        durationMinutes: 60,
        maxScore: 100,
        passingScore: 75,
        shuffleQuestions: true,
        showResult: true,
        allowRetake: true,
        initialQuestions: const [],
      );
      expect(createRes.isSuccess, isTrue);
      final exam = createRes.dataOrNull!;

      // 2. Link Exam to a specific Lecture in Curriculum
      final linkRes = await examsRepo.linkExamToLesson(
        examId: exam.id,
        lessonId: 'lesson-poly-04',
        groupId: 'grp-1',
      );
      expect(linkRes.isSuccess, isTrue);
      expect(backend.exams[exam.id]?.linkedLessonId, equals('lesson-poly-04'));

      // 3. Unlink Exam from Lesson (Converts into general group exam without deletion)
      final unlinkRes = await examsRepo.unlinkExamFromLesson(
        examId: exam.id,
        groupId: 'grp-1',
        makeGeneralExam: true,
      );
      expect(unlinkRes.isSuccess, isTrue);
      expect(backend.exams[exam.id]?.linkedLessonId, isNull, reason: 'Exam preserved as standalone general exam');
      expect(backend.exams[exam.id]?.title, equals('Diagnostic Test: Advanced Polynomial Operations'));
    });

    test('SCENARIO 4: Automated WhatsApp Parent Reports & Multilingual Normalization under Scale', () async {
      // 1. Test cleanPhoneNumber on diverse real-world international formats
      // Arabic-Indic numerals
      expect(WhatsAppReportGenerator.cleanPhoneNumber('٠١٠١٢٣٤٥٦٧٨'), equals('201012345678'));
      // Local Egyptian format with spaces/dashes
      expect(WhatsAppReportGenerator.cleanPhoneNumber('012-345-67890'), equals('201234567890'));
      // Saudi mobile format
      expect(WhatsAppReportGenerator.cleanPhoneNumber('0501234567'), equals('966501234567'));
      // Kuwait mobile format (8 digits)
      expect(WhatsAppReportGenerator.cleanPhoneNumber('51234567'), equals('96551234567'));
      // Kuwait 9-digit with leading 0
      expect(WhatsAppReportGenerator.cleanPhoneNumber('051234567'), equals('96551234567'));
      // International leading 00
      expect(WhatsAppReportGenerator.cleanPhoneNumber('00201012345678'), equals('201012345678'));

      // 2. Batch report generation for 10 students
      final generatedReports = <String, String>{};
      for (int i = 1; i <= 10; i++) {
        final score = 70 + (i * 3);
        final report = WhatsAppReportGenerator.generateNaturalWeeklyReport(
          studentName: 'أحمد محمود $i',
          groupName: 'SAT Math Advanced Masters',
          videoWatchRate: (80 + i).toDouble(),
          completedAssignments: 4,
          totalAssignments: 5,
          mockExamScore: score,
          targetScore: 100,
          activeStudyMinutes: 240 + (i * 20),
          teacherNotes: score >= 90 ? 'أداء ممتاز واستيعاب استثنائي للمفاهيم' : 'يحتاج للتركيز على مسائل الهندسة الإحداثية',
          teacherName: 'د. أنطونيوس أشرف',
        );

        expect(report.isNotEmpty, isTrue);
        expect(report.contains('أحمد محمود $i'), isTrue);
        expect(report.contains('SAT Math Advanced Masters'), isTrue);
        expect(report.contains('د. أنطونيوس أشرف'), isTrue);
        expect(report.contains('$score / 100') || report.contains('$score%') || report.contains('$score'), isTrue);

        generatedReports['std-$i'] = report;
      }

      expect(generatedReports.length, equals(10));

      // 3. Generate Exam Result Dispatch Report
      final examReport = WhatsAppReportGenerator.generateExamResultReport(
        studentName: 'سارة خالد',
        examTitle: 'Digital SAT Practice Test 3 — Module 1 & 2',
        groupName: 'SAT Math Advanced Masters',
        score: 740.0,
        maxScore: 800.0,
        percentage: 92.5,
        teacherNotes: 'تحسن ملحوظ في سرعة حل أسئلة Grid-In',
        teacherName: 'د. أنطونيوس أشرف',
      );

      expect(examReport.contains('سارة خالد'), isTrue);
      expect(examReport.contains('740'), isTrue);
      expect(examReport.contains('800'), isTrue);
      expect(examReport.contains('Digital SAT Practice Test 3'), isTrue);
    });
  });
}
