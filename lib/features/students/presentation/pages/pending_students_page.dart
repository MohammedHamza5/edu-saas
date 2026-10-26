import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/student_entity.dart';
import '../cubit/students_cubit.dart';
import '../cubit/students_state.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../dialogs/pending_student_dialogs.dart';
import '../widgets/pending_student_card.dart';

/// T-03 — Pending Approvals (Teacher)
/// FIFO list of pending students → Approve / Reject with confirmation.
class PendingStudentsPage extends StatefulWidget {
  const PendingStudentsPage({super.key});

  @override
  State<PendingStudentsPage> createState() => _PendingStudentsPageState();
}

class _PendingStudentsPageState extends State<PendingStudentsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<StudentsCubit>().loadPendingStudents();
    try {
      context.read<GroupsCubit>().loadGroups();
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<StudentsCubit>().loadMorePendingStudents();
    }
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
            AppFeedback.showError(context, state.message);
          }
          if (state is StudentActionSuccess) {
            final msg = state.action == 'approve'
                ? context.l10n.studentApprovedToast
                : context.l10n.studentRejectedToast;
            AppFeedback.showSuccess(context, msg);
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
              child: RefreshIndicator(
                onRefresh: () => context
                    .read<StudentsCubit>()
                    .loadPendingStudents(refresh: true),
                child: ListView.separated(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  itemCount:
                      state.pending.length + 1 + (state.isLoadingMore ? 1 : 0),
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

                    if (index == state.pending.length + 1) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                        child: Center(
                          child: AppLoadingView.compact(size: 24),
                        ),
                      );
                    }

                    final student = state.pending[index - 1];
                    return PendingStudentCard(
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
    if (action == 'approve') {
      await PendingStudentDialogs.showSmartApprovalDialog(context, student);
    } else {
      await PendingStudentDialogs.showRejectDialog(context, student);
    }
  }
}
