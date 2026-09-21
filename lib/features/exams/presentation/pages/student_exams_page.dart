import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
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
  final String? initialExamId;

  const StudentExamsPage({super.key, this.initialExamId});

  @override
  State<StudentExamsPage> createState() => _StudentExamsPageState();
}

class _StudentExamsPageState extends State<StudentExamsPage> {
  final ScrollController _scrollController = ScrollController();
  StudentExamFilter _activeFilter = StudentExamFilter.all;

  @override
  void initState() {
    super.initState();
    _loadExams().then((_) {
      if (widget.initialExamId != null && mounted) {
        final state = context.read<ExamsCubit>().state;
        if (state is StudentExamsLoaded) {
          try {
            final exam = state.exams.firstWhere((e) => e.id == widget.initialExamId);
            _openExamIntro(exam);
          } catch (_) {
            // Exam not found in the initial page, might be on another page or invalid.
          }
        }
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _openExamIntro(ExamEntity exam) async {
    final cubit = context.read<ExamsCubit>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: ExamIntroPage(exam: exam),
        ),
      ),
    );
    if (mounted && cubit.state is! ExamTakingState) {
      await _loadExams(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<ExamsCubit>().loadMoreStudentExams();
    }
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    await context.read<ExamsCubit>().loadStudentExams(forceRefresh: forceRefresh);
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
              context.go(AppRoutes.studentDashboard);
            }
          },
        ),
        title: Text(context.l10n.myExamsTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refreshTooltip,
            onPressed: () => _loadExams(forceRefresh: true),
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
                onRetry: () => _loadExams(forceRefresh: true),
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
                              onRefresh: () => _loadExams(forceRefresh: true),
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(AppSpacing.s16),
                                child: Column(
                                  children: [
                                    ResponsiveGrid(
                                      mobileColumns: 1,
                                      tabletColumns: 2,
                                      desktopColumns: 2,
                                      spacing: AppSpacing.s16,
                                      runSpacing: AppSpacing.s16,
                                      children: filtered.map((exam) {
                                        return ExamCard(
                                          exam: exam,
                                          isTeacher: false,
                                          onTap: () => _openExamIntro(exam),
                                        );
                                      }).toList(),
                                    ),
                                    if (state.isLoadingMore)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: AppSpacing.s16,
                                        ),
                                        child: Center(
                                          child: AppLoadingView.compact(size: 24),
                                        ),
                                      ),
                                  ],
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
