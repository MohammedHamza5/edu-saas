import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
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
          tooltip: 'الرجوع للرئيسية',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRouter.studentDashboard);
            }
          },
        ),
        title: const Text('واجباتي المدرسية'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadAssignments,
          ),
        ],
      ),
      body: BlocBuilder<AssignmentsCubit, AssignmentsState>(
        builder: (context, state) {
          if (state is AssignmentsLoading) {
            return const Center(child: AppLoadingView());
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
                subtitle: 'لا توجد واجبات مطلوب تسليمها في مجموعاتك حالياً',
                icon: Icons.assignment_turned_in_outlined,
              ),
            );
          }

          if (state is StudentAssignmentsLoaded) {
            final filtered = _filterAssignments(state.assignments);

            return Column(
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
                        _buildFilterChip('الكل', StudentAssignmentFilter.all,
                            state.assignments.length),
                        const SizedBox(width: AppSpacing.s8),
                        _buildFilterChip(
                          'مطلوب تسليمها',
                          StudentAssignmentFilter.pending,
                          state.assignments.where((a) => !a.hasSubmitted).length,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        _buildFilterChip(
                          'تم تسليمها',
                          StudentAssignmentFilter.submitted,
                          state.assignments
                              .where((a) => a.hasSubmitted && !a.isReviewed)
                              .length,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        _buildFilterChip(
                          'تم التصحيح',
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
                      ? const Center(
                          child: AppEmptyView(
                            message: 'لا توجد نتائج في هذا التصنيف',
                            subtitle: 'جرب التبديل لتصنيف آخر لرؤية واجباتك',
                            icon: Icons.filter_list_off_outlined,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _loadAssignments(),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s12),
                            itemBuilder: (context, index) {
                              final assignment = filtered[index];
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
                            },
                          ),
                        ),
                ),
              ],
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
