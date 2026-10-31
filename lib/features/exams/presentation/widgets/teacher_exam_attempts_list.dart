import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import 'student_attempts_group_card.dart';

class TeacherExamAttemptsList extends StatelessWidget {
  final List<ExamAttemptEntity> attempts;
  final ExamEntity exam;
  final ScrollController scrollController;
  final ExamsCubit cubit;
  final bool isLoadingMore;
  final DateFormat dateFormat;

  const TeacherExamAttemptsList({
    super.key,
    required this.attempts,
    required this.exam,
    required this.scrollController,
    required this.cubit,
    required this.isLoadingMore,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<ExamAttemptEntity>.from(attempts)
      ..sort((a, b) {
        final dateA = a.submittedAt ?? a.startedAt;
        final dateB = b.submittedAt ?? b.startedAt;
        return dateB.compareTo(dateA);
      });

    final Map<String, StudentAttemptsGroup> groupsMap = {};
    for (final att in sorted) {
      final key = att.studentId.isNotEmpty
          ? att.studentId
          : (att.studentName ?? 'unknown');
      if (!groupsMap.containsKey(key)) {
        groupsMap[key] = StudentAttemptsGroup(
          studentId: att.studentId,
          studentName: att.studentName != null &&
                  att.studentName!.trim().isNotEmpty
              ? att.studentName!.trim()
              : context.l10n.studentFallbackName,
          attempts: [],
        );
      }
      groupsMap[key]!.attempts.add(att);
    }

    final groups = groupsMap.values.toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 200) {
          cubit.loadMoreExamAttempts();
        }
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        cacheExtent: 350.0,
        padding: const EdgeInsets.all(AppSpacing.s16),
        itemCount: groups.length + 1 + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      context.l10n.studentsCountSummary(groups.length),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.history_edu_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      context.l10n.totalAttemptsSummary(attempts.length),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (index == groups.length + 1) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
              child: Center(
                child: AppLoadingView.compact(size: 24),
              ),
            );
          }

          final group = groups[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: StudentAttemptsGroupCard(
              group: group,
              exam: exam,
              dateFormat: dateFormat,
            ),
          );
        },
      ),
    );
  }
}
