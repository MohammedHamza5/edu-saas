import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/academic_momentum_entity.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../cubit/mistakes_cubit.dart';
import '../cubit/mistakes_state.dart';
import '../utils/student_exams_filter_helper.dart';
import '../widgets/exam_folders_bar.dart';
import '../widgets/momentum/student_academic_momentum_card.dart';
import '../widgets/student_exams_filter_bar.dart';
import '../widgets/student_exams_grid_view.dart';
import '../widgets/student_exams_overview_hub.dart';
import '../widgets/student_mistakes_bank_banner.dart';
import 'exam_intro_page.dart';
import 'exam_result_page.dart';

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
          } catch (_) {}
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

  void _openExamResult(ExamEntity exam) async {
    final attempt = exam.myLatestAttempt ??
        (exam.hasAttempted || exam.myBestScore != null
            ? ExamAttemptEntity(
                id: '',
                examId: exam.id,
                examVersionId: exam.activeVersion?.id ?? '',
                studentId: '',
                startedAt: DateTime.now(),
                submittedAt: DateTime.now(),
                score: exam.myBestScore ?? 0,
                percentage: exam.maxScore > 0
                    ? ((exam.myBestScore ?? 0) / exam.maxScore) * 100
                    : 0,
                status: AttemptStatus.submitted,
              )
            : null);
    if (attempt == null) return;
    final isLecture =
        StudentExamsFilterHelper.isLessonQuiz(exam) || exam.isUntimed;
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
    if (exam.hasAttempted &&
        !exam.canTakeExam &&
        (exam.myLatestAttempt != null || exam.myBestScore != null)) {
      _openExamResult(exam);
      return;
    }

    final cubit = context.read<ExamsCubit>();
    final isLecture =
        StudentExamsFilterHelper.isLessonQuiz(exam) || exam.isUntimed;
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

  Widget _buildAcademicMomentumCard(
    BuildContext context,
    List<ExamEntity> exams,
  ) {
    int unresolved = 0;
    int resolved = 0;
    try {
      final mistakesCubit = context.read<MistakesCubit>();
      final state = mistakesCubit.state;
      if (state is MistakesLoaded) {
        unresolved = state.unresolvedCountInList;
        resolved = state.resolvedCountInList;
      }
    } catch (_) {}

    final momentum = AcademicMomentumEntity.calculate(
      exams: exams,
      unresolvedMistakes: unresolved,
      resolvedMistakes: resolved,
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: StudentAcademicMomentumCard(momentum: momentum),
    );
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
            icon: const Icon(Icons.bookmark_border_rounded),
            tooltip: context.l10n.savedQuestionsVaultTitle,
            onPressed: () => context.push(AppRoutes.studentSavedQuestions),
          ),
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
                const StudentMistakesBankBanner(),
                const SizedBox(height: AppSpacing.s12),

                // 2. Exams Section via BlocConsumer
                BlocConsumer<ExamsCubit, ExamsState>(
                  listenWhen: (prev, curr) =>
                      prev is ExamTakingState && curr is! ExamTakingState,
                  listener: (context, state) {
                    try {
                      context
                          .read<MistakesCubit>()
                          .loadMistakes(forceRefresh: true);
                    } catch (_) {}
                  },
                  buildWhen: (prev, curr) {
                    return curr is StudentExamsLoaded ||
                        curr is ExamsLoading ||
                        curr is ExamsError ||
                        curr is ExamsEmpty ||
                        curr is ExamsInitial;
                  },
                  builder: (context, state) {
                    if (state is ExamsInitial) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _loadAll();
                        }
                      });
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.s16),
                        child: AppLoadingView.cardsGrid(count: 2, columns: 2),
                      );
                    }

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

                    if (state is ExamsEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.s24),
                        child: AppEmptyView(
                          message: state.message,
                          subtitle: context.l10n.noPublishedExams,
                          icon: Icons.quiz_outlined,
                        ),
                      );
                    }

                    if (state is StudentExamsLoaded) {
                      final summary = StudentExamsFilterHelper.computeSummary(
                        rawExams: state.exams,
                        selectedFolderId: state.selectedFolderId,
                        activeFilter: _activeFilter,
                        searchQuery: _searchQuery,
                      );

                      if (summary.allExams.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.s24),
                          child: AppEmptyView(
                            message: context.l10n.noPublishedExams,
                            subtitle: context.l10n.noPublishedExams,
                            icon: Icons.quiz_outlined,
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 0. Academic Momentum Card
                          _buildAcademicMomentumCard(context, summary.allExams),
                          const SizedBox(height: AppSpacing.s12),

                          // 1. Overview Hub / Summary KPI Banner
                          StudentExamsOverviewHub(
                            allExams: summary.allExams,
                            activeFilter: _activeFilter,
                            onFilterChanged: (filter) =>
                                setState(() => _activeFilter = filter),
                          ),
                          const SizedBox(height: AppSpacing.s12),

                          // 2. Exam Folders Bar
                          if (summary.studentFolders.isNotEmpty) ...[
                            ExamFoldersBar(
                              folders: summary.studentFolders,
                              selectedFolderId: state.selectedFolderId,
                              totalExamsCount: summary.allExams.length,
                              uncategorizedCount: summary.uncategorizedCount,
                              onSelectFolder: (String? fId) => context
                                  .read<ExamsCubit>()
                                  .selectStudentFolder(fId),
                            ),
                            const SizedBox(height: AppSpacing.s6),
                          ],

                          // 3. Search and Filter Chips Bar
                          StudentExamsFilterBar(
                            searchController: _searchController,
                            searchQuery: _searchQuery,
                            onSearchChanged: (val) =>
                                setState(() => _searchQuery = val),
                            onClearSearch: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            folderScopedExams: summary.folderScopedExams,
                            activeFilter: _activeFilter,
                            onFilterChanged: (filter) =>
                                setState(() => _activeFilter = filter),
                          ),
                          const SizedBox(height: AppSpacing.s12),

                          // 4. Exams list or filtered empty state
                          if (summary.filteredExams.isEmpty) ...[
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
                              child: StudentExamsGridView(
                                exams: summary.filteredExams,
                                onTapExam: _openExamIntro,
                                onReviewExam: _openExamResult,
                              ),
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
}
