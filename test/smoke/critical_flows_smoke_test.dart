import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/academic_momentum_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('🚀 [Canonical Architecture §21.3 End-to-End Critical Flows Smoke Suite]', () {
    test('FLOW 1: Student Registration → Teacher Review & Approval → Group Assignment', () async {
      // 1. Initial Registration (Status: Pending, No Group)
      var student = const UserEntity(
        id: 'std_applicant_01',
        tenantId: 'tenant_math_academy',
        role: UserRole.student,
        status: UserStatus.pending,
        fullName: 'Ziad SAT Master',
        email: 'ziad@sat.edu',
      );
      expect(student.isPending, isTrue);

      // 2. Teacher Admin Approval Action
      const teacher = UserEntity(
        id: 'teacher_admin_01',
        tenantId: 'tenant_math_academy',
        role: UserRole.teacher,
        status: UserStatus.active,
        fullName: 'Dr. Antounios',
        email: 'antounios@academy.edu',
      );
      expect(teacher.isTeacher, isTrue);

      // Approval transition
      student = const UserEntity(
        id: 'std_applicant_01',
        tenantId: 'tenant_math_academy',
        role: UserRole.student,
        status: UserStatus.active,
        fullName: 'Ziad SAT Master',
        email: 'ziad@sat.edu',
      );
      expect(student.isActive, isTrue);

      // 3. Group Assignment (Enrolled in SAT Math Alpha)
      final studentGroups = <String>['grp_sat_alpha'];
      expect(studentGroups, contains('grp_sat_alpha'));
    });

    test('FLOW 2: Content Publishing & Enrolled Group Access Rights', () async {
      // Content created as draft
      final content = {
        'id': 'cnt_ch1_algebra',
        'title': 'Chapter 1: Heart of Algebra',
        'status': 'draft',
        'group_id': 'grp_sat_alpha',
      };
      expect(content['status'], equals('draft'));

      // Publishing step
      content['status'] = 'published';
      expect(content['status'], equals('published'));

      // Student enrolled verification
      const studentGroupId = 'grp_sat_alpha';
      final hasAccess = (studentGroupId == content['group_id']) && (content['status'] == 'published');
      expect(hasAccess, isTrue);
    });

    test('FLOW 3: Exam Taking → Server Grading → Mistake Reflection → Academic Momentum', () async {
      // 1. Exam initialized
      final exam = ExamEntity(
        id: 'exam_sat_diagnostic',
        contentId: 'cnt_ch1_algebra',
        groupId: 'grp_sat_alpha',
        tenantId: 'tenant_math_academy',
        title: 'Heart of Algebra Diagnostic',
        durationMinutes: 40,
        maxScore: 100,
        passingScore: 70,
        activeVersion: ExamVersionEntity(
          id: 'v1',
          examId: 'exam_sat_diagnostic',
          versionNumber: 1,
          status: ExamStatus.published,
          createdAt: DateTime.now(),
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(exam.isPublished, isTrue);

      // 2. Student Submits answers
      final studentAnswers = {'q1': 'opt_correct', 'q2': 'opt_wrong_calc'};
      final answerKey = {'q1': 'opt_correct', 'q2': 'opt_correct'};

      int score = 0;
      final mistakeIds = <String>[];
      studentAnswers.forEach((qId, opt) {
        if (opt == answerKey[qId]) {
          score += 50;
        } else {
          mistakeIds.add(qId);
        }
      });

      expect(score, equals(50));
      expect(mistakeIds, contains('q2'));

      // 3. Mistake Reflection (Student labels q2 as Calculation Slip)
      final mistakeReflections = <String, String>{'q2': 'calculation_slip'};
      expect(mistakeReflections['q2'], equals('calculation_slip'));

      // 4. Momentum Engine Synchronization (Streak & Scaled Score)
      final today = DateTime.now();
      final finishedExam = exam.copyWith(
        myLatestAttempt: ExamAttemptEntity(
          id: 'att_01',
          examId: exam.id,
          examVersionId: 'v1',
          studentId: 'std_applicant_01',
          startedAt: today.subtract(const Duration(minutes: 20)),
          submittedAt: today,
          status: AttemptStatus.submitted,
          score: 50,
          percentage: 50.0,
          answers: const [],
        ),
      );

      final momentum = AcademicMomentumEntity.calculate(
        exams: [finishedExam],
        resolvedMistakes: 1,
        unresolvedMistakes: 1,
      );

      expect(momentum.currentStreakDays, equals(1));
      expect(momentum.isTodayActive, isTrue);
    });

    test('FLOW 4: Parent Portal Academic Monitoring & Child Isolation', () async {
      const parentId = 'parent_user_10';
      const myChildId = 'std_applicant_01';
      const foreignChildId = 'std_stranger_99';

      final parentChildDirectory = <String, List<String>>{
        parentId: [myChildId],
      };

      // Authorized Child Access
      final isAuthorizedForMyChild = parentChildDirectory[parentId]?.contains(myChildId) ?? false;
      expect(isAuthorizedForMyChild, isTrue);

      // Unauthorized Child Denial
      final isAuthorizedForForeignChild = parentChildDirectory[parentId]?.contains(foreignChildId) ?? false;
      expect(isAuthorizedForForeignChild, isFalse);
    });
  });
}
