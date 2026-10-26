import 'package:equatable/equatable.dart';
import 'exam_entity.dart';

enum AcademicBadgeType {
  gauntletSlayer,
  consistencyKing,
  speedDemon,
  highAchiever,
}

class AcademicBadgeEntity extends Equatable {
  final AcademicBadgeType type;
  final bool isUnlocked;

  const AcademicBadgeEntity({
    required this.type,
    required this.isUnlocked,
  });

  @override
  List<Object?> get props => [type, isUnlocked];
}

class AcademicMomentumEntity extends Equatable {
  final int currentStreakDays;
  final int longestStreakDays;
  final bool isTodayActive;
  final int completedExamsCount;
  final double averagePercentage;
  final int? predictedScoreLow;
  final int? predictedScoreHigh;
  final List<AcademicBadgeEntity> badges;

  const AcademicMomentumEntity({
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.isTodayActive,
    required this.completedExamsCount,
    required this.averagePercentage,
    this.predictedScoreLow,
    this.predictedScoreHigh,
    required this.badges,
  });

  bool get hasPredictedScore =>
      predictedScoreLow != null && predictedScoreHigh != null;

  factory AcademicMomentumEntity.calculate({
    required List<ExamEntity> exams,
    int unresolvedMistakes = 0,
    int resolvedMistakes = 0,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // 1. Collect unique activity dates
    final Set<DateTime> activeDates = {};
    final List<double> percentages = [];
    bool hasSpeedDemon = false;

    for (final exam in exams) {
      final attempt = exam.myLatestAttempt;
      if (attempt != null && attempt.isSubmitted) {
        final d = attempt.submittedAt ?? attempt.startedAt;
        activeDates.add(DateTime(d.year, d.month, d.day));

        final pct = attempt.percentage ??
            (exam.maxScore > 0 && attempt.score != null
                ? (attempt.score! / exam.maxScore) * 100
                : 0.0);
        percentages.add(pct);

        // Speed demon check: finished with >= 85% in <= 50% of duration
        if (pct >= 85.0 && exam.durationMinutes > 0 && attempt.submittedAt != null) {
          final elapsedMins =
              attempt.submittedAt!.difference(attempt.startedAt).inMinutes;
          if (elapsedMins <= (exam.durationMinutes / 2).ceil()) {
            hasSpeedDemon = true;
          }
        }
      }
    }

    final isTodayActive = activeDates.contains(today);

    // 2. Compute current and longest streak
    int currentStreak = 0;
    int longestStreak = 0;

    if (activeDates.isNotEmpty) {
      final sortedDates = activeDates.toList()..sort();
      int tempStreak = 1;
      longestStreak = 1;

      for (int i = 1; i < sortedDates.length; i++) {
        if (sortedDates[i].difference(sortedDates[i - 1]).inDays == 1) {
          tempStreak++;
          if (tempStreak > longestStreak) longestStreak = tempStreak;
        } else {
          tempStreak = 1;
        }
      }

      // Check current streak from today or yesterday backwards
      DateTime anchor = isTodayActive ? today : yesterday;
      while (activeDates.contains(anchor)) {
        currentStreak++;
        anchor = anchor.subtract(const Duration(days: 1));
      }
      if (currentStreak > longestStreak) longestStreak = currentStreak;
    }

    // 3. Predicted SAT Score Band (200 - 800)
    int? scoreLow;
    int? scoreHigh;
    double avgPct = 0.0;

    if (percentages.isNotEmpty) {
      avgPct = percentages.reduce((a, b) => a + b) / percentages.length;
      if (percentages.length >= 2) {
        final base = (200 + (avgPct / 100.0) * 600).round();
        scoreLow = (base - 30).clamp(200, 800);
        scoreHigh = (base + 30).clamp(200, 800);
      }
    }

    // 4. Badges qualification
    final badges = [
      AcademicBadgeEntity(
        type: AcademicBadgeType.gauntletSlayer,
        isUnlocked: unresolvedMistakes == 0 && resolvedMistakes > 0,
      ),
      AcademicBadgeEntity(
        type: AcademicBadgeType.consistencyKing,
        isUnlocked: currentStreak >= 5 || longestStreak >= 5,
      ),
      AcademicBadgeEntity(
        type: AcademicBadgeType.speedDemon,
        isUnlocked: hasSpeedDemon,
      ),
      AcademicBadgeEntity(
        type: AcademicBadgeType.highAchiever,
        isUnlocked: percentages.length >= 2 && avgPct >= 90.0,
      ),
    ];

    return AcademicMomentumEntity(
      currentStreakDays: currentStreak,
      longestStreakDays: longestStreak,
      isTodayActive: isTodayActive,
      completedExamsCount: percentages.length,
      averagePercentage: avgPct,
      predictedScoreLow: scoreLow,
      predictedScoreHigh: scoreHigh,
      badges: badges,
    );
  }

  @override
  List<Object?> get props => [
        currentStreakDays,
        longestStreakDays,
        isTodayActive,
        completedExamsCount,
        averagePercentage,
        predictedScoreLow,
        predictedScoreHigh,
        badges,
      ];
}
