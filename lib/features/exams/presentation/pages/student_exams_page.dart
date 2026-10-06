import 'dart:async';
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
import '../../domain/entities/mistake_entities.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../cubit/mistakes_cubit.dart';
import '../cubit/mistakes_state.dart';
import '../widgets/exam_card.dart';
import 'exam_intro_page.dart';
import 'exam_review_page.dart';

enum StudentExamFilter { all, lectureQuizzes, general, completed }

class StudentExamsPage extends StatefulWidget {
  final String? initialExamId;

  const StudentExamsPage({super.key, this.initialExamId});

  @override
  State<StudentExamsPage> createState() => _StudentExamsPageState();
}

class _StudentExamsPageState extends State<StudentExamsPage> {
  final ScrollController _scrollController = ScrollController();
  StudentExamFilter _activeFilter = StudentExamFilter.all;
  Set<String> _lessonExamIds = {};

  @override
  void initState() {
    super.initState();
    _loadAll().then((_) {
      if (widget.initialExamId != null && mounted) {
        final state = context.read<ExamsCubit>().state;
        if (state is StudentExamsLoaded) {
          try {
            final exam = state.exams.firstWhere(
              (e) => e.id == widget.initialExamId,
            );
            _openExamIntro(exam);
          } catch (_) {
            // Exam not found in the initial page, might be on another page or invalid.
          }
        }
      }
    });
    _scrollController.addListener(_onScroll);
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
      unawaited(context.read<ExamsCubit>().loadMoreStudentExams());
    }
  }

  Future<void> _loadAll({bool forceRefresh = false}) async {
    // 1. Refresh mistakes summary & questions
    try {
      await context.read<MistakesCubit>().loadMistakes();
    } catch (_) {}

    // 2. Refresh exams & lesson exam ids
    await _loadExams(forceRefresh: forceRefresh);
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    try {
      final ids = <String>{};

      // 1. From content_groups (associated & prerequisite)
      final cgRes = await InjectionContainer.supabaseClient
          .from('content_groups')
          .select('associated_exam_id, prerequisite_exam_id');
      for (final row in (cgRes as List<dynamic>)) {
        final aId = row['associated_exam_id'] as String?;
        final pId = row['prerequisite_exam_id'] as String?;
        if (aId != null && aId.isNotEmpty) ids.add(aId);
        if (pId != null && pId.isNotEmpty) ids.add(pId);
      }

      // 2. From content (associated & prerequisite)
      final cRes = await InjectionContainer.supabaseClient
          .from('content')
          .select('associated_exam_id, prerequisite_exam_id');
      for (final row in (cRes as List<dynamic>)) {
        final aId = row['associated_exam_id'] as String?;
        final pId = row['prerequisite_exam_id'] as String?;
        if (aId != null && aId.isNotEmpty) ids.add(aId);
        if (pId != null && pId.isNotEmpty) ids.add(pId);
      }

      if (mounted) {
        setState(() {
          _lessonExamIds = ids;
        });
      }
    } catch (_) {}

    if (mounted) {
      await context.read<ExamsCubit>().loadStudentExams(
        forceRefresh: forceRefresh,
      );
    }
  }

  bool _isLessonQuiz(ExamEntity exam) {
    if (_lessonExamIds.contains(exam.id)) return true;
    final lower = exam.title.toLowerCase();
    return lower.contains('كويز') ||
        lower.contains('quiz') ||
        lower.contains('درس') ||
        lower.contains('محاضرة') ||
        lower.contains('lesson');
  }

  List<ExamEntity> _filterExams(List<ExamEntity> list) {
    switch (_activeFilter) {
      case StudentExamFilter.all:
        return list;
      case StudentExamFilter.lectureQuizzes:
        return list.where((e) => _isLessonQuiz(e)).toList();
      case StudentExamFilter.general:
        return list.where((e) => !_isLessonQuiz(e)).toList();
      case StudentExamFilter.completed:
        return list
            .where((e) => e.hasAttempted && !e.hasActiveAttempt)
            .toList();
    }
  }

  void _openExamReview(ExamEntity exam) {
    final attempt = exam.myLatestAttempt;
    if (attempt == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ExamReviewPage(
          attemptId: attempt.id,
          exam: exam,
          initialAttempt: attempt,
        ),
      ),
    );
  }

  void _openExamIntro(ExamEntity exam) async {
    // If student has already completed and retake is disallowed, go directly to review
    if (exam.hasAttempted &&
        !exam.canTakeExam &&
        exam.myLatestAttempt != null) {
      _openExamReview(exam);
      return;
    }

    final cubit = context.read<ExamsCubit>();
    final isLecture = _isLessonQuiz(exam) || exam.isUntimed;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: ExamIntroPage(exam: exam, isLectureExam: isLecture),
        ),
      ),
    );
    if (mounted && cubit.state is! ExamTakingState) {
      await _loadAll(forceRefresh: true);
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
            onPressed: () => _loadAll(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAll(forceRefresh: true),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ResponsiveContainer(
              maxWidth: ResponsiveBreakpoints.maxContentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.s12),

                  // 1. Mistakes Bank Hero Banner (ALWAYS visible)
                  _buildMistakesBankBanner(context),
                  const SizedBox(height: AppSpacing.s12),

                  // 2. Exams Section via BlocBuilder
                  BlocBuilder<ExamsCubit, ExamsState>(
                    builder: (context, state) {
                      if (state is ExamsLoading) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.s16),
                          child: AppLoadingView.cardsGrid(count: 2, columns: 2),
                        );
                      }

                      if (state is ExamsError) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.s24),
                          child: AppErrorView(
                            message: state.message,
                            onRetry: () => _loadAll(forceRefresh: true),
                          ),
                        );
                      }

                      final List<ExamEntity> allExams =
                          state is StudentExamsLoaded ? state.exams : [];

                      if (state is ExamsEmpty ||
                          (state is StudentExamsLoaded && allExams.isEmpty)) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.s24),
                          child: AppEmptyView(
                            message: state is ExamsEmpty
                                ? state.message
                                : context.l10n.noPublishedExams,
                            subtitle: context.l10n.noPublishedExams,
                            icon: Icons.quiz_outlined,
                          ),
                        );
                      }

                      if (state is StudentExamsLoaded) {
                        final filtered = _filterExams(allExams);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Filter chips row
                            _buildFilterChips(context, allExams),
                            const Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: AppSpacing.s12),

                            // Exams list or filtered empty state
                            if (filtered.isEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.s32,
                                  horizontal: AppSpacing.s16,
                                ),
                                child: AppEmptyView(
                                  message: context.l10n.noExamsInFilter,
                                  subtitle:
                                      context.l10n.noExamsInFilterSubtitle,
                                  icon: Icons.filter_list_off_outlined,
                                ),
                              ),
                            ] else ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s16,
                                ),
                                child: _buildExamsGrid(filtered),
                              ),
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

                            const SizedBox(height: AppSpacing.s32),
                          ],
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMistakesBankBanner(BuildContext context) {
    MistakesCubit? mistakesCubit;
    try {
      mistakesCubit = context.read<MistakesCubit>();
    } catch (_) {}

    if (mistakesCubit == null) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<MistakesCubit, MistakesState>(
      bloc: mistakesCubit,
      builder: (context, mistakesState) {
        MistakeSummaryEntity? summary;
        bool isLoading = mistakesState is MistakesLoading;

        if (mistakesState is MistakesLoaded) {
          summary = mistakesState.summary;
        }

        final unresolvedCount = summary?.unresolvedCount ?? 0;
        final resolvedCount = summary?.resolvedCount ?? 0;
        final totalCount = summary?.totalMistakes ?? 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                context.l10n.mistakesBankTitle,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                              if (unresolvedCount > 0) ...[
                                const SizedBox(width: AppSpacing.s8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s8,
                                    vertical: AppSpacing.s4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSmall,
                                    ),
                                  ),
                                  child: Text(
                                    '$unresolvedCount',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            isLoading
                                ? context.l10n.mistakesBankSubtitle
                                : (unresolvedCount > 0
                                      ? context.l10n
                                            .questionsNeedingReviewCount(
                                              unresolvedCount,
                                            )
                                      : (totalCount > 0
                                            ? context.l10n.allMistakesMastered
                                            : context
                                                  .l10n
                                                  .noMistakesRecordedYet)),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (summary != null && totalCount > 0) ...[
                  const SizedBox(height: AppSpacing.s16),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      _buildMistakeStatChip(
                        icon: Icons.error_outline_rounded,
                        label:
                            '$unresolvedCount ${context.l10n.unresolvedMistakesCount}',
                        color: unresolvedCount > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      _buildMistakeStatChip(
                        icon: Icons.check_circle_outline_rounded,
                        label:
                            '$resolvedCount ${context.l10n.resolvedMistakesCount}',
                        color: AppColors.success,
                      ),
                      _buildMistakeStatChip(
                        icon: Icons.analytics_outlined,
                        label: '$totalCount ${context.l10n.totalMistakesCount}',
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.s16),
                Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s8,
                  children: [
                    if (unresolvedCount > 0)
                      ElevatedButton.icon(
                        onPressed: () =>
                            context.push(AppRoutes.mistakesPractice),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                          context.l10n.startPracticeCount(unresolvedCount),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s16,
                            vertical: AppSpacing.s10,
                          ),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.studentMistakes),
                      icon: const Icon(Icons.auto_stories_outlined, size: 18),
                      label: Text(
                        unresolvedCount > 0
                            ? context.l10n.reviewMistakesBankBtn
                            : context.l10n.mistakesBankBannerAction,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMistakeStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.s6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, List<ExamEntity> allExams) {
    final lectureCount = allExams.where((e) => _isLessonQuiz(e)).length;
    final generalCount = allExams.where((e) => !_isLessonQuiz(e)).length;
    final completedCount = allExams
        .where((e) => e.hasAttempted && !e.hasActiveAttempt)
        .length;

    return Padding(
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
              StudentExamFilter.all,
              allExams.length,
            ),
            const SizedBox(width: AppSpacing.s8),
            _buildFilterChip(
              context.l10n.lectureQuizzesFilter,
              StudentExamFilter.lectureQuizzes,
              lectureCount,
            ),
            const SizedBox(width: AppSpacing.s8),
            _buildFilterChip(
              context.l10n.generalExamsFilter,
              StudentExamFilter.general,
              generalCount,
            ),
            const SizedBox(width: AppSpacing.s8),
            _buildFilterChip(
              context.l10n.filterCompleted,
              StudentExamFilter.completed,
              completedCount,
            ),
          ],
        ),
      ),
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

  Widget _buildExamsGrid(List<ExamEntity> exams) {
    return ResponsiveGrid(
      mobileColumns: 1,
      tabletColumns: 2,
      desktopColumns: 2,
      spacing: AppSpacing.s16,
      runSpacing: AppSpacing.s16,
      children: exams.map((exam) {
        final isLesson = _isLessonQuiz(exam);
        return ExamCard(
          exam: exam,
          isTeacher: false,
          isLessonQuiz: isLesson,
          onTap: () => _openExamIntro(exam),
          onReview:
              exam.hasAttempted && exam.myLatestAttempt?.isSubmitted == true
              ? () => _openExamReview(exam)
              : null,
        );
      }).toList(),
    );
  }
}
