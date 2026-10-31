import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../models/lesson_studio_models.dart';

/// Quiz / Exam selection and chip list within a staged lecture card
class LessonStudioLectureQuizSection extends StatelessWidget {
  final StagedLecture staged;
  final bool isNarrow;
  final List<Map<String, dynamic>> availableExams;
  final void Function(String examId, String examTitle) onAddExam;
  final ValueChanged<int> onRemoveExam;

  const LessonStudioLectureQuizSection({
    super.key,
    required this.staged,
    required this.isNarrow,
    required this.availableExams,
    required this.onAddExam,
    required this.onRemoveExam,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SizedBox(
      width: isNarrow ? double.infinity : 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (staged.attachedExams.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (int i = 0; i < staged.attachedExams.length; i++)
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
                initialValue: null,
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
    );
  }
}
