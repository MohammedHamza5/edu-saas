import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/student_entity.dart';
import '../cubit/students_cubit.dart';
import '../cubit/students_state.dart';

/// T-03 — Pending Approvals (Teacher)
/// FIFO list of pending students → Approve / Reject with confirmation.
class PendingStudentsPage extends StatefulWidget {
  const PendingStudentsPage({super.key});

  @override
  State<PendingStudentsPage> createState() => _PendingStudentsPageState();
}

class _PendingStudentsPageState extends State<PendingStudentsPage> {
  @override
  void initState() {
    super.initState();
    context.read<StudentsCubit>().loadPendingStudents();
  }

  Widget _buildSkeletonLoading() {
    return const AppLoadingView.list(count: 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.backToStudentsList,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRouter.studentsList),
        ),
        title: Text(context.l10n.newRegistrationRequests),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refresh,
            onPressed: () =>
                context.read<StudentsCubit>().loadPendingStudents(),
          ),
        ],
      ),
      body: BlocConsumer<StudentsCubit, StudentsState>(
        buildWhen: (previous, current) =>
            current is PendingStudentsLoaded ||
            current is StudentsLoading ||
            current is StudentsError ||
            current is StudentActionInProgress ||
            current is StudentActionSuccess,
        listenWhen: (previous, current) =>
            current is StudentsError || current is StudentActionSuccess,
        listener: (context, state) {
          if (state is StudentsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
          if (state is StudentActionSuccess) {
            final msg = state.action == 'approve'
                ? context.l10n.studentApprovedToast
                : context.l10n.studentRejectedToast;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
        },
        builder: (context, state) {
          if (state is StudentsLoading ||
              state is StudentActionInProgress ||
              state is StudentActionSuccess) {
            return _buildSkeletonLoading();
          }

          if (state is StudentsError) {
            return AppErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<StudentsCubit>().loadPendingStudents(),
            );
          }

          if (state is PendingStudentsLoaded) {
            if (state.pending.isEmpty) {
              return AppEmptyView(
                icon: Icons.check_circle_outline_rounded,
                message: context.l10n.noPendingRegistrationRequests,
              );
            }

            return ResponsiveContainer(
              maxWidth: ResponsiveBreakpoints.maxContentWidth,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.s16),
                itemCount: state.pending.length + 1,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.s12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Guidance banner
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              context.l10n.pendingGuidanceBanner(state.pending.length),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final student = state.pending[index - 1];
                  return _PendingCard(
                    student: student,
                    onApprove: () => _act(context, student, 'approve'),
                    onReject: () => _act(context, student, 'reject'),
                  );
                },
              ),
            );
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.read<StudentsCubit>().loadPendingStudents();
            }
          });
          return _buildSkeletonLoading();
        },
      ),
    );
  }

  Future<void> _act(
    BuildContext context,
    StudentEntity student,
    String action,
  ) async {
    final isApprove = action == 'approve';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isApprove
              ? context.l10n.approveStudentConfirmTitle
              : context.l10n.rejectStudentConfirmTitle,
        ),
        content: Text(
          isApprove
              ? context.l10n.approveStudentPendingDetail(student.fullName)
              : context.l10n.rejectStudentPendingDetail(student.fullName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isApprove ? AppColors.success : AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isApprove
                  ? context.l10n.approveStudentAction
                  : context.l10n.rejectStudentAction,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<StudentsCubit>().changeStatus(
        studentId: student.id,
        action: action,
      );
      if (context.mounted) {
        await context.read<StudentsCubit>().loadPendingStudents();
      }
    }
  }
}

// ── Pending card ─────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final StudentEntity student;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCard({
    required this.student,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = student.createdAt != null
        ? DateFormat('yyyy/MM/dd – hh:mm a').format(student.createdAt!)
        : '—';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                child: Text(
                  student.initials,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            context.l10n.requestDateLabel(dateStr),
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
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              AppBadge(
                label: context.l10n.pendingApproval,
                variant: AppBadgeVariant.pending,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.s8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: Text(
                    context.l10n.rejectRequestAction,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded, size: 14),
                  label: Text(
                    context.l10n.approveAndAdmitAction,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

