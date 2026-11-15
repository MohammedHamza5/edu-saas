import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/student_entity.dart';
import '../dialogs/set_subscription_duration_dialog.dart';

/// Card displayed on Student 360 page giving the teacher full insight
/// and control over the student's access & subscription duration.
class StudentSubscriptionCard extends StatelessWidget {
  final StudentEntity student;

  const StudentSubscriptionCard({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final expiresAt = student.subscriptionExpiresAt;
    final isExpired = student.isSubscriptionExpired;
    final days = student.remainingSubscriptionDays;

    return AppCard(
      title: l10n.studentSubscriptionDurationTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s10),
                    decoration: BoxDecoration(
                      color: (isExpired
                              ? AppColors.error
                              : (expiresAt != null
                                  ? AppColors.success
                                  : AppColors.primary))
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isExpired
                          ? Icons.timer_off_rounded
                          : (expiresAt != null
                              ? Icons.verified_user_rounded
                              : Icons.all_inclusive_rounded),
                      color: isExpired
                          ? AppColors.error
                          : (expiresAt != null
                              ? AppColors.success
                              : AppColors.primary),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expiresAt == null
                              ? l10n.subscriptionUnlimited
                              : (isExpired
                                  ? l10n.subscriptionExpiredOn(
                                      DateFormat.yMMMd().format(expiresAt),
                                    )
                                  : l10n.subscriptionExpiresOn(
                                      DateFormat.yMMMd().format(expiresAt),
                                      days ?? 0,
                                    )),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isExpired
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          expiresAt == null
                              ? l10n.subscriptionUnlimitedSubtitle
                              : DateFormat('EEEE, d MMMM yyyy').format(expiresAt),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (isCompact) ...[
                          const SizedBox(height: AppSpacing.s8),
                          AppBadge(
                            label: isExpired
                                ? l10n.subscriptionExpiredBadge
                                : (expiresAt != null
                                    ? l10n.subscriptionActiveBadge
                                    : l10n.subscriptionUnlimited),
                            variant: isExpired
                                ? AppBadgeVariant.suspended
                                : (expiresAt != null
                                    ? AppBadgeVariant.active
                                    : AppBadgeVariant.neutral),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(width: AppSpacing.s8),
                    AppBadge(
                      label: isExpired
                          ? l10n.subscriptionExpiredBadge
                          : (expiresAt != null
                              ? l10n.subscriptionActiveBadge
                              : l10n.subscriptionUnlimited),
                      variant: isExpired
                          ? AppBadgeVariant.suspended
                          : (expiresAt != null
                              ? AppBadgeVariant.active
                              : AppBadgeVariant.neutral),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s12),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: l10n.setSubscriptionDurationAction,
              variant: AppButtonVariant.secondary,
              icon: Icons.edit_calendar_rounded,
              onPressed: () =>
                  SetSubscriptionDurationDialog.show(context, student: student),
            ),
          ),
        ],
      ),
    );
  }
}
