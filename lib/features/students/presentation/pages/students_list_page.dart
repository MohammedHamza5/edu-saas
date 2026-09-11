import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/student_entity.dart';
import '../cubit/students_cubit.dart';
import '../cubit/students_state.dart';

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

  List<({String label, String? value})> _getStatusFilters(BuildContext context) => [
    (label: context.l10n.all, value: null),
    (label: context.l10n.active, value: 'active'),
    (label: context.l10n.pending, value: 'pending'),
    (label: context.l10n.rejected, value: 'rejected'),
    (label: context.l10n.suspended, value: 'suspended'),
  ];

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
    final statusFilters = _getStatusFilters(context);

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
                    onPressed: () => context.go(AppRouter.pendingStudents),
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
        maxWidth: ResponsiveBreakpoints.maxContentWidth,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Search bar ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s12,
                  AppSpacing.s16,
                  0,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.l10n.searchStudentsHint,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch('');
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s12,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // ── Status filter chips ────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s8,
                  ),
                  itemCount: statusFilters.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.s8),
                  itemBuilder: (context, i) {
                    final f = statusFilters[i];
                    final selected = _selectedStatus == f.value;
                    return FilterChip(
                      label: Text(f.label),
                      selected: selected,
                      selectedColor: AppColors.primaryLight.withValues(
                        alpha: 0.2,
                      ),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => _onFilterTap(f.value),
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // ── List ────────────────────────────────────────────────────────
              Expanded(
                child: BlocConsumer<StudentsCubit, StudentsState>(
                  buildWhen: (previous, current) =>
                      current is StudentsLoaded ||
                      current is StudentsLoading ||
                      current is StudentsError,
                  listenWhen: (previous, current) =>
                      current is StudentsError ||
                      current is StudentActionSuccess,
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
                    if (state is StudentsLoading) {
                      return _buildSkeletonLoading();
                    }
                    if (state is StudentsError) {
                      return AppErrorView(
                        message: state.message,
                        onRetry: () => context.read<StudentsCubit>().loadStudents(
                          status: _selectedStatus,
                          refresh: true,
                        ),
                      );
                    }
                    if (state is StudentsLoaded) {
                      if (state.students.isEmpty) {
                        if (_searchController.text.trim().isNotEmpty) {
                          return AppEmptyView(
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
                          );
                        }
                        return AppEmptyView(
                          icon: Icons.people_outline_rounded,
                          message: _selectedStatus != null
                              ? context.l10n.noStudentsWithStatus
                              : context.l10n.noStudentsRegistered,
                        );
                      }
                      return ListView.separated(
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
                          return _StudentCard(
                            student: student,
                            onTap: () => context.go(
                              '${AppRouter.student360}?id=${student.id}',
                              extra: student,
                            ),
                            onAssignGroups: student.isActive
                                ? () => context.go(
                                    AppRouter.assignGroups,
                                    extra: student.id,
                                  )
                                : null,
                            onApprove: student.isPending
                                ? () => _confirmAction(
                                    context,
                                    student: student,
                                    action: 'approve',
                                    title: context.l10n.approveStudentConfirmTitle,
                                    body: context.l10n.approveStudentConfirmBody(
                                      student.fullName,
                                    ),
                                    confirmLabel: context.l10n.approveStudentAction,
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
                                    confirmLabel: context.l10n.rejectStudentAction,
                                    confirmColor: AppColors.error,
                                  )
                                : null,
                            onSuspend: student.isActive
                                ? () => _confirmAction(
                                    context,
                                    student: student,
                                    action: 'suspend',
                                    title: context.l10n.suspendStudentConfirmTitle,
                                    body: context.l10n.suspendStudentConfirmBody(
                                      student.fullName,
                                    ),
                                    confirmLabel: context.l10n.suspendStudentAction,
                                    confirmColor: AppColors.warning,
                                  )
                                : null,
                            onActivate: student.isSuspended
                                ? () => _confirmAction(
                                    context,
                                    student: student,
                                    action: 'activate',
                                    title: context.l10n.activateStudentConfirmTitle,
                                    body: context.l10n.activateStudentConfirmBody(
                                      student.fullName,
                                    ),
                                    confirmLabel: context.l10n.activateStudentAction,
                                    confirmColor: AppColors.success,
                                  )
                                : null,
                          );
                        },
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
                    return _buildSkeletonLoading();
                  },
                ),
              ),
            ],
          ),
        ),
    );
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

// ── Student card widget ───────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final StudentEntity student;
  final VoidCallback onTap;
  final VoidCallback? onAssignGroups;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onSuspend;
  final VoidCallback? onActivate;

  const _StudentCard({
    required this.student,
    required this.onTap,
    this.onAssignGroups,
    this.onApprove,
    this.onReject,
    this.onSuspend,
    this.onActivate,
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
              onAssignGroups != null) ...[
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (onAssignGroups != null)
                  _ActionBtn(
                    label: context.l10n.assignGroupsAction,
                    icon: Icons.group_add_rounded,
                    color: AppColors.primary,
                    onPressed: onAssignGroups!,
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

