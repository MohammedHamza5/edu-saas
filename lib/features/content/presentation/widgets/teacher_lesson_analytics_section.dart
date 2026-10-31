import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../domain/entities/content_entity.dart';

/// Presentation section displaying live student views, completion rates, and average quiz scores
/// for a specific lesson/lecture.
class TeacherLessonAnalyticsSection extends StatelessWidget {
  final ContentEntity? lesson;
  final int totalStudents;
  final int totalViews;
  final int completedStudents;
  final double? averageQuizScore;

  const TeacherLessonAnalyticsSection({
    super.key,
    required this.lesson,
    required this.totalStudents,
    required this.totalViews,
    required this.completedStudents,
    required this.averageQuizScore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (lesson == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: AppEmptyView(
            message: l10n.analyticsAvailableAfterPublish,
            icon: Icons.analytics_outlined,
          ),
        ),
      );
    }

    final quizScoreText = averageQuizScore != null
        ? '${averageQuizScore!.toStringAsFixed(1)}%'
        : l10n.noDataDash;

    final quizSubtitle = lesson?.associatedExamId == null
        ? l10n.noAssociatedQuiz
        : (averageQuizScore == null ? l10n.noAttemptsYet : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats Row
          Row(
            children: [
              Expanded(
                child: _LessonMetricCard(
                  title: l10n.totalViews,
                  value: '$totalViews',
                  icon: Icons.visibility_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: _LessonMetricCard(
                  title: l10n.completedLesson,
                  value: '$completedStudents / $totalStudents',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: _LessonMetricCard(
                  title: l10n.averageQuizScore,
                  value: quizScoreText,
                  subtitle: quizSubtitle,
                  icon: Icons.emoji_events_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.studentLessonProgressStats,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: totalStudents > 0
                          ? completedStudents / totalStudents
                          : 0.0,
                      minHeight: 10,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    l10n.overallCompletionRate(
                      totalStudents > 0
                          ? ((completedStudents / totalStudents) * 100).toInt()
                          : 0,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _LessonMetricCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
