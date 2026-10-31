import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/student_entity.dart';

class StudentCard extends StatelessWidget {
  final StudentEntity student;
  final VoidCallback onTap;
  final VoidCallback? onAssignGroups;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onSuspend;
  final VoidCallback? onActivate;
  final VoidCallback? onDelete;
  final VoidCallback? onWhatsApp;

  const StudentCard({
    super.key,
    required this.student,
    required this.onTap,
    this.onAssignGroups,
    this.onApprove,
    this.onReject,
    this.onSuspend,
    this.onActivate,
    this.onDelete,
    this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final badgeVariant = switch (student.status) {
      'active' => AppBadgeVariant.active,
      'pending' => AppBadgeVariant.pending,
      'suspended' => AppBadgeVariant.suspended,
      _ => AppBadgeVariant.neutral,
    };

    final statusLabel = switch (student.status) {
      'active' => context.l10n.active,
      'pending' => context.l10n.pendingApproval,
      'rejected' => context.l10n.rejected,
      'suspended' => context.l10n.suspended,
      _ => student.status,
    };

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                backgroundImage: student.avatarUrl != null
                    ? NetworkImage(student.avatarUrl!)
                    : null,
                child: student.avatarUrl == null
                    ? Text(
                        student.initials,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            student.email,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (student.phone != null && student.phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              student.phone!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (student.parentPhone != null &&
                        student.parentPhone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.family_restroom_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${context.l10n.parentPhoneLabel}: ${student.parentPhone!}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              AppBadge(label: statusLabel, variant: badgeVariant),
            ],
          ),

          // Action buttons — only shown when relevant
          if (onApprove != null ||
              onReject != null ||
              onSuspend != null ||
              onActivate != null ||
              onAssignGroups != null ||
              onWhatsApp != null ||
              onDelete != null) ...[
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    if (onAssignGroups != null)
                      _ActionBtn(
                        label: context.l10n.assignGroupsAction,
                        icon: Icons.group_add_rounded,
                        color: AppColors.primary,
                        onPressed: onAssignGroups!,
                      ),
                    if (onWhatsApp != null)
                      _ActionBtn(
                        label: context.l10n.whatsappQuickActionTooltip,
                        icon: Icons.mark_chat_read_rounded,
                        color: const Color(0xFF25D366),
                        onPressed: onWhatsApp!,
                      ),
                  ],
                ),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    if (onReject != null)
                      _ActionBtn(
                        label: context.l10n.rejectStudentAction,
                        icon: Icons.close_rounded,
                        color: AppColors.error,
                        onPressed: onReject!,
                      ),
                    if (onApprove != null)
                      _ActionBtn(
                        label: context.l10n.approveStudentAction,
                        icon: Icons.check_rounded,
                        color: AppColors.success,
                        onPressed: onApprove!,
                      ),
                    if (onSuspend != null)
                      _ActionBtn(
                        label: context.l10n.suspendStudentAction,
                        icon: Icons.pause_circle_outline_rounded,
                        color: AppColors.warning,
                        onPressed: onSuspend!,
                      ),
                    if (onActivate != null)
                      _ActionBtn(
                        label: context.l10n.activateStudentAction,
                        icon: Icons.play_circle_outline_rounded,
                        color: AppColors.success,
                        onPressed: onActivate!,
                      ),
                    if (onDelete != null)
                      _ActionBtn(
                        label: context.l10n.deleteStudentAction,
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        onPressed: onDelete!,
                      ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s6,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
