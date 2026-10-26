import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/student_entity.dart';
import '../cubit/students_cubit.dart';

/// Card providing teacher control actions for student status:
/// suspend, activate, approve, or reject.
class StudentAccountActionsCard extends StatelessWidget {
  final StudentEntity student;

  const StudentAccountActionsCard({
    super.key,
    required this.student,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: context.l10n.accountActionsTitle,
      child: Column(
        children: [
          if (student.isActive)
            ListTile(
              leading: const Icon(
                Icons.pause_circle_outline_rounded,
                color: AppColors.warning,
              ),
              title: Text(context.l10n.suspendAccountTemporary),
              subtitle: Text(context.l10n.suspendAccountDesc),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
              onTap: () async {
                final l10n = context.l10n;
                final cubit = context.read<StudentsCubit>();
                final ok = await _confirm(
                  context,
                  title: l10n.suspendStudentConfirmTitle,
                  body: l10n.suspendStudentConfirmBody(student.fullName),
                  label: l10n.suspendStudentAction,
                  color: AppColors.warning,
                );
                if (!context.mounted) return;
                if (!ok) return;

                await cubit.changeStatus(
                  studentId: student.id,
                  action: 'suspend',
                );
                if (!context.mounted) return;
                await cubit.loadStudent360(student.id);
                if (!context.mounted) return;
              },
            ),
          if (student.isSuspended)
            ListTile(
              leading: const Icon(
                Icons.play_circle_outline_rounded,
                color: AppColors.success,
              ),
              title: Text(context.l10n.reactivateAccountTitle),
              subtitle: Text(context.l10n.reactivateAccountDesc),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
              onTap: () async {
                final l10n = context.l10n;
                final cubit = context.read<StudentsCubit>();
                final ok = await _confirm(
                  context,
                  title: l10n.activateStudentConfirmTitle,
                  body: l10n.activateStudentConfirmBody(student.fullName),
                  label: l10n.activateStudentAction,
                  color: AppColors.success,
                );
                if (!context.mounted) return;
                if (!ok) return;

                await cubit.changeStatus(
                  studentId: student.id,
                  action: 'activate',
                );
                if (!context.mounted) return;
                await cubit.loadStudent360(student.id);
                if (!context.mounted) return;
              },
            ),
          if (student.isPending) ...[
            ListTile(
              leading: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
              ),
              title: Text(context.l10n.approveAndAdmitStudentTitle),
              onTap: () async {
                final l10n = context.l10n;
                final cubit = context.read<StudentsCubit>();
                final ok = await _confirm(
                  context,
                  title: l10n.approveStudentConfirmTitle,
                  body: l10n.approveStudentConfirmBody(student.fullName),
                  label: l10n.approveStudentAction,
                  color: AppColors.success,
                );
                if (!context.mounted) return;
                if (!ok) return;

                await cubit.changeStatus(
                  studentId: student.id,
                  action: 'approve',
                );
                if (!context.mounted) return;
                await cubit.loadStudent360(student.id);
                if (!context.mounted) return;
              },
            ),
            ListTile(
              leading: const Icon(Icons.highlight_off, color: AppColors.error),
              title: Text(context.l10n.rejectRequestAction),
              onTap: () async {
                final l10n = context.l10n;
                final cubit = context.read<StudentsCubit>();
                final ok = await _confirm(
                  context,
                  title: l10n.rejectStudentConfirmTitle,
                  body: l10n.rejectStudentConfirmBody(student.fullName),
                  label: l10n.rejectStudentAction,
                  color: AppColors.error,
                );
                if (!context.mounted) return;
                if (!ok) return;

                await cubit.changeStatus(
                  studentId: student.id,
                  action: 'reject',
                );
                if (!context.mounted) return;
                await cubit.loadStudent360(student.id);
                if (!context.mounted) return;
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String label,
    required Color color,
  }) async {
    final cancelLabel = context.l10n.cancel;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(label),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
