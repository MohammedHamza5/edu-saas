import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/mistake_entities.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../cubit/mistakes_cubit.dart';
import '../cubit/mistakes_state.dart';
import '../widgets/exam_card.dart';
import 'exam_intro_page.dart';
import 'exam_result_page.dart';

enum StudentExamFilter { all, available, inProgress, completed }

class StudentExamsPage extends StatefulWidget {
  final String? initialExamId;

  const StudentExamsPage({super.key, this.initialExamId});

  @override
  State<StudentExamsPage> createState() => _StudentExamsPageState();
}

class _StudentExamsPageState extends State<StudentExamsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  StudentExamFilter _activeFilter = StudentExamFilter.all;
  String _searchQuery = '';
  bool _isLoadingAll = false;

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
    _searchController.dispose();
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
    if (_isLoadingAll) return;
    _isLoadingAll = true;
    try {
      // ⚡ Parallelize loading mistakes and student exams in a single round-trip
      final mistakesFuture = () async {
        try {
          await context.read<MistakesCubit>().loadMistakes();
        } catch (_) {}
      }();

      final examsFuture = _loadExams(forceRefresh: forceRefresh);

      await Future.wait<void>([mistakesFuture, examsFuture]);
    } finally {
      if (mounted) {
        _isLoadingAll = false;
      }
    }
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    if (mounted) {
      await context.read<ExamsCubit>().loadStudentExams(
        forceRefresh: forceRefresh,
      );
    }
  }

  bool _isLessonQuiz(ExamEntity exam) {
    if (exam.isLectureExam) return true;
    if (exam.linkedLessonId != null && exam.linkedLessonId!.isNotEmpty) {
      return true;
    }
    final lower = exam.title.toLowerCase();
    return lower.contains('كويز') ||
        lower.contains('quiz') ||
        lower.contains('درس') ||
        lower.contains('محاضرة') ||
        lower.contains('lesson');
  }

  List<ExamEntity> _filterExams(List<ExamEntity> list) {
    List<ExamEntity> filtered;
    switch (_activeFilter) {
      case StudentExamFilter.all:
        filtered = list;
        break;
      case StudentExamFilter.available:
        filtered = list.where((e) => !e.hasAttempted).toList();
        break;
      case StudentExamFilter.inProgress:
        filtered = list.where((e) => e.hasActiveAttempt).toList();
        break;
      case StudentExamFilter.completed:
        filtered = list.where((e) => e.isFullyCompleted).toList();
        break;
    }

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      filtered = filtered.where((e) {
        final title = e.title.toLowerCase();
        final group = (e.groupName ?? '').toLowerCase();
        final folder = (e.folderName ?? '').toLowerCase();
        return title.contains(query) ||
            group.contains(query) ||
            folder.contains(query);
      }).toList();
    }

    return filtered;
  }

  void _openExamResult(ExamEntity exam) async {
    final attempt = exam.myLatestAttempt;
    if (attempt == null) return;
    final isLecture = _isLessonQuiz(exam) || exam.isUntimed;
    final cubit = context.read<ExamsCubit>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: ExamResultPage(
            exam: exam,
            attempt: attempt,
            isLectureExam: isLecture,
          ),
        ),
      ),
    );
    if (mounted) {
      await _loadAll(forceRefresh: true);
    }
  }

  void _openExamIntro(ExamEntity exam) async {
    // If student has already completed and retake is disallowed, go directly to result page
    if (exam.hasAttempted &&
        !exam.canTakeExam &&
        exam.myLatestAttempt != null) {
      _openExamResult(exam);
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
    if (mounted) {
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
          child: ResponsiveContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.s12),

                // 1. Mistakes Bank Hero Banner (ALWAYS visible)
                _buildMistakesBankBanner(context),
                const SizedBox(height: AppSpacing.s12),

                // 2. Exams Section via BlocBuilder
                BlocBuilder<ExamsCubit, ExamsState>(
                  buildWhen: (prev, curr) {
                    if (prev.runtimeType != curr.runtimeType) return true;
                    if (prev is StudentExamsLoaded &&
                        curr is StudentExamsLoaded) {
                      return prev.exams != curr.exams ||
                          prev.isLoadingMore != curr.isLoadingMore ||
                          prev.hasMore != curr.hasMore;
                    }
                    return true;
                  },
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
                        state is StudentExamsLoaded
                        ? state.exams.where((e) => !_isLessonQuiz(e)).toList()
                        : [];

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
                          // 1. Overview Hub / Summary KPI Banner
                          _buildOverviewHub(context, allExams),
                          const SizedBox(height: AppSpacing.s12),

                          // 2. Search Bar
                          _buildSearchBar(context),
                          const SizedBox(height: AppSpacing.s6),

                          // 3. Filter chips row
                          _buildFilterChips(context, allExams),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: AppSpacing.s12),

                          // 4. Exams list or filtered empty state
                          if (filtered.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s32,
                                horizontal: AppSpacing.s16,
                              ),
                              child: AppEmptyView(
                                message: _searchQuery.isNotEmpty
                                    ? context.l10n.noResultsFound
                                    : context.l10n.noExamsInFilter,
                                subtitle: context.l10n.noExamsInFilterSubtitle,
                                icon: _searchQuery.isNotEmpty
                                    ? Icons.search_off_rounded
                                    : Icons.filter_list_off_outlined,
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

                    if (state is ExamTakingState) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_isLoadingAll) {
                          context.read<ExamsCubit>().exitExamTaking();
                          _loadAll(forceRefresh: true);
                        }
                      });
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.s16),
                        child: AppLoadingView.cardsGrid(count: 2, columns: 2),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_isLoadingAll) {
                        _loadAll(forceRefresh: true);
                      }
                    });
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.s16),
                      child: AppLoadingView.cardsGrid(count: 2, columns: 2),
                    );
                  },
                ),
              ],
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
      buildWhen: (prev, curr) {
        if (prev.runtimeType != curr.runtimeType) return true;
        if (prev is MistakesLoaded && curr is MistakesLoaded) {
          return prev.summary != curr.summary;
        }
        return true;
      },
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
                      onPressed: () => context.go(AppRoutes.studentMistakes),
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

  Widget _buildOverviewHub(BuildContext context, List<ExamEntity> allExams) {
    final totalCount = allExams.length;
    final completedCount = allExams.where((e) => e.isFullyCompleted).length;
    final inProgressCount = allExams.where((e) => e.hasActiveAttempt).length;
    final availableCount = allExams.where((e) => !e.hasAttempted).length;
    final overallProgress = totalCount > 0
        ? (completedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s6),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(
                    child: Text(
                      context.l10n.studentExamsOverviewTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: (completedCount == totalCount && totalCount > 0)
                      ? AppColors.success.withValues(alpha: 0.12)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (completedCount == totalCount && totalCount > 0)
                          ? Icons.check_circle_rounded
                          : Icons.pie_chart_outline_rounded,
                      size: 13,
                      color: (completedCount == totalCount && totalCount > 0)
                          ? AppColors.success
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(overallProgress * 100).toInt()}% ${context.l10n.studentExamsOverallProgress}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: (completedCount == totalCount && totalCount > 0)
                            ? AppColors.success
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: overallProgress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                overallProgress >= 1.0
                    ? AppColors.success
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          LayoutBuilder(
            builder: (context, kpiConstraints) {
              final isVeryNarrow = kpiConstraints.maxWidth < 340;
              if (isVeryNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiTile(
                            title: context.l10n.studentExamsStatsTotal,
                            count: totalCount,
                            icon: Icons.assignment_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            isSelected: _activeFilter == StudentExamFilter.all,
                            onTap: () => setState(
                              () => _activeFilter = StudentExamFilter.all,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: _buildKpiTile(
                            title: context.l10n.studentExamsStatsCompleted,
                            count: completedCount,
                            icon: Icons.check_circle_rounded,
                            color: AppColors.success,
                            isSelected:
                                _activeFilter == StudentExamFilter.completed,
                            onTap: () => setState(
                              () => _activeFilter = StudentExamFilter.completed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiTile(
                            title: context.l10n.studentExamsStatsInProgress,
                            count: inProgressCount,
                            icon: Icons.hourglass_top_rounded,
                            color: AppColors.warning,
                            isSelected:
                                _activeFilter == StudentExamFilter.inProgress,
                            onTap: () => setState(
                              () =>
                                  _activeFilter = StudentExamFilter.inProgress,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: _buildKpiTile(
                            title: context.l10n.studentExamsStatsAvailable,
                            count: availableCount,
                            icon: Icons.rocket_launch_outlined,
                            color: const Color(0xFF0284C7),
                            isSelected:
                                _activeFilter == StudentExamFilter.available,
                            onTap: () => setState(
                              () => _activeFilter = StudentExamFilter.available,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildKpiTile(
                      title: context.l10n.studentExamsStatsTotal,
                      count: totalCount,
                      icon: Icons.assignment_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      isSelected: _activeFilter == StudentExamFilter.all,
                      onTap: () =>
                          setState(() => _activeFilter = StudentExamFilter.all),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: _buildKpiTile(
                      title: context.l10n.studentExamsStatsCompleted,
                      count: completedCount,
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      isSelected: _activeFilter == StudentExamFilter.completed,
                      onTap: () => setState(
                        () => _activeFilter = StudentExamFilter.completed,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: _buildKpiTile(
                      title: context.l10n.studentExamsStatsInProgress,
                      count: inProgressCount,
                      icon: Icons.hourglass_top_rounded,
                      color: AppColors.warning,
                      isSelected: _activeFilter == StudentExamFilter.inProgress,
                      onTap: () => setState(
                        () => _activeFilter = StudentExamFilter.inProgress,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: _buildKpiTile(
                      title: context.l10n.studentExamsStatsAvailable,
                      count: availableCount,
                      icon: Icons.rocket_launch_outlined,
                      color: const Color(0xFF0284C7),
                      isSelected: _activeFilter == StudentExamFilter.available,
                      onTap: () => setState(
                        () => _activeFilter = StudentExamFilter.available,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s6,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : AppColors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: context.l10n.examSearchPlaceholder,
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textSecondary,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip: context.l10n.clearSearchTooltip,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s10,
          ),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
        ),
        onChanged: (val) {
          setState(() => _searchQuery = val);
        },
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, List<ExamEntity> allExams) {
    final availableCount = allExams.where((e) => !e.hasAttempted).length;
    final inProgressCount = allExams.where((e) => e.hasActiveAttempt).length;
    final completedCount = allExams.where((e) => e.isFullyCompleted).length;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s6,
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
              context.l10n.filterNotStarted,
              StudentExamFilter.available,
              availableCount,
            ),
            const SizedBox(width: AppSpacing.s8),
            _buildFilterChip(
              context.l10n.attemptStatusInProgress,
              StudentExamFilter.inProgress,
              inProgressCount,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        if (width < 640) {
          crossAxisCount = 1;
        } else if (width < 1100) {
          crossAxisCount = 2;
        } else if (width < 1550) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 4;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.s16,
            mainAxisSpacing: AppSpacing.s16,
            mainAxisExtent: 340,
          ),
          itemCount: exams.length,
          itemBuilder: (context, index) {
            final exam = exams[index];
            return ExamCard(
              exam: exam,
              isTeacher: false,
              isLessonQuiz: false,
              onTap: () => _openExamIntro(exam),
              onReview:
                  exam.hasAttempted && exam.myLatestAttempt?.isSubmitted == true
                  ? () => _openExamResult(exam)
                  : null,
            );
          },
        );
      },
    );
  }
}
