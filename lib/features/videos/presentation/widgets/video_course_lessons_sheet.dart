import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';

/// Modal bottom sheet displaying the sequence of course lessons with completion
/// status, current lesson indicator, and lock states.
class VideoCourseLessonsSheet extends StatelessWidget {
  const VideoCourseLessonsSheet({
    super.key,
    required this.courseLessons,
    required this.currentVideoId,
    this.groupName,
    required this.onLessonTap,
  });

  final List<LessonAssignmentEntity> courseLessons;
  final String currentVideoId;
  final String? groupName;
  final void Function(
    LessonAssignmentEntity lesson,
    int index,
    int totalCount,
  ) onLessonTap;

  /// Convenience static launcher for the bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required List<LessonAssignmentEntity> courseLessons,
    required String currentVideoId,
    String? groupName,
    required void Function(
      LessonAssignmentEntity lesson,
      int index,
      int totalCount,
    ) onLessonTap,
  }) {
    if (courseLessons.isEmpty) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => VideoCourseLessonsSheet(
        courseLessons: courseLessons,
        currentVideoId: currentVideoId,
        groupName: groupName,
        onLessonTap: onLessonTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount =
        courseLessons.where((l) => l.isEffectivelyCompleted).length;
    final totalCount = courseLessons.length;
    final pct = totalCount > 0 ? ((completedCount / totalCount) * 100).toInt() : 0;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.s20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName ?? context.l10n.courseLessonsTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.lessonsCompletedRatio(
                        completedCount,
                        totalCount,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalCount > 0 ? completedCount / totalCount : 0,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s8),

          // Lessons List
          Flexible(
            child: ListView.separated(
              
              shrinkWrap: true,
              itemCount: courseLessons.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (ctx, i) {
                final item = courseLessons[i];
                final isCurrent = item.contentId == currentVideoId;
                final isCompleted = item.isEffectivelyCompleted;
                final isLocked = item.isLocked;

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: isCompleted
                        ? AppColors.success.withAlpha(25)
                        : isCurrent
                        ? AppColors.primary.withAlpha(25)
                        : isLocked
                        ? AppColors.surfaceVariant
                        : AppColors.primary.withAlpha(15),
                    child: Icon(
                      isCompleted
                          ? Icons.check_rounded
                          : isCurrent
                          ? Icons.play_arrow_rounded
                          : isLocked
                          ? Icons.lock_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 14,
                      color: isCompleted
                          ? AppColors.success
                          : isCurrent
                          ? AppColors.primary
                          : isLocked
                          ? AppColors.textMuted
                          : AppColors.primary,
                    ),
                  ),
                  title: Text(
                    '${i + 1}. ${item.title}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent
                          ? AppColors.primary
                          : isLocked
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: isCurrent
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull,
                            ),
                          ),
                          child: Text(
                            context.l10n.statusInProgress,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : isCompleted
                      ? const Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: AppColors.success,
                        )
                      : isLocked
                      ? const Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        )
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    if (!isCurrent) {
                      onLessonTap(item, i + 1, totalCount);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
