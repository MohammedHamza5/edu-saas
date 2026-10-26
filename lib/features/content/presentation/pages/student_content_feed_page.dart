import 'dart:async';
import 'package:edu_saas/features/groups/domain/entities/group_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../../../core/utils/group_slug_resolver.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';
import '../cubit/course_progress_cubit.dart';
import '../cubit/course_progress_state.dart';
import '../utils/student_content_navigation_helper.dart';
import '../utils/student_content_quiz_launcher.dart';
import '../widgets/student_content_slivers_view.dart';
import '../widgets/student_content_toolbar.dart';
import '../widgets/student_group_switcher_bar.dart';
import '../widgets/student_mission_command_deck.dart';

class StudentContentFeedPage extends StatefulWidget {
  final String groupId;
  final String? groupName;

  const StudentContentFeedPage({
    super.key,
    required this.groupId,
    this.groupName,
  });

  @override
  State<StudentContentFeedPage> createState() => _StudentContentFeedPageState();
}

class _StudentContentFeedPageState extends State<StudentContentFeedPage> {
  final ScrollController _scrollController = ScrollController();
  late String _activeGroupId;
  late String? _activeGroupName;
  List<GroupEntity> _studentGroups = [];
  ContentType? _selectedTypeFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRoadmapMode = true;
  bool _isOpeningQuiz = false;
  final Set<String> _expandedChapterIds = {};

