import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';

/// Top header bar for teacher course syllabus showing stats and primary actions (responsive)
class TeacherCourseHeaderBar extends StatelessWidget {
  final bool isMobile;
  final String? groupName;
  final List<ContentEntity> lessons;
  final List<ChapterEntity> chapters;
  final int publishedCount;
  final int draftCount;
  final bool isAllCollapsed;
  final VoidCallback onToggleAllChaptersCollapse;
  final Widget bulkVisibilityMenu;
  final VoidCallback onOpenGroupAnalytics;
  final VoidCallback onAddNewChapter;
  final VoidCallback onAddLesson;

  const TeacherCourseHeaderBar({
    super.key,
    required this.isMobile,
    required this.groupName,
    required this.lessons,
    required this.chapters,
    required this.publishedCount,
    required this.draftCount,
    required this.isAllCollapsed,
    required this.onToggleAllChaptersCollapse,
    required this.bulkVisibilityMenu,
    required this.onOpenGroupAnalytics,
    required this.onAddNewChapter,
    required this.onAddLesson,
  });

  Widget _buildBannerStat({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (!isMobile) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  groupName ?? l10n.courseBuilderTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s4,
                  children: [
                    _buildBannerStat(
                      icon: Icons.video_collection_rounded,
                      label: l10n.nLessonsCount(lessons.length),
                      color: AppColors.primary,
                    ),
                    _buildBannerStat(
                      icon: Icons.check_circle_outline_rounded,
                      label: l10n.publishedCountBadge(publishedCount),
                      color: AppColors.success,
                    ),
                    if (draftCount > 0)
                      _buildBannerStat(
                        icon: Icons.visibility_off_outlined,
                        label: l10n.draftCountBadge(draftCount),
                        color: AppColors.warning,
                      ),
                    _buildBannerStat(
                      icon: Icons.picture_as_pdf_rounded,
                      label:
                          '${lessons.where((l) => l.file != null).length} ${l10n.hasStudyMaterial}',
                      color: const Color(0xFFEA580C),
                    ),
                    _buildBannerStat(
                      icon: Icons.quiz_rounded,
                      label:
                          '${lessons.where((l) => l.associatedExamTitle != null).length} ${l10n.hasLessonQuiz}',
                      color: AppColors.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          IconButton(
            tooltip: isAllCollapsed
                ? l10n.expandAllChapters
                : l10n.collapseAllChapters,
            icon: Icon(
              isAllCollapsed
                  ? Icons.unfold_more_rounded
                  : Icons.unfold_less_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: onToggleAllChaptersCollapse,
          ),
          const SizedBox(width: AppSpacing.s4),
          bulkVisibilityMenu,
          const SizedBox(width: AppSpacing.s8),
          AppButton(
            text: l10n.groupAnalytics,
            icon: Icons.insights_rounded,
            variant: AppButtonVariant.outlined,
            onPressed: onOpenGroupAnalytics,
          ),
          const SizedBox(width: AppSpacing.s8),
          AppButton(
            text: l10n.addNewChapter,
            icon: Icons.create_new_folder_rounded,
            variant: AppButtonVariant.outlined,
            onPressed: onAddNewChapter,
          ),
          const SizedBox(width: AppSpacing.s8),
          AppButton(
            text: l10n.addLessonButton,
            icon: Icons.add_rounded,
            onPressed: onAddLesson,
          ),
        ],
      );
    }

    // Mobile Column Layout
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                groupName ?? l10n.courseBuilderTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: isAllCollapsed
                  ? l10n.expandAllChapters
                  : l10n.collapseAllChapters,
              icon: Icon(
                isAllCollapsed
                    ? Icons.unfold_more_rounded
                    : Icons.unfold_less_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
              onPressed: onToggleAllChaptersCollapse,
            ),
            const SizedBox(width: 4),
            bulkVisibilityMenu,
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              onPressed: onOpenGroupAnalytics,
              tooltip: l10n.groupAnalytics,
              icon: const Icon(
                Icons.insights_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(8),
              ),
            ),
            const SizedBox(width: AppSpacing.s6),
            Expanded(
              child: AppButton(
                text: l10n.addNewChapter,
                icon: Icons.create_new_folder_rounded,
                variant: AppButtonVariant.outlined,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: onAddNewChapter,
              ),
            ),
            const SizedBox(width: AppSpacing.s6),
            Expanded(
              child: AppButton(
                text: l10n.addLessonButton,
                icon: Icons.add_rounded,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onPressed: onAddLesson,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: AppSpacing.s10,
          runSpacing: AppSpacing.s4,
          children: [
            _buildBannerStat(
              icon: Icons.video_collection_rounded,
              label: l10n.nLessonsCount(lessons.length),
              color: AppColors.primary,
            ),
            _buildBannerStat(
              icon: Icons.check_circle_outline_rounded,
              label: l10n.publishedCountBadge(publishedCount),
              color: AppColors.success,
            ),
            if (draftCount > 0)
              _buildBannerStat(
                icon: Icons.visibility_off_outlined,
                label: l10n.draftCountBadge(draftCount),
                color: AppColors.warning,
              ),
            _buildBannerStat(
              icon: Icons.picture_as_pdf_rounded,
              label:
                  '${lessons.where((l) => l.file != null).length} ${l10n.hasStudyMaterial}',
              color: const Color(0xFFEA580C),
            ),
            _buildBannerStat(
              icon: Icons.quiz_rounded,
              label:
                  '${lessons.where((l) => l.associatedExamTitle != null).length} ${l10n.hasLessonQuiz}',
              color: AppColors.success,
            ),
          ],
        ),
      ],
    );
  }
}
