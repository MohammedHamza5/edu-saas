import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
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
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.studentsList),
        ),
        title: Text(context.l10n.newRegistrationRequests),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refresh,
            onPressed: () => context.read<StudentsCubit>().loadPendingStudents(
              refresh: true,
            ),
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
              onRetry: () => context.read<StudentsCubit>().loadPendingStudents(
                refresh: true,
              ),
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
              child: RefreshIndicator(
                onRefresh: () => context
                    .read<StudentsCubit>()
                    .loadPendingStudents(refresh: true),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  itemCount: state.pending.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Elevated Guidance Banner
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.12),
                              AppColors.surfaceVariant.withValues(alpha: 0.4),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusLarge,
                          ),
                          border: Border.all(
                            color: AppColors.primaryLight.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.s8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Text(
                                context.l10n.pendingGuidanceBanner(
                                  state.pending.length,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
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
              color: isApprove
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : const Color(0xFFEF4444).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              const BoxShadow(
                color: Color(0x80000000),
                blurRadius: 32,
                offset: Offset(0, 16),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: (isApprove
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444))
                    .withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 4),
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
                      color: (isApprove ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isApprove ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isApprove
                          ? Icons.how_to_reg_rounded
                          : Icons.person_off_rounded,
                      color: isApprove
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFEF4444),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isApprove
                              ? l10n.approveStudentConfirmTitle
                              : l10n.rejectStudentConfirmTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isApprove
                              ? l10n.approveStudentPendingDetail(student.fullName)
                              : l10n.rejectStudentPendingDetail(student.fullName),
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
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                        backgroundColor: isApprove
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
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
                        isApprove
                            ? l10n.approveStudentAction
                            : l10n.rejectStudentAction,
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

// ── Elevated Pending Card ───────────────────────────────────────────────────

class _PendingCard extends StatefulWidget {
  final StudentEntity student;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingCard({
    required this.student,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard> {
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
                          Row(
                            children: [
                              Flexible(
                                child: Text(
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
                              ),
                              const SizedBox(width: AppSpacing.s8),
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
