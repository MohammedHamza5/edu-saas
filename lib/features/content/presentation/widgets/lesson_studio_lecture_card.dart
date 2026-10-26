import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/chapter_entity.dart';
import '../models/lesson_studio_models.dart';

/// Individual lecture card displayed within the Lesson Studio staging workspace.
/// Allows customizing title, chapter, attached quizzes, and PDF materials.
class LessonStudioLectureCard extends StatelessWidget {
  final StagedLecture staged;
  final int index;
  final List<ChapterEntity> chapters;
  final bool isOnlyOne;
  final List<Map<String, dynamic>> availableExams;
  final VoidCallback onRemoveVideo;
  final VoidCallback onPickFromLibrary;
  final VoidCallback onPickPdf;
  final ValueChanged<String?> onChapterChanged;
  final ValueChanged<bool> onPublishChanged;
  final void Function(String examId, String examTitle) onAddExam;
  final ValueChanged<int> onRemoveExam;
  final VoidCallback onRemovePdf;

  const LessonStudioLectureCard({
    super.key,
    required this.staged,
    required this.index,
    required this.chapters,
    required this.isOnlyOne,
    required this.availableExams,
    required this.onRemoveVideo,
    required this.onPickFromLibrary,
    required this.onPickPdf,
    required this.onChapterChanged,
    required this.onPublishChanged,
    required this.onAddExam,
    required this.onRemoveExam,
    required this.onRemovePdf,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Drag handle, Index, Thumbnail, Editable Title, Duration badge, Close
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!isOnlyOne) ...[
                  ReorderableDragStartListener(
                    index: index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                ],

                // Thumbnail
                Container(
                  width: 72,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                    image: staged.video.thumbnailUrl != null
                        ? DecorationImage(
                            image: NetworkImage(staged.video.thumbnailUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),

                // Editable Title Field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: staged.titleController,
                              labelText: l10n.lessonTitleLabel,
                              hintText: staged.video.title,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Duration badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              staged.video.formattedDuration,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),

                // Remove video button
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.error,
                  tooltip: l10n.cancel,
                  onPressed: onRemoveVideo,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s12),

            // Row 2: Target Chapter, Quiz Section, PDF Handout, Publish Switch
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                return Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // 1. Target Chapter Dropdown
                    SizedBox(
                      width: isNarrow ? double.infinity : 210,
                      child: DropdownButtonFormField<String?>(
                        value: chapters.any((c) => c.id == staged.chapterId)
                            ? staged.chapterId
                            : null,
                        isDense: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.folder_outlined, size: 16),
                          labelText: l10n.targetChapterLabel,
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
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              l10n.noChapterOption,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                          for (final ch in chapters)
                            DropdownMenuItem<String?>(
                              value: ch.id,
                              child: Text(
                                ch.title,
                                style: const TextStyle(fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: onChapterChanged,
                      ),
                    ),

                    // 2. Quiz / Exam Section
                    SizedBox(
                      width: isNarrow ? double.infinity : 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (staged.attachedExams.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (int i = 0;
                                    i < staged.attachedExams.length;
                                    i++)
                                  InputChip(
                                    avatar: Icon(
                                      staged.attachedExams[i].isRequired
                                          ? Icons.lock_rounded
                                          : Icons.quiz_outlined,
                                      size: 13,
                                      color: AppColors.primary,
                                    ),
                                    label: Text(
                                      staged.attachedExams[i].examTitle.isNotEmpty
                                          ? staged.attachedExams[i].examTitle
                                          : 'اختبار #${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.close_rounded,
                                      size: 13,
                                    ),
                                    onDeleted: () => onRemoveExam(i),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          Builder(
                            builder: (ctx) {
                              final unattached = availableExams.where(
                                (e) => !staged.attachedExams.any(
                                  (a) => a.examId == e['id'],
                                ),
                              ).toList();

                              return DropdownButtonFormField<String?>(
                                value: null,
                                isDense: true,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.quiz_outlined,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  labelText: staged.attachedExams.isEmpty
                                      ? l10n.mandatoryQuizSection
                                      : '+ ${l10n.addQuizToLessonAction}',
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
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      staged.attachedExams.isEmpty
                                          ? l10n.noQuizAttached
                                          : '+ ${l10n.addQuizToLessonAction}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: staged.attachedExams.isEmpty
                                            ? AppColors.textMuted
                                            : AppColors.primary,
                                        fontWeight: staged.attachedExams.isEmpty
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  ...unattached.map(
                                    (exam) => DropdownMenuItem<String?>(
                                      value: exam['id'] as String?,
                                      child: Text(
                                        exam['title'] as String? ?? '',
                                        style: const TextStyle(fontSize: 11.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    final match = availableExams.firstWhere(
                                      (e) => e['id'] == val,
                                      orElse: () => {'title': ''},
                                    );
                                    onAddExam(
                                      val,
                                      match['title'] as String? ?? '',
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // 3. PDF Handout Section (Prominent Chip with Replace and Delete)
                    if (!staged.hasPdf)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: onPickFromLibrary,
                            icon: const Icon(
                              Icons.folder_shared_rounded,
                              size: 15,
                              color: Color(0xFFEA580C),
                            ),
                            label: Text(
                              l10n.selectFromMaterialsLibrary,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFEA580C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: const Color(0xFFEA580C).withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: onPickPdf,
                            icon: const Icon(
                              Icons.upload_file_rounded,
                              size: 15,
                            ),
                            label: Text(
                              l10n.uploadFromDeviceAction,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMedium,
                          ),
                          border: Border.all(
                            color: const Color(0xFFEA580C).withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                              color: Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    staged.pdfDisplayName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEA580C),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (staged.formattedPdfSize != null)
                                    Text(
                                      staged.formattedPdfSize!,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: const Color(
                                          0xFFEA580C,
                                        ).withValues(alpha: 0.8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Quick Replace Menu
                            PopupMenuButton<String>(
                              tooltip: l10n.changeAction,
                              icon: const Icon(
                                Icons.swap_horiz_rounded,
                                size: 16,
                                color: Color(0xFFEA580C),
                              ),
                              onSelected: (val) {
                                if (val == 'library') {
                                  onPickFromLibrary();
                                } else if (val == 'upload') {
                                  onPickPdf();
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'library',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.folder_shared_rounded,
                                        size: 16,
                                        color: Color(0xFFEA580C),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.selectFromMaterialsLibrary,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'upload',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.upload_file_rounded,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.uploadFromDeviceAction,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Remove Button
                            InkWell(
                              onTap: onRemovePdf,
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 4. Publish Toggle Switch
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: staged.isPublished
                            ? AppColors.success.withValues(alpha: 0.08)
                            : AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                        border: Border.all(
                          color: staged.isPublished
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            staged.isPublished
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 16,
                            color: staged.isPublished
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            staged.isPublished
                                ? l10n.statusPublished
                                : l10n.statusDraft,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: staged.isPublished
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                          Switch(
                            value: staged.isPublished,
                            activeColor: AppColors.success,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: onPublishChanged,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
