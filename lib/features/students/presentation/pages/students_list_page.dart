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
import '../../../../core/widgets/app_state_switcher.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/student_entity.dart';
import '../cubit/students_cubit.dart';
import '../cubit/students_state.dart';
import '../dialogs/academic_report_dialog.dart';
import '../widgets/student_card.dart';
import '../widgets/students_filter_bar.dart';

/// T-02 — Students List (Teacher)
/// Features: search / filter by status / pagination 25 / approve-reject-suspend shortcuts
class StudentsListPage extends StatefulWidget {
  const StudentsListPage({super.key});

  @override
  State<StudentsListPage> createState() => _StudentsListPageState();
}

class _StudentsListPageState extends State<StudentsListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String? _selectedStatus; // null = all
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    context.read<StudentsCubit>().loadStudents();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<StudentsCubit>().loadMore();
    }
  }

  void _onSearch(String q) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<StudentsCubit>().search(q);
      }
    });
  }

  void _onFilterTap(String? status) {
    setState(() => _selectedStatus = status);
    context.read<StudentsCubit>().setFilter(status);
  }

  Widget _buildSkeletonLoading() {
    return const AppLoadingView.list(count: 6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.studentsListTitle),
        actions: [
          // Pending badge button → T-03
          BlocBuilder<StudentsCubit, StudentsState>(
            builder: (context, state) {
              final count = state is StudentsLoaded ? state.pendingCount : 0;
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    icon: const Icon(Icons.pending_actions_rounded),
                    tooltip: context.l10n.pendingStudentsTitle,
                    onPressed: () => context.go(AppRoutes.pendingStudents),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refresh,
            onPressed: () => context.read<StudentsCubit>().loadStudents(
              status: _selectedStatus,
              refresh: true,
            ),
          ),
        ],
      ),
      body: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudentsFilterBar(
              searchController: _searchController,
              selectedStatus: _selectedStatus,
              onSearch: _onSearch,
              onClearSearch: () {
                _searchController.clear();
                _onSearch('');
                setState(() {});
              },
              onFilterTap: _onFilterTap,
            ),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: BlocConsumer<StudentsCubit, StudentsState>(
                buildWhen: (previous, current) =>
                    current is StudentsLoaded ||
                    current is StudentsLoading ||
                    current is StudentsError,
                listenWhen: (previous, current) =>
                    current is StudentsError || current is StudentActionSuccess,
                listener: (context, state) {
                  if (state is StudentsError) {
                    AppFeedback.showError(context, state.message);
                  }
                  if (state is StudentActionSuccess) {
                    final msg = switch (state.action) {
                      'approve' => context.l10n.studentApprovedToast,
                      'reject' => context.l10n.studentRejectedToast,
                      'suspend' => context.l10n.studentSuspendedToast,
                      'activate' => context.l10n.studentActivatedToast,
                      _ => context.l10n.statusUpdatedToast,
                    };
                    AppFeedback.showSuccess(context, msg);
                  }
                },
                builder: (context, state) {
                  return AppStateSwitcher(
                    child: () {
                      if (state is StudentsLoading) {
                        return KeyedSubtree(
                          key: const ValueKey('students_loading'),
                          child: _buildSkeletonLoading(),
                        );
                      }
                      if (state is StudentsError) {
                        return KeyedSubtree(
                          key: const ValueKey('students_error'),
                          child: AppErrorView(
                            message: state.message,
                            onRetry: () =>
                                context.read<StudentsCubit>().loadStudents(
                                      status: _selectedStatus,
                                      refresh: true,
                                    ),
                          ),
                        );
                      }
                      if (state is StudentsLoaded) {
                        if (state.students.isEmpty) {
                          final emptyWidget = _searchController.text
                                  .trim()
                                  .isNotEmpty
                              ? AppEmptyView(
                                  icon: Icons.search_off_rounded,
                                  message: context.l10n.noStudentsMatchingSearch(
                                    _searchController.text.trim(),
                                  ),
                                  actionText: context.l10n.clearSearch,
                                  onAction: () {
                                    _searchController.clear();
                                    _onSearch('');
                                    setState(() {});
                                  },
                                )
                              : AppEmptyView(
                                  icon: Icons.people_outline_rounded,
                                  message: _selectedStatus != null
                                      ? context.l10n.noStudentsWithStatus
                                      : context.l10n.noStudentsRegistered,
                                );
                          return KeyedSubtree(
                            key: ValueKey(
                                'students_empty_${_searchController.text.trim()}'),
                            child: emptyWidget,
                          );
                        }
                        return KeyedSubtree(
                          key: const ValueKey('students_loaded_list'),
                          child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      itemCount:
                          state.students.length + (state.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s12),
                      itemBuilder: (context, index) {
                        if (index == state.students.length) {
                          return const Padding(
                            padding: EdgeInsets.all(AppSpacing.s16),
                            child: Center(
                              child: AppLoadingView.compact(size: 24),
                            ),
                          );
                        }
                        final student = state.students[index];
                        return StudentCard(
                          student: student,
                          onTap: () => context.go(
                            '${AppRoutes.student360}?id=${student.id}',
                            extra: student,
                          ),
                          onAssignGroups: student.isActive
                              ? () => context.go(
                                  AppRoutes.assignGroups,
                                  extra: student.id,
                                )
                              : null,
                          onApprove: student.isPending
                              ? () => _confirmAction(
                                  context,
                                  student: student,
                                  action: 'approve',
                                  title:
                                      context.l10n.approveStudentConfirmTitle,
                                  body: context.l10n.approveStudentConfirmBody(
                                    student.fullName,
                                  ),
                                  confirmLabel:
                                      context.l10n.approveStudentAction,
                                  confirmColor: AppColors.success,
                                )
                              : null,
                          onReject: student.isPending
                              ? () => _confirmAction(
                                  context,
                                  student: student,
                                  action: 'reject',
                                  title: context.l10n.rejectStudentConfirmTitle,
                                  body: context.l10n.rejectStudentConfirmBody(
                                    student.fullName,
                                  ),
                                  confirmLabel:
                                      context.l10n.rejectStudentAction,
                                  confirmColor: AppColors.error,
                                )
                              : null,
                          onSuspend: student.isActive
                              ? () => _confirmAction(
                                  context,
                                  student: student,
                                  action: 'suspend',
                                  title:
                                      context.l10n.suspendStudentConfirmTitle,
                                  body: context.l10n.suspendStudentConfirmBody(
                                    student.fullName,
                                  ),
                                  confirmLabel:
                                      context.l10n.suspendStudentAction,
                                  confirmColor: AppColors.warning,
                                )
                              : null,
                          onActivate: student.isSuspended
                              ? () => _confirmAction(
                                  context,
                                  student: student,
                                  action: 'activate',
                                  title:
                                      context.l10n.activateStudentConfirmTitle,
                                  body: context.l10n.activateStudentConfirmBody(
                                    student.fullName,
                                  ),
                                  confirmLabel:
                                      context.l10n.activateStudentAction,
                                  confirmColor: AppColors.success,
                                )
                              : null,
                          onDelete: () => _confirmDeleteStudent(context, student),
                          onWhatsApp: (student.parentPhone?.isNotEmpty == true ||
                                  student.phone?.isNotEmpty == true)
                              ? () {
                                  AcademicReportDialog.show(
                                    context,
                                    studentId: student.id,
                                    studentName: student.fullName,
                                    parentPhone: student.parentPhone,
                                    studentPhone: student.phone,
                                  );
                                }
                              : null,
                        );
                      },
                    ),
                  );
                }
                // Resilient auto-recovery: If cubit is in an unexpected state, reload students
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    context.read<StudentsCubit>().loadStudents(
                          status: _selectedStatus,
                        );
                  }
                });
                return KeyedSubtree(
                  key: const ValueKey('students_fallback'),
                  child: _buildSkeletonLoading(),
                );
              }(),
            );
          },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteStudent(
    BuildContext context,
    StudentEntity student,
  ) async {
    final l10n = context.l10n;
    final cubit = context.read<StudentsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteStudentConfirmTitle),
        content: Text(l10n.deleteStudentConfirmBody(student.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteStudentAction),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirmed == true) {
      final ok = await cubit.deleteStudent(student.id);
      if (!context.mounted) return;
      if (ok) {
        AppFeedback.showSuccess(context, l10n.studentDeletedSuccess);
      }
    }
  }

  Future<void> _confirmAction(
    BuildContext context, {
    required StudentEntity student,
    required String action,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<StudentsCubit>().changeStatus(
        studentId: student.id,
        action: action,
      );
    }
  }
}
