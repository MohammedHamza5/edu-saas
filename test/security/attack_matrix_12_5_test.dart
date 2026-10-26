import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'mocks/simulated_attack_matrix_backend.dart';

void main() {
  late SimulatedAttackMatrixBackend backend;

  // Identity actors
  const studentA = UserEntity(
    id: 'std_a_101',
    tenantId: 'tenant_omega',
    role: UserRole.student,
    status: UserStatus.active,
    fullName: 'Student Alice',
    email: 'alice@omega.edu',
  );

  const studentB = UserEntity(
    id: 'std_b_102',
    tenantId: 'tenant_omega',
    role: UserRole.student,
    status: UserStatus.active,
    fullName: 'Student Bob',
    email: 'bob@omega.edu',
  );

  const studentForeignTenant = UserEntity(
    id: 'std_c_201',
    tenantId: 'tenant_alpha',
    role: UserRole.student,
    status: UserStatus.active,
    fullName: 'Student Charlie',
    email: 'charlie@alpha.edu',
  );

  const parentA = UserEntity(
    id: 'parent_a_501',
    tenantId: 'tenant_omega',
    role: UserRole.parent,
    status: UserStatus.active,
    fullName: 'Parent Alice Senior',
    email: 'parent_a@omega.edu',
  );

  const teacherOmega = UserEntity(
    id: 'teacher_omega_001',
    tenantId: 'tenant_omega',
    role: UserRole.teacher,
    status: UserStatus.active,
    fullName: 'Prof. Omega',
    email: 'prof@omega.edu',
  );

  setUp(() {
    backend = SimulatedAttackMatrixBackend(currentSession: studentA);

    // Seed database users
    backend.users[studentA.id] = studentA;
    backend.users[studentB.id] = studentB;
    backend.users[studentForeignTenant.id] = studentForeignTenant;
    backend.users[parentA.id] = parentA;
    backend.users[teacherOmega.id] = teacherOmega;

    // Seed Parent links: parentA is ONLY linked to studentA
    backend.parentLinks[parentA.id] = [studentA.id];

    // Seed Content items (one published, one draft)
    backend.contentItems['cnt_published'] = {
      'id': 'cnt_published',
      'tenant_id': 'tenant_omega',
      'title': 'SAT Math Chapter 1',
      'status': 'published',
    };
    backend.contentItems['cnt_draft'] = {
      'id': 'cnt_draft',
      'tenant_id': 'tenant_omega',
      'title': 'SAT Math Final Secret Draft',
      'status': 'draft',
    };

    // Seed Groups: studentA is in grp_sat, NOT in grp_est
    backend.groupMembers['grp_sat'] = [studentA.id];
    backend.groupMembers['grp_est'] = [studentB.id];

    // Seed Exams
    backend.exams['exam_sat_101'] = ExamEntity(
      id: 'exam_sat_101',
      contentId: 'cnt_sat_exam',
      groupId: 'grp_sat',
      tenantId: 'tenant_omega',
      title: 'SAT Milestone Exam',
      durationMinutes: 45,
      maxScore: 100,
      passingScore: 60,
      activeVersion: ExamVersionEntity(
        id: 'v1',
        examId: 'exam_sat_101',
        versionNumber: 1,
        status: ExamStatus.published,
        createdAt: DateTime.now(),
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    backend.secretExamKeys['exam_sat_101'] = {'q1': 'opt_1'};
  });

  group('🛡️ [Canonical Architecture §12.5 Attack Matrix Verification]', () {
    test('1. Student A → بيانات Student B ❌ يفشل (IDOR Denial)', () async {
      backend.currentSession = studentA;
      final result = await backend.getStudentProfile(studentB.id);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, equals('IDOR_DENIED'));
    });

    test('2. Student A → Tenant B ❌ يفشل (Cross-Tenant Breach Rejection)', () async {
      backend.currentSession = studentA;
      final result = await backend.getStudentProfile(studentForeignTenant.id);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, equals('TENANT_BREACH'));
    });

    test('3. Parent A → طفل B غير مرتبط ❌ يفشل (Foreign Child Denial)', () async {
      backend.currentSession = parentA;
      final result = await backend.getParentChildAcademicData(studentB.id);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, equals('FOREIGN_CHILD'));
    });

    test('4. Student → Draft Content ❌ يفشل (Zero-Knowledge 404)', () async {
      backend.currentSession = studentA;
      final result = await backend.getContent('cnt_draft');
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, equals('NOT_FOUND'));
    });

    test('5. Student → فيديو غير مصرح ❌ يفشل (Unenrolled Group Rejection)', () async {
      backend.currentSession = studentA;
      final result = await backend.requestVideoPlayback('vid_est_01', 'grp_est');
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, equals('UNAUTHORIZED_VIDEO'));
    });

    test('6. Student → تعديل درجته ❌ يفشل (Zero-Client-Trust Server Scoring)', () async {
      backend.currentSession = studentA;
      // Attacker claims 100/100, but provided wrong answer
      final result = await backend.submitExamAnswers(
        'exam_sat_101',
        {'q1': 'opt_WRONG'},
        clientClaimedScore: 100,
      );
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals(0), reason: 'Server strictly ignored client claimed score');
    });

    test('7. Student → رؤية is_correct قبل التسليم ❌ يفشل (Stripped Options)', () async {
      backend.currentSession = studentA;
      final result = await backend.getExamQuestionsForStudent('exam_sat_101');
      expect(result.isSuccess, isTrue);
      for (final opt in result.dataOrNull!) {
        expect(opt.containsKey('is_correct'), isFalse, reason: 'is_correct must be stripped');
      }
    });

    test('8. Student → عملية إدارية ❌ يفشل (Privilege Escalation Denial)', () async {
      backend.currentSession = studentA;
      final result = await backend.approveStudentAdmission(studentB.id);
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, equals('NOT_AUTHORIZED'));
    });

    test('9. Student → محتواه الخاص المصرّح ✅ ينجح', () async {
      backend.currentSession = studentA;
      final profileResult = await backend.getStudentProfile(studentA.id);
      expect(profileResult.isSuccess, isTrue);
      expect(profileResult.dataOrNull!['id'], equals(studentA.id));

      final contentResult = await backend.getContent('cnt_published');
      expect(contentResult.isSuccess, isTrue);
    });

    test('10. Parent → طفله المرتبط ✅ ينجح', () async {
      backend.currentSession = parentA;
      final result = await backend.getParentChildAcademicData(studentA.id);
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!['childId'], equals(studentA.id));
    });

    test('11. Teacher → بيانات Tenant الخاص به ✅ ينجح', () async {
      backend.currentSession = teacherOmega;
      final result = await backend.getTeacherTenantStudents();
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull!, containsAll([studentA.id, studentB.id]));
      expect(result.dataOrNull!, isNot(contains(studentForeignTenant.id)));
    });
  });
}
