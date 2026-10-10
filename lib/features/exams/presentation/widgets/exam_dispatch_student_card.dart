import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_parent_dispatch_entity.dart';

class ExamDispatchStudentCard extends StatelessWidget {
  final ExamDispatchStudentEntity student;
  final ExamDispatchMetaEntity exam;
  final int index;
  final bool isSent;
  final VoidCallback onTapDispatch;
  final VoidCallback? onEditPhone;

  const ExamDispatchStudentCard({
    super.key,
    required this.student,
    required this.exam,
    required this.index,
    required this.isSent,
    required this.onTapDispatch,
    this.onEditPhone,
  });

  @override
  Widget build(BuildContext context) {
    final isSubmitted = student.isSubmitted;
    final bestScore = student.bestScore;
    final maxScore = exam.maxScore;
    final pct = student.bestPercentage ?? 0.0;
    final hasParentPhone = student.hasParentPhone;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: isSent
              ? const Color(0xFF22C55E).withValues(alpha: 0.4)
              : AppColors.border,
          width: isSent ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Rank/Avatar, Name, Group, Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Rank badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        student.studentName.characters.isNotEmpty
                            ? student.studentName.characters.first
                            : context.l10n.studentInitialFallback,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '#$index',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.s12),

                // Name & Group
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              student.studentName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 11,
                                    color: Color(0xFF16A34A),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    context.l10n.dispatchSentBadge,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Group tag
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              student.groupName,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),

                          // Parent phone badge
                          InkWell(
                            onTap: onEditPhone,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: hasParentPhone
                                    ? const Color(0xFF22C55E)
                                        .withValues(alpha: 0.1)
                                    : AppColors.warning
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    hasParentPhone
                                        ? Icons.phone_android_rounded
                                        : Icons.warning_amber_rounded,
                                    size: 11,
                                    color: hasParentPhone
                                        ? const Color(0xFF16A34A)
                                        : AppColors.warning,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    hasParentPhone
                                        ? student.parentPhone!
                                        : context.l10n.missingParentPhonePrompt,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: hasParentPhone
                                          ? const Color(0xFF16A34A)
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Score pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isSubmitted) ...[
                      Text(
                        '$bestScore / $maxScore',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: student.isPassed
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.l10n.examStatusNotTakenShort,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s8),

            // Bottom Actions Row: Status label & WhatsApp Dispatch CTA
            Row(
              children: [
                // Attempt info
                if (isSubmitted)
                  Text(
                    context.l10n.studentAttemptsGroupCount(student.attemptsCount),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  )
                else
                  Text(
                    context.l10n.awaitingExamSubmissionNotice,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.warning,
                    ),
                  ),

                const Spacer(),

                // Primary Dispatch Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSent
                        ? AppColors.surfaceVariant
                        : const Color(0xFF22C55E),
                    foregroundColor: isSent
                        ? AppColors.textPrimary
                        : Colors.white,
                    elevation: isSent ? 0 : 1,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                  ),
                  icon: Icon(
                    isSent
                        ? Icons.replay_rounded
                        : Icons.send_rounded,
                    size: 14,
                    color: isSent ? AppColors.textSecondary : Colors.white,
                  ),
                  label: Text(
                    isSent
                        ? context.l10n.resendToParentAction
                        : context.l10n.sendScoreToParentAction,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSent ? AppColors.textSecondary : Colors.white,
                    ),
                  ),
                  onPressed: onTapDispatch,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
