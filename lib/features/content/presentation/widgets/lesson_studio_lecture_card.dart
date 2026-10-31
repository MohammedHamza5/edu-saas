import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/chapter_entity.dart';
import '../models/lesson_studio_models.dart';
import 'lesson_studio_lecture_header_row.dart';
import 'lesson_studio_lecture_pdf_section.dart';
import 'lesson_studio_lecture_quiz_section.dart';

/// Individual lecture card displayed within the Lesson Studio staging workspace.
/// Coordinates lecture title, chapter selection, attached quizzes, and PDF materials.
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
            LessonStudioLectureHeaderRow(
              staged: staged,
              index: index,
              isOnlyOne: isOnlyOne,
              onRemoveVideo: onRemoveVideo,
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
                        initialValue:
                            chapters.any((c) => c.id == staged.chapterId)
                                ? staged.chapterId
                                : null,
                        isDense: true,
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.folder_outlined, size: 16),
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
                    LessonStudioLectureQuizSection(
                      staged: staged,
                      isNarrow: isNarrow,
                      availableExams: availableExams,
                      onAddExam: onAddExam,
                      onRemoveExam: onRemoveExam,
                    ),

                    // 3. PDF Handout Section
                    LessonStudioLecturePdfSection(
                      staged: staged,
                      onPickFromLibrary: onPickFromLibrary,
                      onPickPdf: onPickPdf,
                      onRemovePdf: onRemovePdf,
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
                            activeThumbColor: AppColors.success,
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
