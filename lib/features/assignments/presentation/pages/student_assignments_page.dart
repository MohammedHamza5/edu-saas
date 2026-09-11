import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../domain/entities/assignment_entity.dart';
import '../cubit/assignments_cubit.dart';
import '../cubit/assignments_state.dart';
import '../widgets/assignment_card.dart';
import 'assignment_submission_page.dart';

enum StudentAssignmentFilter { all, pending, submitted, reviewed }

class StudentAssignmentsPage extends StatefulWidget {
  const StudentAssignmentsPage({super.key});

  @override
  State<StudentAssignmentsPage> createState() => _StudentAssignmentsPageState();
}

class _StudentAssignmentsPageState extends State<StudentAssignmentsPage> {
  StudentAssignmentFilter _activeFilter = StudentAssignmentFilter.all;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  void _loadAssignments() {
    context.read<AssignmentsCubit>().loadStudentAssignments();
  }

  List<AssignmentEntity> _filterAssignments(List<AssignmentEntity> list) {
    switch (_activeFilter) {
      case StudentAssignmentFilter.all:
        return list;
      case StudentAssignmentFilter.pending:
        return list.where((a) => !a.hasSubmitted).toList();
      case StudentAssignmentFilter.submitted:
        return list.where((a) => a.hasSubmitted && !a.isReviewed).toList();
      case StudentAssignmentFilter.reviewed:
        return list.where((a) => a.isReviewed).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.backToHomeTooltip,
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRouter.studentDashboard);
            }
          },
        ),
        title: Text(context.l10n.myHomeworkTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refreshTooltip,
            onPressed: _loadAssignments,
          ),
        ],
      ),
      body: BlocBuilder<AssignmentsCubit, AssignmentsState>(
        builder: (context, state) {
          if (state is AssignmentsLoading) {
            return const AppLoadingView.cardsGrid(count: 4, columns: 2);
          }

          if (state is AssignmentsError) {
            return Center(
              child: AppErrorView(
                message: state.message,
                onRetry: _loadAssignments,
              ),
            );
          }

          if (state is AssignmentsEmpty) {
            return Center(
              child: AppEmptyView(
                message: state.message,
                subtitle: context.l10n.noAssignmentsInGroup,
                icon: Icons.assignment_turned_in_outlined,
              ),
            );
          }

          if (state is StudentAssignmentsLoaded) {
            final filtered = _filterAssignments(state.assignments);

            return Center(
              child: ResponsiveContainer(
                maxWidth: ResponsiveBreakpoints.maxContentWidth,
                child: Column(
                  children: [
                    // Filter chips
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                        vertical: AppSpacing.s8,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              context.l10n.filterAll,
                              StudentAssignmentFilter.all,
                              state.assignments.length,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            _buildFilterChip(
                              context.l10n.filterPendingSubmission,
                              StudentAssignmentFilter.pending,
                              state.assignments.where((a) => !a.hasSubmitted).length,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            _buildFilterChip(
                              context.l10n.filterSubmitted,
                              StudentAssignmentFilter.submitted,
                              state.assignments
                                  .where((a) => a.hasSubmitted && !a.isReviewed)
                                  .length,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            _buildFilterChip(
                              context.l10n.filterReviewed,
                              StudentAssignmentFilter.reviewed,
                              state.assignments.where((a) => a.isReviewed).length,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),

                    // Assignments List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: AppEmptyView(
                                message: context.l10n.noAssignmentsInFilter,
                                subtitle: context.l10n.noAssignmentsInFilterSubtitle,
                                icon: Icons.filter_list_off_outlined,
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async => _loadAssignments(),
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(AppSpacing.s16),
                                child: ResponsiveGrid(
                                  mobileColumns: 1,
                                  tabletColumns: 2,
                                  desktopColumns: 2,
                                  spacing: AppSpacing.s16,
                                  runSpacing: AppSpacing.s16,
                                  children: filtered.map((assignment) {
                                    return AssignmentCard(
                                      assignment: assignment,
                                      isTeacher: false,
                                      onTap: () {
                                        Navigator.of(context)
                                            .push<void>(
                                          MaterialPageRoute<void>(
                                            builder: (_) => BlocProvider.value(
                                              value: context.read<AssignmentsCubit>(),
                                              child: AssignmentSubmissionPage(
                                                assignment: assignment,
                                              ),
                                            ),
                                          ),
                                        )
                                            .then((_) {
                                          if (context.mounted) {
                                            _loadAssignments();
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildFilterChip(
      String label, StudentAssignmentFilter filter, int count) {
    final isSelected = _activeFilter == filter;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      onSelected: (_) {
        setState(() {
          _activeFilter = filter;
        });
      },
    );
  }
}
