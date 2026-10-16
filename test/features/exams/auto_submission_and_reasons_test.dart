import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/data/models/exam_attempt_model.dart';

void main() {
  group('Exam Auto-Submission & Submission Reasons Unit Tests', () {
    test('ExamSubmissionReason parses strings correctly and maps back to value', () {
      expect(
        ExamSubmissionReason.fromString('student_submitted'),
        equals(ExamSubmissionReason.studentSubmitted),
      );
      expect(
        ExamSubmissionReason.fromString('time_expired'),
        equals(ExamSubmissionReason.timeExpired),
      );
      expect(
        ExamSubmissionReason.fromString('forced_exit'),
        equals(ExamSubmissionReason.forcedExit),
      );
      expect(
        ExamSubmissionReason.fromString('security_violations'),
        equals(ExamSubmissionReason.securityViolations),
      );
      expect(
        ExamSubmissionReason.fromString('tab_closed'),
        equals(ExamSubmissionReason.tabClosed),
      );
      expect(
        ExamSubmissionReason.fromString('system_timeout'),
        equals(ExamSubmissionReason.systemTimeout),
      );
      // Fallback
      expect(
        ExamSubmissionReason.fromString(null),
        equals(ExamSubmissionReason.studentSubmitted),
      );
      expect(
        ExamSubmissionReason.fromString('unknown_reason'),
        equals(ExamSubmissionReason.studentSubmitted),
      );

      // Value getters
      expect(ExamSubmissionReason.studentSubmitted.value, equals('student_submitted'));
      expect(ExamSubmissionReason.timeExpired.value, equals('time_expired'));
      expect(ExamSubmissionReason.forcedExit.value, equals('forced_exit'));
      expect(ExamSubmissionReason.securityViolations.value, equals('security_violations'));
      expect(ExamSubmissionReason.tabClosed.value, equals('tab_closed'));
      expect(ExamSubmissionReason.systemTimeout.value, equals('system_timeout'));
    });

    test('ExamAttemptModel parses submission_reason and serializes toJson accurately', () {
      final jsonWithReason = {
        'id': 'att_1',
        'exam_id': 'exam_1',
        'exam_version_id': 'v_1',
        'student_id': 'stud_1',
        'started_at': '2026-10-13T10:00:00.000Z',
        'submitted_at': '2026-10-13T10:30:00.000Z',
        'status': 'expired',
        'submission_reason': 'time_expired',
        'score': 75,
        'percentage': 75.0,
      };

      final model = ExamAttemptModel.fromJson(jsonWithReason);

      expect(model.id, equals('att_1'));
      expect(model.status, equals(AttemptStatus.expired));
      expect(model.submissionReason, equals(ExamSubmissionReason.timeExpired));
      expect(model.score, equals(75));

      final serialized = model.toJson();
      expect(serialized['submission_reason'], equals('time_expired'));
      expect(serialized['status'], equals('expired'));
    });

    test('ExamAttemptModel falls back safely when submission_reason is omitted', () {
      final jsonLegacy = {
        'id': 'att_2',
        'exam_id': 'exam_1',
        'exam_version_id': 'v_1',
        'student_id': 'stud_1',
        'started_at': '2026-10-13T10:00:00.000Z',
        'status': 'submitted',
      };

      final model = ExamAttemptModel.fromJson(jsonLegacy);

      expect(model.submissionReason, equals(ExamSubmissionReason.studentSubmitted));
    });

    test('ExamAttemptEntity copyWith properly modifies submissionReason', () {
      final entity = ExamAttemptEntity(
        id: 'att_3',
        examId: 'exam_1',
        examVersionId: 'v_1',
        studentId: 'stud_1',
        startedAt: DateTime.utc(2026, 10, 13, 10),
        status: AttemptStatus.inProgress,
        submissionReason: ExamSubmissionReason.studentSubmitted,
      );

      final updated = entity.copyWith(
        status: AttemptStatus.expired,
        submissionReason: ExamSubmissionReason.forcedExit,
      );

      expect(updated.status, equals(AttemptStatus.expired));
      expect(updated.submissionReason, equals(ExamSubmissionReason.forcedExit));
    });
  });
}
