import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/chapter_entity.dart';
import '../models/lesson_studio_models.dart';

/// Staging deck displaying selected lectures, batch settings, and reorderable cards
class LessonStudioStagingDeck extends StatelessWidget {
  final List<ChapterEntity> chapters;
  final List<String> stagedOrder;
  final Map<String, StagedLecture> stagedLectures;
  final String? batchGlobalChapterId;
  final bool batchGlobalPublished;
  final bool isSaving;
  final VoidCallback onClearSelection;
  final ValueChanged<String?> onBatchChapterChanged;
  final VoidCallback onQuickCreateChapter;
  final ValueChanged<bool> onBatchPublishChanged;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onSaveUnified;
  final Widget Function(
    BuildContext context,
    StagedLecture staged,
    int index,
    bool isOnlyOne,
  ) cardBuilder;

  const LessonStudioStagingDeck({
    super.key,
    required this.chapters,
    required this.stagedOrder,
    required this.stagedLectures,
    required this.batchGlobalChapterId,
    required this.batchGlobalPublished,
    required this.isSaving,
    required this.onClearSelection,
    required this.onBatchChapterChanged,
    required this.onQuickCreateChapter,
    required this.onBatchPublishChanged,
    required this.onReorder,
    required this.onSaveUnified,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = stagedOrder.length;

    return Column(
      children: [
        // Global Toolbar & Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.video_library_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              count == 1
                                  ? l10n.lessonStudioTitle
                                  : l10n.batchModeTitle(count),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                count == 1
                                    ? l10n.singleVideoModeBadge
                                    : l10n.selectedVideosBadge(count),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          count > 1
                              ? l10n.reorderLecturesHint
                              : l10n.lessonStudioSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Clear all selections
                  TextButton.icon(
                    onPressed: onClearSelection,
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: Text(l10n.clearSelection),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s14),

              // Global Batch Assignment Bar (Chapter & Publish)
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: chapters.any((c) => c.id == batchGlobalChapterId)
                                ? batchGlobalChapterId
                                : null,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: count > 1
                                  ? l10n.applyChapterToAll
                                  : l10n.targetChapterLabel,
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
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
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 200,
                                        ),
                                        child: Text(
                                          ch.title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: onBatchChapterChanged,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        IconButton(
                          icon: const Icon(Icons.add_rounded),
                          tooltip: l10n.quickCreateChapter,
                          onPressed: onQuickCreateChapter,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),

                  // Global Publish / Draft Switch
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          batchGlobalPublished
                              ? l10n.publishAllBatch
                              : l10n.draftAllBatch,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: batchGlobalPublished
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: batchGlobalPublished,
                          activeColor: AppColors.success,
                          onChanged: onBatchPublishChanged,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Staging List with Drag & Drop Reordering
        Expanded(
          child: count == 1
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: cardBuilder(
                        context,
                        stagedLectures[stagedOrder.first]!,
                        0,
                        true,
                      ),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  itemCount: stagedOrder.length,
                  onReorder: onReorder,
                  itemBuilder: (ctx, index) {
                    final videoId = stagedOrder[index];
                    final staged = stagedLectures[videoId];
                    if (staged == null) {
                      return SizedBox.shrink(key: ValueKey('empty_$videoId'));
                    }
                    return KeyedSubtree(
                      key: ValueKey(videoId),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                        child: cardBuilder(
                          ctx,
                          staged,
                          index,
                          false,
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Unified Action Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Text(
                count == 1
                    ? l10n.singleVideoModeBadge
                    : l10n.selectedVideosBadge(count),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              AppButton(
                text: count == 1
                    ? l10n.saveLectureButton
                    : l10n.addBatchLecturesButton(count),
                icon: count == 1 ? Icons.save_rounded : Icons.rocket_launch_rounded,
                isLoading: isSaving,
                onPressed: onSaveUnified,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
