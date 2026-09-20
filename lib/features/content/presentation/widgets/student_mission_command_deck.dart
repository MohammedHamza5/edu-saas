import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';

/// Hero Academic Mission Command Deck for Students.
///
/// Anchors the top of the curriculum page to eliminate friction and focus
/// student cognitive energy on exactly what to do next.
class StudentMissionCommandDeck extends StatelessWidget {
  final ContentEntity? nextLesson;
  final int? nextLessonIndex;
  final int completedCount;
  final int totalCount;
  final int overallPercentage;
  final String groupName;
  final VoidCallback? onResume;

  const StudentMissionCommandDeck({
    super.key,
    required this.nextLesson,
    this.nextLessonIndex,
    required this.completedCount,
    required this.totalCount,
    required this.overallPercentage,
    required this.groupName,
    this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllCompleted = totalCount > 0 && completedCount >= totalCount;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s12, bottom: AppSpacing.s16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: isAllCompleted
              ? [
                  AppColors.success.withAlpha(25),
                  AppColors.surfaceVariant.withAlpha(30),
                  AppColors.surface,
                ]
              : [
                  AppColors.primary.withAlpha(28),
                  AppColors.surfaceVariant.withAlpha(50),
                  AppColors.surface,
                ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: isAllCompleted
              ? AppColors.success.withAlpha(70)
              : AppColors.primary.withAlpha(70),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAllCompleted ? AppColors.success : AppColors.primary)
                .withAlpha(18),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        child: Stack(
          children: [
            // Mathematical ambient grid watermark in background
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.04,
                child: Icon(
                  Icons.functions_rounded,
                  size: 160,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: isAllCompleted
                  ? _buildAllCompletedView(context, theme)
                  : _buildActiveMissionView(context, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveMissionView(BuildContext context, ThemeData theme) {
    final lesson = nextLesson;
    final index = nextLessonIndex ?? 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Meta Row: Group Name & Progress Indicator Pill
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.flag_circle_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    context.l10n.currentMissionTitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Completion ratio badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 13,
                    color: overallPercentage > 0
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$completedCount / $totalCount ($overallPercentage%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: overallPercentage > 0
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s14),

        // Middle Section: Lesson Number + Title + Big Action
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 640;

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.l10n.lectureNumberBadge(index),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (lesson?.type != null)
                      Text(
                        lesson!.type.localizedLabel(context),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  lesson?.title ?? context.l10n.startNextLessonAction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.currentMissionSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            );

            final resumeButton = ElevatedButton.icon(
              onPressed: onResume,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                context.l10n.resumeLessonAction,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 3,
                shadowColor: AppColors.primary.withAlpha(100),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s20,
                  vertical: AppSpacing.s12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
              ),
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: AppSpacing.s16),
                  resumeButton,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: AppSpacing.s14),
                resumeButton,
              ],
            );
          },
        ),

        const SizedBox(height: AppSpacing.s16),

        // Bottom: Smooth Mathematical Progress Track
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: totalCount > 0 ? (completedCount / totalCount) : 0.0,
            backgroundColor: AppColors.border.withAlpha(90),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildAllCompletedView(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success.withAlpha(90), width: 2),
          ),
          child: const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.success,
            size: 28,
          ),
        ),
        const SizedBox(width: AppSpacing.s16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.allLecturesCompletedTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.l10n.allLecturesCompletedSubtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
