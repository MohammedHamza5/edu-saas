import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
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
import '../dialogs/chapter_edit_dialog.dart';
import '../dialogs/quick_create_chapter_dialog.dart';
import '../utils/teacher_course_actions_helper.dart';
import '../widgets/chapter_analytics_sheet.dart';
import '../widgets/group_analytics_sheet.dart';
import '../widgets/teacher_course_overview_section.dart';
import '../widgets/teacher_course_syllabus_view.dart';

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
  ) async {
    if (_selectedGroupId == null) return;
    final newIndex = currentIndex + delta;
    if (newIndex < 0 || newIndex >= allChapters.length) return;

    final reordered = List<ChapterEntity>.from(allChapters);
    final movedItem = reordered.removeAt(currentIndex);
    reordered.insert(newIndex, movedItem);

    final idsInOrder = reordered.map((c) => c.id).toList();
    await context.read<ContentCubit>().reorderCourseChapters(
          groupId: _selectedGroupId!,
          chapterIdsInOrder: idsInOrder,
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

  Future<void> _handleToggleVisibility(ContentEntity lesson) async {
    if (_selectedGroupId == null) return;
    final newVisibility = !lesson.isPublished;
    final cubit = context.read<ContentCubit>();
    final success = await cubit.toggleLessonVisibility(
      contentId: lesson.id,
      groupId: _selectedGroupId!,
      isPublished: newVisibility,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.lessonVisibilityUpdatedToast),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
      final created = await QuickCreateChapterDialog.show(
        context,
        groupId: _selectedGroupId!,
      );
      if (created != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chapterCreatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      _isCreatingChapter = false;
    }
  }

  Future<void> _handleEditChapter(ChapterEntity chapter) async {
    if (_isEditingChapter) return;
    _isEditingChapter = true;
    try {
      final confirmed = await ChapterEditDialog.show(
        context,
        chapter: chapter,
      );
      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.chapterUpdatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
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
  ) async {
    if (_selectedGroupId == null) return;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 ||
        oldIndex >= chapterLessons.length ||
        newIndex < 0 ||
        newIndex >= chapterLessons.length ||
        oldIndex == newIndex) {
      return;
    }
    final reordered = List<ContentEntity>.from(chapterLessons);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    await context.read<ContentCubit>().reorderChapterLessons(
      groupId: _selectedGroupId!,
      contentIdsInOrder: reordered.map((l) => l.id).toList(),
    );
  }

  Future<void> _handleToggleChapterVisibility(ChapterEntity chapter) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final success = await context.read<ContentCubit>().toggleChapterVisibility(
      chapterId: chapter.id,
      isPublished: !chapter.isPublished,
    );
    if (success && mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            !chapter.isPublished
                ? l10n.chapterPublishedToast
                : l10n.chapterHiddenToast,
          ),
          backgroundColor:
              !chapter.isPublished ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _selectedGroupName != null
        ? context.l10n.groupContentPrefix(_selectedGroupName!)
        : context.l10n.courseBuilderTitle;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.backTooltip,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.teacherDashboard);
            }
          },
        ),
        title: Row(
          children: [
            const Icon(
              Icons.school_rounded,
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
            tooltip: context.l10n.refreshTooltip,
            onPressed: () => _loadContent(forceRefresh: true),
          ),
        ],
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
                        final lessons = state.items;
                        final chapters = state.chapters;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Course Overview Banner Card
                            TeacherCourseOverviewSection(
                              selectedGroupName: _selectedGroupName,
                              lessons: lessons,
                              chapters: chapters,
                              isAllCollapsed: _collapsedChapterIds.length >=
                                  chapters.length,
                              onToggleAllChaptersCollapse: () =>
                                  _toggleAllChaptersCollapse(chapters),
                              onBulkVisibility: _handleBulkVisibility,
                              onOpenGroupAnalytics: () =>
                                  _openGroupAnalytics(chapters, lessons),
                              onAddNewChapter: _handleCreateChapter,
                              onAddLesson: _handleAddLesson,
                            ),

                            // Content Area: Clean, full-width course syllabus
                            Expanded(
                              child: TeacherCourseSyllabusView(
                                scrollController: _scrollController,
                                onRefresh: () =>
                                    _loadContent(forceRefresh: true),
                                chapters: chapters,
                                lessons: lessons,
                                collapsedChapterIds: _collapsedChapterIds,
                                isLoadingMore: state.isLoadingMore,
                                onAddLesson: _handleAddLesson,
                                onToggleChapterCollapse:
                                    _toggleChapterCollapse,
                                onMoveChapter: (idx, delta) =>
                                    _moveChapter(chapters, idx, delta),
                                onChapterAnalytics: _openChapterAnalytics,
                                onAddLessonToChapter: _handleAddLesson,
                                onToggleChapterVisibility:
                                    _handleToggleChapterVisibility,
                                onEditChapter: _handleEditChapter,
                                onDeleteChapter: _handleDeleteChapter,
                                onOpenEditLesson: _openEditLessonPage,
                                onReorderLesson:
                                    _handleReorderLessonsInChapter,
                                onMoveLessonToChapter: (lesson) =>
                                    _handleMoveLessonToChapter(
                                      lesson,
                                      chapters,
                                    ),
                                onLessonAnalytics: _openLessonAnalytics,
                                onDeleteLesson: _confirmDelete,
                                onToggleLessonVisibility:
                                    _handleToggleVisibility,
                              ),
                            ),
                          ],
                        );
                      }

                      // Default empty
                      return const SizedBox.shrink();
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
