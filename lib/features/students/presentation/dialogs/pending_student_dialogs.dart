import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/student_entity.dart';
import '../cubit/students_cubit.dart';
import 'smart_student_approval_dialog.dart';

/// Modal dialogs and action confirmations for pending students approval & rejection.
class PendingStudentDialogs {
  PendingStudentDialogs._();

  /// Shows confirmation dialog for rejecting a pending student request.
  static Future<void> showRejectDialog(
    BuildContext context,
    StudentEntity student,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 32,
                offset: Offset(0, 16),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Color(0x26EF4444),
                blurRadius: 24,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_off_rounded,
                      color: Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.rejectStudentConfirmTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.rejectStudentPendingDetail(student.fullName),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textMuted,
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: l10n.cancel,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSmall),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        l10n.rejectStudentAction,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;
    final cubit = context.read<StudentsCubit>();
    await cubit.changeStatus(
      studentId: student.id,
      action: 'reject',
    );
    if (!context.mounted) return;
    await cubit.loadPendingStudents();
  }

  /// Smart Dialog that allows teacher to approve and immediately enroll
  /// student into target groups in one seamless step.
  static Future<void> showSmartApprovalDialog(
    BuildContext context,
    StudentEntity student,
  ) async {
    final l10n = context.l10n;
    final groupsCubit = context.read<GroupsCubit>();
    if (groupsCubit.state is! GroupsLoaded) {
      await groupsCubit.loadGroups();
    }
    if (!context.mounted) return;

    final selectedGroupIds =
        await SmartStudentApprovalDialog.show(context, student);
    if (selectedGroupIds == null) return;
    if (!context.mounted) return;
    final cubit = context.read<StudentsCubit>();

    if (selectedGroupIds.isNotEmpty) {
      final success = await cubit.approveAndAssignGroups(
        studentId: student.id,
        groupIds: selectedGroupIds.toList(),
      );
      if (!context.mounted) return;
      if (success) {
        AppFeedback.showSuccess(
          context,
          l10n.smartApproveSuccessWithGroupsToast(
            student.fullName,
            selectedGroupIds.length,
          ),
        );
      }
    } else {
      final success = await cubit.changeStatus(
        studentId: student.id,
        action: 'approve',
      );
      if (!context.mounted) return;
      if (success) {
        AppFeedback.showSuccess(
          context,
          l10n.smartApproveSuccessNoGroupsToast(student.fullName),
        );
      }
    }
  }
}
