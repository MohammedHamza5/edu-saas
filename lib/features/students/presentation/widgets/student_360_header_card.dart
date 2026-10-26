import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/student_entity.dart';

/// Header card displaying student avatar, name, contact info, and status badge.
class Student360HeaderCard extends StatelessWidget {
  final StudentEntity student;

  const Student360HeaderCard({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primaryLight.withValues(
              alpha: 0.15,
            ),
            backgroundImage: student.avatarUrl != null
                ? NetworkImage(student.avatarUrl!)
                : null,
            child: student.avatarUrl == null
                ? Text(
                    student.initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
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
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
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
                          '${context.l10n.studentPhoneLabel}: ${student.phone!}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
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
                        color: Color(0xFF25D366),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${context.l10n.parentPhoneLabel}: ${student.parentPhone!}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                StudentStatusBadge(status: student.status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual status badge (active, pending, suspended, rejected).
class StudentStatusBadge extends StatelessWidget {
  final String status;

  const StudentStatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final (label, variant) = switch (status) {
      'active' => (context.l10n.active, AppBadgeVariant.active),
      'pending' => (context.l10n.pendingApproval, AppBadgeVariant.pending),
      'suspended' => (context.l10n.suspended, AppBadgeVariant.suspended),
      _ => (context.l10n.rejected, AppBadgeVariant.neutral),
    };
    return AppBadge(label: label, variant: variant);
  }
}
