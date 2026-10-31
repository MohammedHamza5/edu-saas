import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../utils/teacher_course_actions_helper.dart';
import '../widgets/chapter_analytics_sheet.dart';
import '../widgets/group_analytics_sheet.dart';
import '../widgets/teacher_course_app_bar.dart';
import '../widgets/teacher_course_loaded_view.dart';

/// The Course Builder page (formerly TeacherContentLibraryPage).
///
/// Here the teacher selects a Course (Group) and manages the sequential
/// Lessons (Videos + Quizzes + PDFs) that belong to it.
class TeacherContentLibraryPage extends StatefulWidget {
  final String? groupId;
  final String? groupName;
  final ContentEntity? preselectedVideo;

  const TeacherContentLibraryPage({
    super.key,
    this.groupId,
    this.groupName,
    this.preselectedVideo,
  });

  @override
  State<TeacherContentLibraryPage> createState() =>
      _TeacherContentLibraryPageState();
}

class _TeacherContentLibraryPageState extends State<TeacherContentLibraryPage> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedGroupId;
  String? _selectedGroupName;
  bool _isCreatingChapter = false;
  bool _isEditingChapter = false;
  final Set<String> _collapsedChapterIds = {};

  void _toggleChapterCollapse(String chapterId) {
    setState(() {
      if (_collapsedChapterIds.contains(chapterId)) {
        _collapsedChapterIds.remove(chapterId);
      } else {
        _collapsedChapterIds.add(chapterId);
      }
    });
  }

  void _toggleAllChaptersCollapse(List<ChapterEntity> allChapters) {
    setState(() {
      if (_collapsedChapterIds.length >= allChapters.length) {
        _collapsedChapterIds.clear();
      } else {
        _collapsedChapterIds.addAll(allChapters.map((c) => c.id));
      }
    });
  }

  Future<void> _moveChapter(
    List<ChapterEntity> allChapters,
    int currentIndex,
    int delta,
  ) {
    if (_selectedGroupId == null) return Future.value();
    return TeacherCourseActionsHelper.moveChapter(
      cubit: context.read<ContentCubit>(),
      groupId: _selectedGroupId!,
      allChapters: allChapters,
      currentIndex: currentIndex,
      delta: delta,
    );
  }

  void _openChapterAnalytics(
    ChapterEntity chapter,
    List<ContentEntity> chapterLessons,
  ) {
    if (_selectedGroupId == null) return;
    ChapterAnalyticsSheet.show(
      context,
      groupId: _selectedGroupId!,
      chapter: chapter,
      chapterLessons: chapterLessons,
    );
  }

  void _openGroupAnalytics(
    List<ChapterEntity> chapters,
    List<ContentEntity> lessons,
  ) {
    if (_selectedGroupId == null) return;
    GroupAnalyticsSheet.show(
      context,
      groupId: _selectedGroupId!,
      groupName: _selectedGroupName ?? '',
      chapters: chapters,
      lessons: lessons,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.preselectedVideo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedGroupId != null) {
          _openEditLessonPage(widget.preselectedVideo!);
        }
      });
    }
    final initialId =
        widget.groupId ?? TeacherGroupFilterBar.lastSelectedGroupId;
    GroupsState? groupsState;
    try {
      groupsState = context.read<GroupsCubit>().state;
    } catch (_) {}

    if (initialId != null) {
      _selectedGroupId = initialId;
      _selectedGroupName = widget.groupName;
      if (_selectedGroupName == null && groupsState is GroupsLoaded) {
        _selectedGroupName = groupsState.groups
            .where((g) => g.id == initialId)
            .firstOrNull
            ?.name;
      }
    } else if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
      _selectedGroupId = groupsState.groups.first.id;
      _selectedGroupName = groupsState.groups.first.name;
    }

    if (_selectedGroupId != null) {
      unawaited(
        context.read<ContentCubit>().loadGroupContent(_selectedGroupId!),
      );
    }
    _scrollController.addListener(_onScroll);
    try {
      context.read<GroupsCubit>().loadGroups();
    } catch (_) {}
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      unawaited(context.read<ContentCubit>().loadMoreContent());
    }
  }

  void _onGroupChanged(GroupEntity group) {
    if (_selectedGroupId == group.id) return;
    TeacherGroupFilterBar.lastSelectedGroupId = group.id;
    setState(() {
      _selectedGroupId = group.id;
      _selectedGroupName = group.name;
    });
    _loadContent();
  }

  Future<void> _loadContent({bool forceRefresh = false}) async {
    if (_selectedGroupId != null) {
      unawaited(
        context.read<ContentCubit>().loadGroupContent(
          _selectedGroupId!,
          forceRefresh: forceRefresh,
        ),
      );
    }
  }

  Future<void> _handleAddLesson({String? chapterId}) async {
    if (_selectedGroupId == null) return;
    final chParam = chapterId != null ? '&chapterId=$chapterId' : '';
    await context.push(
      '/teacher/groups/$_selectedGroupId/lessons/new?name=${Uri.encodeComponent(_selectedGroupName ?? "")}$chParam',
    );
    if (mounted) {
      await _loadContent(forceRefresh: true);
    }
  }

  Future<void> _openEditLessonPage(ContentEntity lesson) async {
    if (_selectedGroupId == null) return;
    await context.push(
      '/teacher/groups/$_selectedGroupId/lessons/${lesson.id}?name=${Uri.encodeComponent(_selectedGroupName ?? "")}',
    );
    if (mounted) {
      await _loadContent(forceRefresh: true);
      if (!context.mounted) return;
    }
  }

  Future<void> _openLessonAnalytics(ContentEntity lesson) async {
    if (_selectedGroupId == null) return;
    await context.push(
      '/teacher/groups/$_selectedGroupId/lessons/${lesson.id}?name=${Uri.encodeComponent(_selectedGroupName ?? "")}&tab=analytics',
    );
    if (mounted) {
      await _loadContent(forceRefresh: true);
      if (!context.mounted) return;
    }
  }

  Future<void> _confirmDelete(ContentEntity item) {
    return TeacherCourseActionsHelper.confirmDeleteLesson(
      context: context,
      item: item,
      cubit: context.read<ContentCubit>(),
    );
  }

  Future<void> _handleToggleVisibility(ContentEntity lesson) {
    if (_selectedGroupId == null) return Future.value();
    return TeacherCourseActionsHelper.handleToggleLessonVisibility(
      context: context,
      cubit: context.read<ContentCubit>(),
      groupId: _selectedGroupId!,
      lesson: lesson,
    );
  }

  Future<void> _handleBulkVisibility(bool isPublished) {
    if (_selectedGroupId == null) return Future.value();
    return TeacherCourseActionsHelper.handleBulkVisibility(
      context: context,
      cubit: context.read<ContentCubit>(),
      groupId: _selectedGroupId!,
      isPublished: isPublished,
    );
  }

  Future<void> _handleCreateChapter() async {
    if (_selectedGroupId == null || _isCreatingChapter) return;
    _isCreatingChapter = true;
    try {
      await TeacherCourseActionsHelper.handleCreateChapter(
        context: context,
        groupId: _selectedGroupId!,
      );
    } finally {
      _isCreatingChapter = false;
    }
  }

  Future<void> _handleEditChapter(ChapterEntity chapter) async {
    if (_isEditingChapter) return;
    _isEditingChapter = true;
    try {
      await TeacherCourseActionsHelper.handleEditChapter(
        context: context,
        chapter: chapter,
      );
    } finally {
      _isEditingChapter = false;
    }
  }

  Future<void> _handleDeleteChapter(ChapterEntity chapter) {
    return TeacherCourseActionsHelper.handleDeleteChapter(
      context: context,
      cubit: context.read<ContentCubit>(),
      chapter: chapter,
    );
  }

  Future<void> _handleMoveLessonToChapter(
    ContentEntity lesson,
    List<ChapterEntity> chapters,
  ) {
    if (_selectedGroupId == null) return Future.value();
    return TeacherCourseActionsHelper.handleMoveLessonToChapter(
      context: context,
      cubit: context.read<ContentCubit>(),
      groupId: _selectedGroupId!,
      lesson: lesson,
      chapters: chapters,
    );
  }

  Future<void> _handleReorderLessonsInChapter(
    List<ContentEntity> chapterLessons,
    int oldIndex,
    int newIndex,
  ) {
    if (_selectedGroupId == null) return Future.value();
    return TeacherCourseActionsHelper.reorderLessonsInChapter(
      cubit: context.read<ContentCubit>(),
      groupId: _selectedGroupId!,
      chapterLessons: chapterLessons,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
  }

  Future<void> _handleToggleChapterVisibility(ChapterEntity chapter) {
    return TeacherCourseActionsHelper.handleToggleChapterVisibility(
      context: context,
      cubit: context.read<ContentCubit>(),
      chapter: chapter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: TeacherCourseAppBar(
        selectedGroupName: _selectedGroupName,
        onRefresh: () => _loadContent(forceRefresh: true),
      ),
      floatingActionButton:
          (_selectedGroupId == null || MediaQuery.of(context).size.width >= 960)
          ? null
          : FloatingActionButton.extended(
              onPressed: _handleAddLesson,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.addLessonButton),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
      body: ResponsiveContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Group Selector Bar (Full width, top of page)
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.s12,
                bottom: AppSpacing.s8,
              ),
              child: TeacherGroupFilterBar(
                selectedGroupId: _selectedGroupId,
                onGroupChanged: _onGroupChanged,
                onRefresh: () => _loadContent(forceRefresh: true),
              ),
            ),

            // 2. Main Content Area
            Expanded(
              child: Builder(
                builder: (context) {
                  GroupsCubit? groupsCubit;
                  try {
                    groupsCubit = context.read<GroupsCubit>();
                  } catch (_) {
                    groupsCubit = null;
                  }

                  Widget bodyContent = BlocBuilder<ContentCubit, ContentState>(
                    builder: (context, state) {
                      if (state is ContentLoading) {
                        return const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.s12),
                          child: AppLoadingView.cardsGrid(
                            count: 4,
                            columns: 1,
                          ),
                        );
                      }

                      if (state is ContentError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: AppErrorView(
                              message: state.message,
                              onRetry: () => _loadContent(forceRefresh: true),
                            ),
                          ),
                        );
                      }

                      if (state is ContentLoaded) {
                        return TeacherCourseLoadedView(
                          selectedGroupName: _selectedGroupName,
                          lessons: state.items,
                          chapters: state.chapters,
                          collapsedChapterIds: _collapsedChapterIds,
                          isLoadingMore: state.isLoadingMore,
                          scrollController: _scrollController,
                          onRefresh: () => _loadContent(forceRefresh: true),
                          onAddLesson: _handleAddLesson,
                          onToggleChapterCollapse: _toggleChapterCollapse,
                          onToggleAllChaptersCollapse: () =>
                              _toggleAllChaptersCollapse(state.chapters),
                          onMoveChapter: (idx, delta) =>
                              _moveChapter(state.chapters, idx, delta),
                          onChapterAnalytics: _openChapterAnalytics,
                          onToggleChapterVisibility:
                              _handleToggleChapterVisibility,
                          onEditChapter: _handleEditChapter,
                          onDeleteChapter: _handleDeleteChapter,
                          onOpenEditLesson: _openEditLessonPage,
                          onReorderLesson: _handleReorderLessonsInChapter,
                          onMoveLessonToChapter: (lesson) =>
                              _handleMoveLessonToChapter(
                            lesson,
                            state.chapters,
                          ),
                          onLessonAnalytics: _openLessonAnalytics,
                          onDeleteLesson: _confirmDelete,
                          onToggleLessonVisibility: _handleToggleVisibility,
                          onBulkVisibility: _handleBulkVisibility,
                          onOpenGroupAnalytics: () =>
                              _openGroupAnalytics(state.chapters, state.items),
                          onAddNewChapter: _handleCreateChapter,
                        );
                      }

                      // Default loading skeleton while resolving group
                      return const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.s12),
                        child: AppLoadingView.cardsGrid(
                          count: 4,
                          columns: 1,
                        ),
                      );
                    },
                  );

                  if (groupsCubit != null) {
                    bodyContent = BlocListener<GroupsCubit, GroupsState>(
                      bloc: groupsCubit,
                      listener: (context, groupsState) {
                        if (groupsState is GroupsLoaded &&
                            _selectedGroupId == null &&
                            groupsState.groups.isNotEmpty) {
                          setState(() {
                            _selectedGroupId = groupsState.groups.first.id;
                            _selectedGroupName =
                                groupsState.groups.first.name;
                          });
                          _loadContent();
                        }
                      },
                      child: bodyContent,
                    );
                  }

                  return bodyContent;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
