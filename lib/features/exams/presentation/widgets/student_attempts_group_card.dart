import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';
import '../pages/exam_review_page.dart';
import '../extensions/exam_ui_extensions.dart';

class StudentAttemptsGroup {
  final String studentId;
  final String studentName;
  final List<ExamAttemptEntity> attempts;

  StudentAttemptsGroup({
    required this.studentId,
    required this.studentName,
    required this.attempts,
  });

  int get count => attempts.length;

  ExamAttemptEntity get latest => attempts.first;

  ExamAttemptEntity get best {
    ExamAttemptEntity top = attempts.first;
    for (final a in attempts) {
      if ((a.percentage ?? a.score?.toDouble() ?? 0) >
          (top.percentage ?? top.score?.toDouble() ?? 0)) {
        top = a;
      }
    }
    return top;
  }
}

class StudentAttemptsGroupCard extends StatefulWidget {
  final StudentAttemptsGroup group;
  final ExamEntity exam;
  final DateFormat dateFormat;

  const StudentAttemptsGroupCard({
    super.key,
    required this.group,
    required this.exam,
    required this.dateFormat,
  });

  @override
  State<StudentAttemptsGroupCard> createState() =>
      StudentAttemptsGroupCardState();
}

class StudentAttemptsGroupCardState extends State<StudentAttemptsGroupCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final exam = widget.exam;
    final best = group.best;
    final latest = group.latest;
    final isPassed = best.isPassed(exam.passingScore);
    final hasMultiple = group.count > 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: _isExpanded
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border,
          width: _isExpanded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: hasMultiple
                ? () => setState(() => _isExpanded = !_isExpanded)
                : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      group.studentName.isNotEmpty
                          ? group.studentName.characters.first
                          : context.l10n.studentInitialFallback,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.studentName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasMultiple) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.history_rounded,
                                      size: 11,
                                      color: Color(0xFF7C3AED),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      context.l10n.studentAttemptsGroupCount(
                                        group.count,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latest.submittedAt != null
                              ? widget.dateFormat.format(latest.submittedAt!)
                              : context.l10n.startedDatePrefix(
                                  widget.dateFormat.format(latest.startedAt),
                                ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (hasMultiple
                                  ? AppColors.success
                                  : latest.status.color)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                        ),
                        child: Text(
                          hasMultiple
                              ? (isPassed
                                  ? context.l10n.attemptStatusSubmitted
                                  : latest.status.localizedLabel(context))
                              : latest.status.localizedLabel(context),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasMultiple
                                ? (isPassed
                                    ? AppColors.success
                                    : latest.status.color)
                                : latest.status.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: latest.submissionReason.color
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              latest.submissionReason.icon,
                              size: 10,
                              color: latest.submissionReason.color,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              latest.submissionReason.localizedLabel(context),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: latest.submissionReason.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (best.score != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          hasMultiple
                              ? context.l10n.highestScoreBadge(
                                  '${best.score}/${exam.maxScore} (${best.percentage?.toStringAsFixed(1)}%)',
                                )
                              : '${latest.score}/${exam.maxScore} (${latest.percentage?.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPassed
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.rate_review_outlined,
                      size: 17,
                      color: AppColors.primary,
                    ),
                    tooltip: context.l10n.viewStudentAnswersAction,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ExamReviewPage(
                            attemptId: latest.id,
                            exam: exam,
                            initialAttempt: latest,
                          ),
                        ),
                      );
                    },
                  ),
                  if (hasMultiple) ...[
                    const SizedBox(width: 2),
                    Icon(
                      _isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: Color(0xFF16A34A),
                    ),
                    tooltip: context.l10n.sendScoreToParentAction,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    onPressed: () {
                      context.push(
                        '/teacher/exams/${exam.id}/parent-dispatch?title=${Uri.encodeComponent(exam.title)}',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded && hasMultiple) ...[
            const Divider(height: 1, color: AppColors.border),
            Container(
              color: AppColors.surfaceVariant.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      context.l10n.allAttemptsHistoryHeader(group.count),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ...group.attempts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final att = entry.value;
                    final attemptNumber = group.count - index;
                    final isThisBest = att.id == best.id;
                    final passed = att.isPassed(exam.passingScore);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isThisBest
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isThisBest
                                    ? AppColors.success.withValues(alpha: 0.4)
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              context.l10n.attemptNumberLabel(attemptNumber),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isThisBest
                                    ? AppColors.success
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              att.submittedAt != null
                                  ? widget.dateFormat.format(att.submittedAt!)
                                  : context.l10n.startedDatePrefix(
                                      widget.dateFormat.format(att.startedAt),
                                    ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          if (att.score != null)
                            Text(
                              '${att.score}/${exam.maxScore} (${att.percentage?.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: passed
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: att.submissionReason.color
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  att.submissionReason.icon,
                                  size: 10,
                                  color: att.submissionReason.color,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  att.submissionReason.localizedLabel(context),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: att.submissionReason.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.rate_review_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            tooltip: context.l10n.viewStudentAnswersAction,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ExamReviewPage(
                                    attemptId: att.id,
                                    exam: exam,
                                    initialAttempt: att,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
