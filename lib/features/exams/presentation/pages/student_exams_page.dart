import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
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
enum AssessmentTypeFilter { all, lessonQuizzes, generalExams }

class StudentExamsPage extends StatefulWidget {
  final String? initialExamId;

  const StudentExamsPage({super.key, this.initialExamId});

  @override
  State<StudentExamsPage> createState() => _StudentExamsPageState();
}

class _StudentExamsPageState extends State<StudentExamsPage> {
  final ScrollController _scrollController = ScrollController();
  StudentExamFilter _activeFilter = StudentExamFilter.all;
  AssessmentTypeFilter _typeFilter = AssessmentTypeFilter.all;
  Set<String> _lessonExamIds = {};

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
    try {
      final res = await InjectionContainer.supabaseClient
          .from('content_groups')
          .select('associated_exam_id')
          .not('associated_exam_id', 'is', null);
      if (mounted) {
        final ids = <String>{};
        for (final row in (res as List<dynamic>)) {
          final id = row['associated_exam_id'] as String?;
          if (id != null && id.isNotEmpty) ids.add(id);
        }
        setState(() {
          _lessonExamIds = ids;
        });
      }
    } catch (_) {}
    if (mounted) {
      await context.read<ExamsCubit>().loadStudentExams(forceRefresh: forceRefresh);
    }
  }

  bool _isLessonQuiz(ExamEntity exam) {
    if (_lessonExamIds.contains(exam.id)) return true;
    final lower = exam.title.toLowerCase();
    return lower.contains('quiz') || lower.contains('درس') || lower.contains('lesson');
  }

  List<ExamEntity> _filterExams(List<ExamEntity> list) {
    var result = list;
    if (_typeFilter == AssessmentTypeFilter.lessonQuizzes) {
      result = result.where(_isLessonQuiz).toList();
    } else if (_typeFilter == AssessmentTypeFilter.generalExams) {
      result = result.where((e) => !_isLessonQuiz(e)).toList();
    }

    switch (_activeFilter) {
      case StudentExamFilter.all:
        return result;
      case StudentExamFilter.available:
        return result.where((e) => !e.hasAttempted || e.canTakeExam).toList();
      case StudentExamFilter.inProgress:
        return result.where((e) => e.hasActiveAttempt).toList();
      case StudentExamFilter.completed:
        return result.where((e) => e.hasAttempted && !e.hasActiveAttempt).toList();
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
        title: Text(context.l10n.courseAssessmentsTitle),
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
            final lessonQuizzes = filtered.where(_isLessonQuiz).toList();
            final generalExams = filtered.where((e) => !_isLessonQuiz(e)).toList();

            return Center(
              child: ResponsiveContainer(
                maxWidth: ResponsiveBreakpoints.maxContentWidth,
                child: Column(
                  children: [
                    // 1. Assessment Category Chips (All / Lesson Quizzes / General Exams)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.s16,
                        right: AppSpacing.s16,
                        top: AppSpacing.s8,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildCategoryChip(
                              context.l10n.filterAll,
                              AssessmentTypeFilter.all,
                              state.exams.length,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            _buildCategoryChip(
                              context.l10n.lessonQuizzesSectionTitle,
                              AssessmentTypeFilter.lessonQuizzes,
                              state.exams.where(_isLessonQuiz).length,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            _buildCategoryChip(
                              context.l10n.generalExamsSectionTitle,
                              AssessmentTypeFilter.generalExams,
                              state.exams.where((e) => !_isLessonQuiz(e)).length,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 2. Status Filter Chips
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                        vertical: AppSpacing.s8,
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(context.l10n.filterAll, StudentExamFilter.all, filtered.length),
                            const SizedBox(width: AppSpacing.s8),
                            _buildFilterChip(
                              context.l10n.filterAvailable,
                              StudentExamFilter.available,
                              filtered.where((e) => !e.hasAttempted || e.canTakeExam).length,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            _buildFilterChip(
                              context.l10n.filterInProgress,
                              StudentExamFilter.inProgress,
                              filtered.where((e) => e.hasActiveAttempt).length,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            _buildFilterChip(
                              context.l10n.filterCompleted,
                              StudentExamFilter.completed,
                              filtered.where((e) => e.hasAttempted && !e.hasActiveAttempt).length,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),

                    // 3. Exams List grouped or filtered
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
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (_typeFilter == AssessmentTypeFilter.all) ...[
                                      if (lessonQuizzes.isNotEmpty) ...[
                                        _buildSectionHeader(
                                          context,
                                          title: context.l10n.lessonQuizzesSectionTitle,
                                          subtitle: context.l10n.lessonQuizzesSectionDesc,
                                          icon: Icons.quiz_rounded,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(height: AppSpacing.s8),
                                        _buildExamsGrid(lessonQuizzes),
                                        const SizedBox(height: AppSpacing.s24),
                                      ],
                                      if (generalExams.isNotEmpty) ...[
                                        _buildSectionHeader(
                                          context,
                                          title: context.l10n.generalExamsSectionTitle,
                                          subtitle: context.l10n.generalExamsSectionDesc,
                                          icon: Icons.assignment_rounded,
                                          color: const Color(0xFF0D9488),
                                        ),
                                        const SizedBox(height: AppSpacing.s8),
                                        _buildExamsGrid(generalExams),
                                      ],
                                    ] else if (_typeFilter == AssessmentTypeFilter.lessonQuizzes) ...[
                                      _buildSectionHeader(
                                        context,
                                        title: context.l10n.lessonQuizzesSectionTitle,
                                        subtitle: context.l10n.lessonQuizzesSectionDesc,
                                        icon: Icons.quiz_rounded,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(height: AppSpacing.s8),
                                      _buildExamsGrid(filtered),
                                    ] else ...[
                                      _buildSectionHeader(
                                        context,
                                        title: context.l10n.generalExamsSectionTitle,
                                        subtitle: context.l10n.generalExamsSectionDesc,
                                        icon: Icons.assignment_rounded,
                                        color: const Color(0xFF0D9488),
                                      ),
                                      const SizedBox(height: AppSpacing.s8),
                                      _buildExamsGrid(filtered),
                                    ],
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

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamsGrid(List<ExamEntity> exams) {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 2,
      spacing: AppSpacing.s16,
      runSpacing: AppSpacing.s16,
      children: exams.map((exam) {
        return ExamCard(
          exam: exam,
          isTeacher: false,
          onTap: () => _openExamIntro(exam),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryChip(String label, AssessmentTypeFilter filter, int count) {
    final isSelected = _typeFilter == filter;
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
          _typeFilter = filter;
        });
      },
    );
  }

  Widget _buildFilterChip(String label, StudentExamFilter filter, int count) {
    final isSelected = _activeFilter == filter;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppColors.primary.withAlpha(25),
      backgroundColor: Colors.transparent,
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      onSelected: (_) {
        setState(() {
          _activeFilter = filter;
        });
      },
    );
  }
}
