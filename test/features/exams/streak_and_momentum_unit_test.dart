import 'package:edu_saas/features/exams/domain/entities/academic_momentum_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pillar 4: Academic Momentum & Streaks Unit Tests', () {
    final now = DateTime(2026, 10, 21, 14, 0); // Today: 2026-10-21
    final yesterday = DateTime(2026, 10, 20, 10, 0);
    final twoDaysAgo = DateTime(2026, 10, 19, 12, 0);

    ExamEntity createExamWithAttempt({
      required String id,
      required DateTime startedAt,
      required DateTime submittedAt,
      required int score,
      required int maxScore,
      int durationMinutes = 60,
    }) {
      return ExamEntity(
        id: id, contentId: 'c_$id', tenantId: 't1', groupId: 'g1',
        title: 'Exam $id', durationMinutes: durationMinutes, maxScore: maxScore,
        createdAt: startedAt, updatedAt: startedAt,
        myLatestAttempt: ExamAttemptEntity(
          id: 'att_$id', examId: id, examVersionId: 'v1', studentId: 's1',
          startedAt: startedAt, submittedAt: submittedAt,
          status: AttemptStatus.submitted, score: score,
          percentage: (score / maxScore) * 100,
        ),
      );
    }

    test('Computes currentStreak and longestStreak correctly from consecutive days', () {
      final exam1 = createExamWithAttempt(
        id: 'e1', startedAt: twoDaysAgo, submittedAt: twoDaysAgo, score: 80, maxScore: 100,
      );
      final exam2 = createExamWithAttempt(
        id: 'e2', startedAt: yesterday, submittedAt: yesterday, score: 85, maxScore: 100,
      );
      final exam3 = createExamWithAttempt(
        id: 'e3', startedAt: now, submittedAt: now, score: 90, maxScore: 100,
      );

      final momentum = AcademicMomentumEntity.calculate(
        exams: [exam1, exam2, exam3],
        referenceDate: now,
      );

      expect(momentum.currentStreakDays, 3);
      expect(momentum.longestStreakDays, 3);
      expect(momentum.isTodayActive, true);
    });

    test('Maintains streak if active yesterday but not yet today', () {
      final exam1 = createExamWithAttempt(
        id: 'e1', startedAt: twoDaysAgo, submittedAt: twoDaysAgo, score: 80, maxScore: 100,
      );
      final exam2 = createExamWithAttempt(
        id: 'e2', startedAt: yesterday, submittedAt: yesterday, score: 85, maxScore: 100,
      );

      final momentum = AcademicMomentumEntity.calculate(
        exams: [exam1, exam2],
        referenceDate: now,
      );

      expect(momentum.currentStreakDays, 2);
      expect(momentum.isTodayActive, false);
    });

    test('Predicted SAT Math score band calculates accurately with 2+ exams', () {
      final exam1 = createExamWithAttempt(
        id: 'e1', startedAt: yesterday, submittedAt: yesterday, score: 90, maxScore: 100,
      );
      final exam2 = createExamWithAttempt(
        id: 'e2', startedAt: now, submittedAt: now, score: 80, maxScore: 100,
      );

      final momentum = AcademicMomentumEntity.calculate(
        exams: [exam1, exam2],
        referenceDate: now,
      );

      // Average = 85.0% -> Base = 200 + 0.85 * 600 = 710 -> Band = [680, 740]
      expect(momentum.hasPredictedScore, true);
      expect(momentum.predictedScoreLow, 680);
      expect(momentum.predictedScoreHigh, 740);
    });

    test('Predicted SAT score returns null when fewer than 2 exams completed', () {
      final exam1 = createExamWithAttempt(
        id: 'e1', startedAt: now, submittedAt: now, score: 95, maxScore: 100,
      );

      final momentum = AcademicMomentumEntity.calculate(
        exams: [exam1],
        referenceDate: now,
      );

      expect(momentum.hasPredictedScore, false);
      expect(momentum.predictedScoreLow, isNull);
      expect(momentum.predictedScoreHigh, isNull);
    });

    test('Badges unlock conditions evaluate accurately', () {
      // 1. Gauntlet Slayer: 0 unresolved and > 0 resolved
      final m1 = AcademicMomentumEntity.calculate(
        exams: [], unresolvedMistakes: 0, resolvedMistakes: 5, referenceDate: now,
      );
      final gauntletBadge = m1.badges.firstWhere((b) => b.type == AcademicBadgeType.gauntletSlayer);
      expect(gauntletBadge.isUnlocked, true);

      // 2. High Achiever: 2+ exams with avg >= 90%
      final e1 = createExamWithAttempt(
        id: 'e1', startedAt: yesterday, submittedAt: yesterday, score: 95, maxScore: 100,
      );
      final e2 = createExamWithAttempt(
        id: 'e2', startedAt: now, submittedAt: now, score: 95, maxScore: 100,
      );
      final m2 = AcademicMomentumEntity.calculate(
        exams: [e1, e2], referenceDate: now,
      );
      final highAchieverBadge = m2.badges.firstWhere((b) => b.type == AcademicBadgeType.highAchiever);
      expect(highAchieverBadge.isUnlocked, true);

      // 3. Speed Demon: finished in <= 50% of duration with >= 85%
      final speedExam = createExamWithAttempt(
        id: 'e3', startedAt: now, submittedAt: now.add(const Duration(minutes: 20)),
        score: 90, maxScore: 100, durationMinutes: 60,
      );
      final m3 = AcademicMomentumEntity.calculate(
        exams: [speedExam], referenceDate: now,
      );
      final speedBadge = m3.badges.firstWhere((b) => b.type == AcademicBadgeType.speedDemon);
      expect(speedBadge.isUnlocked, true);
    });
  });
}
