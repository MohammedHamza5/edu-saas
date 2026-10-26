import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import 'teacher_course_header_bar.dart';

/// Top overview summary card for the active course syllabus, including lesson/chapter counters,
/// bulk visibility popups, analytics triggers, and chapter creation.
class TeacherCourseOverviewSection extends StatelessWidget {
  final String? selectedGroupName;
  final List<ContentEntity> lessons;
  final List<ChapterEntity> chapters;
  final bool isAllCollapsed;
  final VoidCallback onToggleAllChaptersCollapse;
  final ValueChanged<bool> onBulkVisibility;
  final VoidCallback onOpenGroupAnalytics;
  final VoidCallback onAddNewChapter;
  final VoidCallback onAddLesson;

  const TeacherCourseOverviewSection({
    super.key,
    required this.selectedGroupName,
    required this.lessons,
    required this.chapters,
    required this.isAllCollapsed,
    required this.onToggleAllChaptersCollapse,
    required this.onBulkVisibility,
    required this.onOpenGroupAnalytics,
    required this.onAddNewChapter,
    required this.onAddLesson,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final publishedCount = lessons.where((l) => l.isPublished).length;
    final draftCount = lessons.where((l) => l.isDraft).length;

    final bulkVisibilityMenu = PopupMenuButton<String>(
      tooltip: l10n.lessonStatusLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: AppColors.textPrimary,
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'publish_all',
          child: Row(
            children: [
              const Icon(
                Icons.visibility_rounded,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(ctx.l10n.publishAllLessonsAction),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'hide_all',
          child: Row(
            children: [
              const Icon(
                Icons.visibility_off_rounded,
                color: AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(ctx.l10n.hideAllLessonsAction),
            ],
          ),
        ),
      ],
      onSelected: (val) {
        if (val == 'publish_all') {
          onBulkVisibility(true);
        } else if (val == 'hide_all') {
          onBulkVisibility(false);
        }
      },
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: LayoutBuilder(
        builder: (context, bannerConstraints) {
          final isDesktop = bannerConstraints.maxWidth >= 1150;
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: TeacherCourseHeaderBar(
              isMobile: !isDesktop,
              groupName: selectedGroupName,
              lessons: lessons,
              chapters: chapters,
              publishedCount: publishedCount,
              draftCount: draftCount,
              isAllCollapsed: isAllCollapsed,
              onToggleAllChaptersCollapse: onToggleAllChaptersCollapse,
              bulkVisibilityMenu: bulkVisibilityMenu,
              onOpenGroupAnalytics: onOpenGroupAnalytics,
              onAddNewChapter: onAddNewChapter,
              onAddLesson: onAddLesson,
            ),
          );
        },
      ),
    );
  }
}
