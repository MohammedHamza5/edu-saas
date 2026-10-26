import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../domain/entities/student_entity.dart';

/// Elevated Pending Student Card displaying registration details and actions.
class PendingStudentCard extends StatefulWidget {
  final StudentEntity student;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const PendingStudentCard({
    super.key,
    required this.student,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<PendingStudentCard> createState() => _PendingStudentCardState();
}

class _PendingStudentCardState extends State<PendingStudentCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final dateStr = student.createdAt != null
        ? DateFormat('yyyy/MM/dd – hh:mm a').format(student.createdAt!)
        : '—';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                : AppColors.borderDark,
            width: _isHovered ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x70000000),
              blurRadius: _isHovered ? 24 : 14,
              offset: Offset(0, _isHovered ? 8 : 4),
              spreadRadius: -2,
            ),
            if (_isHovered)
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 640;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: Avatar + Name & Email + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar Badge
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0x33F59E0B),
                            Color(0x14F59E0B),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        student.initials,
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s16),
                    // Name + Email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: AppSpacing.s8,
                            runSpacing: AppSpacing.s4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                student.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              AppBadge(
                                label: context.l10n.pendingApproval,
                                variant: AppBadgeVariant.pending,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.alternate_email_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  student.email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.s16),

                // Info Chips Wrap (Phone, Guardian, Registration Timestamp)
                Wrap(
                  spacing: AppSpacing.s10,
                  runSpacing: AppSpacing.s8,
                  children: [
                    if (student.phone != null && student.phone!.isNotEmpty)
                      _buildInfoChip(
                        icon: Icons.phone_android_rounded,
                        iconColor: AppColors.primaryLight,
                        label: student.phone!,
                      ),
                    if (student.parentPhone != null &&
                        student.parentPhone!.isNotEmpty)
                      _buildInfoChip(
                        icon: Icons.family_restroom_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        label:
                            '${context.l10n.parentPhoneLabel}: ${student.parentPhone!}',
                      ),
                    _buildInfoChip(
                      icon: Icons.calendar_today_rounded,
                      iconColor: AppColors.textMuted,
                      label: context.l10n.requestDateLabel(dateStr),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.s16),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: AppSpacing.s16),

                // Action Buttons
                if (isWide)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildRejectButton(context),
                      const SizedBox(width: AppSpacing.s12),
                      _buildApproveButton(context),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: _buildRejectButton(context)),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(child: _buildApproveButton(context)),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApproveButton(BuildContext context) {
    return InkWell(
      onTap: widget.onApprove,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [
              Color(0xFF16A34A),
              Color(0xFF059669),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3310B981),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.approveAndAdmitAction,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectButton(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFF87171),
        side: BorderSide(
          color: const Color(0xFFEF4444).withValues(alpha: 0.35),
          width: 1.2,
        ),
        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: widget.onReject,
      icon: const Icon(Icons.close_rounded, size: 16),
      label: Text(
        context.l10n.rejectRequestAction,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
