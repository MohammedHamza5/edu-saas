import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/chapter_entity.dart';

/// Card containing Lesson Title input and Target Academic Chapter dropdown.
class LessonEditorTitleAndChapterCard extends StatelessWidget {
  final TextEditingController titleController;
  final List<ChapterEntity> chapters;
  final String? selectedChapterId;
  final bool isLoadingChapters;
  final ValueChanged<String?> onChapterChanged;
  final VoidCallback onQuickCreateChapter;

  const LessonEditorTitleAndChapterCard({
    super.key,
    required this.titleController,
    required this.chapters,
    required this.selectedChapterId,
    required this.isLoadingChapters,
    required this.onChapterChanged,
    required this.onQuickCreateChapter,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Lesson Title Card ──────────────────────────────────────────────
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.lessonTitleLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                AppTextField(
                  controller: titleController,
                  hintText: l10n.lessonTitleHint,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // ── Academic Chapter Selector Card ──────────────────────────────────
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.targetChapterLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onQuickCreateChapter,
                      icon: const Icon(Icons.add_rounded, size: 14),
                      label: Text(
                        l10n.quickCreateChapter,
                        style: const TextStyle(fontSize: 11),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s10),
                if (isLoadingChapters)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  DropdownButtonFormField<String?>(
                    initialValue: chapters.any((c) => c.id == selectedChapterId)
                        ? selectedChapterId
                        : null,
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.noChapterOption),
                      ),
                      for (final ch in chapters)
                        DropdownMenuItem<String?>(
                          value: ch.id,
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                size: 16,
                                color: ch.isPublished
                                    ? AppColors.primary
                                    : AppColors.warning,
                              ),
                              const SizedBox(width: 8),
                              Text(ch.title),
                              if (!ch.isPublished) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '(${l10n.chapterVisibilityDraft})',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                    onChanged: onChapterChanged,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Card containing Lecture Visibility (Published vs Draft switch).
class LessonEditorVisibilityCard extends StatelessWidget {
  final bool isPublished;
  final ValueChanged<bool> onPublishChanged;

  const LessonEditorVisibilityCard({
    super.key,
    required this.isPublished,
    required this.onPublishChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isPublished
                        ? AppColors.success
                        : AppColors.warning)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPublished
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: isPublished
                    ? AppColors.success
                    : AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.s14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.lessonStatusLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPublished
                        ? l10n.lessonStatusPublishedDesc
                        : l10n.lessonStatusDraftDesc,
                    style: TextStyle(
                      fontSize: 11,
                      color: isPublished
                          ? AppColors.textSecondary
                          : AppColors.warning,
                      fontWeight: isPublished
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isPublished,
              onChanged: onPublishChanged,
              activeThumbColor: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}
