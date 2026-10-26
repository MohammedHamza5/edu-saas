import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';

/// Simulated Backend engine strictly validating the 12.5 Canonical Attack Matrix
class SimulatedAttackMatrixBackend {
  UserEntity currentSession;

  // Multi-tenant database records
  final Map<String, UserEntity> users = {};
  final Map<String, List<String>> parentLinks = {}; // parentId -> [childId]
  final Map<String, ExamEntity> exams = {};
  final Map<String, Map<String, dynamic>> secretExamKeys = {}; // examId -> {qId: correctOpt}
  final Map<String, Map<String, dynamic>> contentItems = {}; // id -> content map
  final Map<String, List<String>> groupMembers = {}; // groupId -> [studentId]

  SimulatedAttackMatrixBackend({required this.currentSession});

  /// IDOR & Cross-Tenant Student Data Access Check (§5.2, §5.4, §12.5)
  Future<Result<Map<String, dynamic>>> getStudentProfile(String targetStudentId) async {
    final target = users[targetStudentId];
    if (target == null) {
      return const FailureResult(ServerFailure('Student not found', code: 'NOT_FOUND'));
    }
    // 1. Cross-Tenant Barrier
    if (target.tenantId != currentSession.tenantId) {
      return const FailureResult(ServerFailure('Tenant boundary breach', code: 'TENANT_BREACH'));
    }
    // 2. IDOR Barrier: Student can only access their own profile
    if (currentSession.isStudent && currentSession.id != targetStudentId) {
      return const FailureResult(ServerFailure('IDOR access denied', code: 'IDOR_DENIED'));
    }
    return Success({'id': target.id, 'name': target.fullName, 'email': target.email});
  }

  /// Parent Child Access Check (§5.2, §12.5)
  Future<Result<Map<String, dynamic>>> getParentChildAcademicData(String childId) async {
    if (!currentSession.isParent) {
      return const FailureResult(ServerFailure('Parents only', code: 'NOT_AUTHORIZED'));
    }
    final allowedChildren = parentLinks[currentSession.id] ?? [];
    if (!allowedChildren.contains(childId)) {
      return const FailureResult(ServerFailure('Unlinked child access blocked', code: 'FOREIGN_CHILD'));
    }
    return Success({'childId': childId, 'gpa': 3.9, 'streak': 5});
  }

  /// Draft Content Isolation Check (§5.2, §12.5)
  Future<Result<Map<String, dynamic>>> getContent(String contentId) async {
    final item = contentItems[contentId];
    if (item == null) {
      return const FailureResult(ServerFailure('Not found', code: 'NOT_FOUND'));
    }
    if (item['tenant_id'] != currentSession.tenantId) {
      return const FailureResult(ServerFailure('Tenant breach', code: 'TENANT_BREACH'));
    }
    // Zero-knowledge draft isolation: appears as 404 to students
    if (currentSession.isStudent && item['status'] == 'draft') {
      return const FailureResult(ServerFailure('Not found', code: 'NOT_FOUND'));
    }
    return Success(item);
  }

  /// Unauthorized Video Playback Token Check (§11.3, §12.5)
  Future<Result<String>> requestVideoPlayback(String videoId, String groupId) async {
    final enrolled = (groupMembers[groupId] ?? []).contains(currentSession.id);
    if (currentSession.isStudent && !enrolled) {
      return const FailureResult(ServerFailure('Unauthorized video group', code: 'UNAUTHORIZED_VIDEO'));
    }
    return const Success('https://tokenized.bunnycdn.com/stream.m3u8');
  }

  /// Exam Question Options Zero-Knowledge Sanitization (§0.1, §12.5)
  Future<Result<List<Map<String, dynamic>>>> getExamQuestionsForStudent(String examId) async {
    final exam = exams[examId];
    if (exam == null || (currentSession.isStudent && exam.isDraft)) {
      return const FailureResult(ServerFailure('Exam not found', code: 'NOT_FOUND'));
    }
    final rawOptions = [
      {'id': 'opt_1', 'text': 'Option A', 'is_correct': true},
      {'id': 'opt_2', 'text': 'Option B', 'is_correct': false},
    ];
    // Strip is_correct unconditionally for student caller
    final sanitized = rawOptions.map((opt) {
      final copy = Map<String, dynamic>.from(opt);
      if (currentSession.isStudent) {
        copy.remove('is_correct');
      }
      return copy;
    }).toList();
    return Success(sanitized);
  }

  /// Atomic Server-Side Score Evaluation (§0.5, §11.3, §12.5)
  Future<Result<int>> submitExamAnswers(String examId, Map<String, String> answers, {int? clientClaimedScore}) async {
    final keys = secretExamKeys[examId] ?? {};
    int serverScore = 0;
    keys.forEach((qId, correctOpt) {
      if (answers[qId] == correctOpt) {
        serverScore += 25;
      }
    });
    // Disregard clientClaimedScore completely (Zero Client Trust)
    return Success(serverScore);
  }

  /// Administrative Actions Barrier (§5.2, §12.5)
  Future<Result<bool>> approveStudentAdmission(String studentId) async {
    if (!currentSession.isTeacher) {
      return const FailureResult(ServerFailure('Admin privilege required', code: 'NOT_AUTHORIZED'));
    }
    return const Success(true);
  }

  /// Teacher Tenant Boundary Check (§5.2, §12.5)
  Future<Result<List<String>>> getTeacherTenantStudents() async {
    if (!currentSession.isTeacher) {
      return const FailureResult(ServerFailure('Teacher only', code: 'NOT_AUTHORIZED'));
    }
    final tenantStudents = users.values
        .where((u) => u.tenantId == currentSession.tenantId && u.isStudent)
        .map((u) => u.id)
        .toList();
    return Success(tenantStudents);
  }
}
