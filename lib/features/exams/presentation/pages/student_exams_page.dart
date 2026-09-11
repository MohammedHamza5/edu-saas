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
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../widgets/exam_card.dart';
import 'exam_intro_page.dart';

enum StudentExamFilter { all, available, inProgress, completed }

class StudentExamsPage extends StatefulWidget {
  const StudentExamsPage({super.key});

  @override
  State<StudentExamsPage> createState() => _StudentExamsPageState();
}

class _StudentExamsPageState extends State<StudentExamsPage> {
  StudentExamFilter _activeFilter = StudentExamFilter.all;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  void _loadExams() {
    context.read<ExamsCubit>().loadStudentExams();
  }

  List<ExamEntity> _filterExams(List<ExamEntity> list) {
    switch (_activeFilter) {
      case StudentExamFilter.all:
        return list;
      case StudentExamFilter.available:
        return list.where((e) => !e.hasAttempted || e.canTakeExam).toList();
      case StudentExamFilter.inProgress:
        return list.where((e) => e.hasActiveAttempt).toList();
      case StudentExamFilter.completed:
        return list.where((e) => e.hasAttempted && !e.hasActiveAttempt).toList();
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
        title: Text(context.l10n.myExamsTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refreshTooltip,
            onPressed: _loadExams,
          ),
        ],
      ),
      body: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          if (state is ExamsLoading) {
            return const AppLoadingView.cardsGrid(count: 4, columns: 2);
          }

          if (state is ExamsError) {
            return Center(
              child: AppErrorView(
                message: state.message,
                onRetry: _loadExams,
              ),
            );
          }

          if (state is ExamsEmpty) {
            return Center(
              child: AppEmptyView(
                message: state.message,
                subtitle: context.l10n.noPublishedExams,
                icon: Icons.quiz_outlined,
              ),
            );
          }

          if (state is StudentExamsLoaded) {
            final filtered = _filterExams(state.exams);

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
                            _buildFilterChip(context.l10n.filterAll, StudentExamFilter.all, state.exams.length),
                            const SizedBox(width: AppSpacing.s8),
                            _buildFilterChip(
                              context.l10n.filterAvailable,
                              StudentExamFilter.available,
                              state.exams.where((e) => !e.hasAttempted || e.canTakeExam).length,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            _buildFilterChip(
                              context.l10n.filterInProgress,
                              StudentExamFilter.inProgress,
                              state.exams.where((e) => e.hasActiveAttempt).length,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            _buildFilterChip(
                              context.l10n.filterCompleted,
                              StudentExamFilter.completed,
                              state.exams.where((e) => e.hasAttempted && !e.hasActiveAttempt).length,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),

                    // Exams List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: AppEmptyView(
                                message: context.l10n.noExamsInFilter,
                                subtitle: context.l10n.noExamsInFilterSubtitle,
                                icon: Icons.filter_list_off_outlined,
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async => _loadExams(),
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(AppSpacing.s16),
                                child: ResponsiveGrid(
                                  mobileColumns: 1,
                                  tabletColumns: 2,
                                  desktopColumns: 2,
                                  spacing: AppSpacing.s16,
                                  runSpacing: AppSpacing.s16,
                                  children: filtered.map((exam) {
                                    return ExamCard(
                                      exam: exam,
                                      isTeacher: false,
                                      onTap: () {
                                        Navigator.of(context)
                                            .push<void>(
                                          MaterialPageRoute<void>(
                                            builder: (_) => BlocProvider.value(
                                              value: context.read<ExamsCubit>(),
                                              child: ExamIntroPage(exam: exam),
                                            ),
                                          ),
                                        )
                                            .then((_) {
                                          if (context.mounted) {
                                            _loadExams();
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

  Widget _buildFilterChip(String label, StudentExamFilter filter, int count) {
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