  String? get _currentUserId {
    try {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        return authState.user.id;
      }
    } catch (_) {}
    return AppCache.currentUserId;
  }

  @override
  void initState() {
    super.initState();
    _activeGroupId = GroupSlugResolver.toId(widget.groupId);
    _activeGroupName = widget.groupName;
    _initializeFeed();
  }

  void _initializeFeed() {
    if (GroupSlugResolver.isUuid(_activeGroupId)) {
      unawaited(
        context.read<CourseProgressCubit>().loadCourseProgress(
              _activeGroupId,
              studentId: _currentUserId,
            ),
      );
    }
    unawaited(_fetchStudentGroups());
  }

  Future<void> _fetchStudentGroups() async {
    try {
      final result = await InjectionContainer.groupsRepository.getGroups();
      if (mounted && result.isSuccess && result.dataOrNull != null) {
        final groups = result.dataOrNull!;
        for (final g in groups) {
          GroupSlugResolver.registerGroup(g.id, g.name);
        }

        final hadValidUuidBefore = GroupSlugResolver.isUuid(_activeGroupId);
        final previousId = _activeGroupId;

        setState(() {
          _studentGroups = groups;
          final match = _studentGroups.where((g) {
            return g.id == _activeGroupId ||
                g.id == widget.groupId ||
                GroupSlugResolver.toSlug(g.id, g.name).toLowerCase() ==
                    widget.groupId.toLowerCase() ||
                g.name.toLowerCase() == widget.groupId.toLowerCase();
          });

          if (match.isNotEmpty) {
            _activeGroupId = match.first.id;
            _activeGroupName = match.first.name;
          } else if (_studentGroups.isNotEmpty &&
              !GroupSlugResolver.isUuid(_activeGroupId)) {
            _activeGroupId = _studentGroups.first.id;
            _activeGroupName = _studentGroups.first.name;
          }
        });

        if (mounted &&
            (!hadValidUuidBefore || _activeGroupId != previousId) &&
            GroupSlugResolver.isUuid(_activeGroupId)) {
          unawaited(
            context.read<CourseProgressCubit>().loadCourseProgress(
                  _activeGroupId,
                  studentId: _currentUserId,
                ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        unawaited(
          context.read<CourseProgressCubit>().loadCourseProgress(
                _activeGroupId,
                studentId: _currentUserId,
              ),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleContentTap(
    LessonAssignmentEntity item, {
    int? index,
    int? totalCount,
  }) async {
    await StudentContentNavigationHelper.handleContentTap(
      context: context,
      item: item,
      activeGroupId: _activeGroupId,
      activeGroupName: _activeGroupName,
      onTakeQuiz: _handleTakeQuiz,
      index: index,
      totalCount: totalCount,
    );

    if (mounted) {
      unawaited(
        context.read<CourseProgressCubit>().loadCourseProgress(
              _activeGroupId,
              studentId: _currentUserId,
            ),
      );
    }
  }

  Future<void> _handleTakeQuiz(LessonAssignmentEntity item) async {
    if (_isOpeningQuiz) return;
    setState(() => _isOpeningQuiz = true);
    try {
      await StudentContentQuizLauncher.takeQuiz(
        context: context,
        item: item,
        activeGroupId: _activeGroupId,
        currentUserId: _currentUserId,
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningQuiz = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _activeGroupName != null
        ? context.l10n.groupContentPrefix(_activeGroupName!)
        : context.l10n.groupContentDefault;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.backToStudentDashboard,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.studentDashboard),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.menu_book_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refreshContent,
            onPressed: () => context
                .read<CourseProgressCubit>()
                .loadCourseProgress(_activeGroupId, studentId: _currentUserId),
          ),
        ],
      ),
      body: Stack(
        children: [
          BlocConsumer<CourseProgressCubit, CourseProgressState>(
            listener: (context, state) {
              if (state is CourseProgressError) {
                AppFeedback.showError(context, state.message);
              }
            },
            builder: (context, state) {
              if (state is CourseProgressInitial ||
                  state is CourseProgressLoading) {
                return const AppLoadingView.cardsGrid(count: 4, columns: 2);
              }

              if (state is CourseProgressError) {
                final userFriendlyMessage = _isTechnicalError(state.message)
                    ? context.l10n.errorOccurred
                    : state.message;

                return AppErrorView(
                  message: userFriendlyMessage,
                  onRetry: () async {
                    final cubit = context.read<CourseProgressCubit>();
                    await _fetchStudentGroups();
                    if (!mounted) return;
                    if (GroupSlugResolver.isUuid(_activeGroupId)) {
                      unawaited(
                        cubit.loadCourseProgress(
                          _activeGroupId,
                          studentId: _currentUserId,
                        ),
                      );
                    }
                  },
                );
              }

              if (state is CourseProgressLoaded) {
                final videoLectures = state.lessons
                    .where((i) => i.type == ContentType.video)
                    .toList();
                final allPublished = videoLectures.isNotEmpty
                    ? videoLectures
                    : state.lessons;
                final completedCount = allPublished
                    .where((i) => i.isEffectivelyCompleted)
                    .length;
                final totalPublishedCount = allPublished.length;
                final overallProgressPct = totalPublishedCount > 0
                    ? ((completedCount / totalPublishedCount) * 100).toInt()
                    : 0;

                LessonAssignmentEntity? nextLesson;
                int? nextLessonIndex;
                for (int i = 0; i < allPublished.length; i++) {
                  final it = allPublished[i];
                  if (!it.isEffectivelyCompleted && !it.isLocked) {
                    nextLesson = it;
                    nextLessonIndex = i + 1;
                    break;
                  }
                }
                if (nextLesson == null) {
                  for (int i = 0; i < allPublished.length; i++) {
                    final it = allPublished[i];
                    if (!it.isEffectivelyCompleted) {
                      nextLesson = it;
                      nextLessonIndex = i + 1;
                      break;
                    }
                  }
                }

                var items = _selectedTypeFilter == null
                    ? allPublished
                    : allPublished
                        .where((i) => i.type == _selectedTypeFilter)
                        .toList();

                if (_searchQuery.isNotEmpty) {
                  items = items
                      .where(
                        (i) =>
                            i.title.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ||
                            (i.description?.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ??
                                false) ||
                            (i.pdfFileName?.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ??
                                false),
                      )
                      .toList();
                }

                return ResponsiveContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                  ),
                  child: RefreshIndicator(
                    onRefresh: () async =>
                        context.read<CourseProgressCubit>().loadCourseProgress(
                              _activeGroupId,
                              studentId: _currentUserId,
                            ),
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (_studentGroups.length > 1)
                          SliverToBoxAdapter(
                            child: StudentGroupSwitcherBar(
                              groups: _studentGroups,
                              activeGroupId: _activeGroupId,
                              onGroupSelected: (g) {
                                setState(() {
                                  _activeGroupId = g.id;
                                  _activeGroupName = g.name;
                                  _selectedTypeFilter = null;
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _expandedChapterIds.clear();
                                });
                                context
                                    .read<CourseProgressCubit>()
                                    .loadCourseProgress(
                                      g.id,
                                      studentId: _currentUserId,
                                    );
                              },
                            ),
                          ),
                        if (allPublished.isNotEmpty)
                          SliverToBoxAdapter(
                            child: StudentMissionCommandDeck(
                              nextLesson: nextLesson,
                              nextLessonIndex: nextLessonIndex,
                              completedCount: completedCount,
                              totalCount: totalPublishedCount,
                              overallPercentage: overallProgressPct,
                              groupName: _activeGroupName ?? '',
                              onResume: nextLesson != null
                                  ? () => _handleContentTap(
                                        nextLesson!,
                                        index: nextLessonIndex,
                                        totalCount: totalPublishedCount,
                                      )
                                  : null,
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: StudentContentToolbar(
                            isRoadmapMode: _isRoadmapMode,
                            onToggleViewMode: (val) =>
                                setState(() => _isRoadmapMode = val),
                            searchController: _searchController,
                            searchQuery: _searchQuery,
                            onSearchChanged: (val) =>
                                setState(() => _searchQuery = val.trim()),
                            onClearSearch: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            allPublished: allPublished,
                            selectedTypeFilter: _selectedTypeFilter,
                            onSelectTypeFilter: (filter) =>
                                setState(() => _selectedTypeFilter = filter),
                          ),
                        ),
                        if (allPublished.isEmpty && state.chapters.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Center(
                                child: AppEmptyView(
                                  message: context.l10n.courseBeingPreparedTitle,
                                  subtitle:
                                      context.l10n.courseBeingPreparedSubtitle,
                                  icon: Icons.school_outlined,
                                ),
                              ),
                            ),
                          )
                        else if (items.isEmpty && state.chapters.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.search_off_rounded,
                                      size: 48,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(height: AppSpacing.s12),
                                    Text(
                                      context.l10n.noMatchingContentFound(
                                        _searchQuery,
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          StudentContentSliversView(
                            items: items,
                            chapters: state.chapters,
                            isRoadmapMode: _isRoadmapMode,
                            selectedTypeFilter: _selectedTypeFilter,
                            searchQuery: _searchQuery,
                            expandedChapterIds: _expandedChapterIds,
                            onToggleChapter: (key) {
                              setState(() {
                                if (_expandedChapterIds.contains(key)) {
                                  _expandedChapterIds.remove(key);
                                } else {
                                  _expandedChapterIds.add(key);
                                }
                              });
                            },
                            onLessonTap: (item, globalIndex, totalCount) =>
                                _handleContentTap(
                              item,
                              index: globalIndex,
                              totalCount: totalCount,
                            ),
                            onOpenHandout: (item) =>
                                StudentContentNavigationHelper.openHandout(
                              context: context,
                              item: item,
                            ),
                            onTakeQuiz: (item) => _handleTakeQuiz(item),
                          ),
                      ],
                    ),
                  ),
                );
              }

              return const AppLoadingView.cardsGrid(count: 4, columns: 2);
            },
          ),
          if (_isOpeningQuiz)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s24,
                        vertical: AppSpacing.s16,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Text(
                            context.l10n.loading,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isTechnicalError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('exception') ||
        lower.contains('postgres') ||
        lower.contains('sql') ||
        lower.contains('syntax') ||
        lower.contains('null') ||
        lower.contains('undefined') ||
        lower.contains('code:');
  }
}
