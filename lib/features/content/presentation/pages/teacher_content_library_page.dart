import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';

import '../widgets/course_lesson_tile.dart';
import '../widgets/chapter_analytics_sheet.dart';
import '../widgets/group_analytics_sheet.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';

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
    try {
      context.read<GroupsCubit>().loadGroups();
    } catch (_) {}
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
    }
  }

  Future<void> _openLessonAnalytics(ContentEntity lesson) async {
    if (_selectedGroupId == null) return;
    await context.push(
      '/teacher/groups/$_selectedGroupId/lessons/${lesson.id}?name=${Uri.encodeComponent(_selectedGroupName ?? "")}&tab=analytics',
    );
    if (mounted) {
      await _loadContent(forceRefresh: true);
    }
  }

  Future<void> _confirmDelete(ContentEntity item) async {
    final cubit = context.read<ContentCubit>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.deleteItemConfirmMessage(item.title)),
            const SizedBox(height: AppSpacing.s12),
            Text(
              ctx.l10n.deleteLessonSmartNote,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(ctx.l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirm == true) {
      unawaited(cubit.deleteContent(item.id));
    }
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

  Future<void> _handleBulkVisibility(bool isPublished) async {
    if (_selectedGroupId == null) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isPublished
              ? l10n.publishAllLessonsConfirmTitle
              : l10n.hideAllLessonsConfirmTitle,
        ),
        content: Text(
          isPublished
              ? l10n.publishAllLessonsConfirmMessage
              : l10n.hideAllLessonsConfirmMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPublished
                  ? AppColors.success
                  : AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: Text(
              isPublished
                  ? l10n.publishAllLessonsAction
                  : l10n.hideAllLessonsAction,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final cubit = context.read<ContentCubit>();
      final success = await cubit.toggleAllLessonsVisibility(
        groupId: _selectedGroupId!,
        isPublished: isPublished,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.allLessonsVisibilityUpdatedToast),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleCreateChapter() async {
    if (_selectedGroupId == null || _isCreatingChapter) return;
    _isCreatingChapter = true;

    try {
      final controller = TextEditingController();
      final l10n = context.l10n;

      bool isSubmitting = false;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> submit() async {
              final text = controller.text.trim();
              if (text.isEmpty || isSubmitting) return;

              setDialogState(() => isSubmitting = true);

              final created = await context.read<ContentCubit>().createChapter(
                groupId: _selectedGroupId!,
                title: text,
              );
              final success = created != null;

              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop(success);
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.create_new_folder_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.s8),
                  Text(l10n.newChapterDialogTitle),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.chapterTitleLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      hintText: l10n.chapterTitleHint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      if (!isSubmitting) unawaited(submit());
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogCtx).pop(false),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () => unawaited(submit()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.save),
                ),
              ],
            );
          },
        ),
      );

      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chapterCreatedSuccess),
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
      final controller = TextEditingController(text: chapter.title);
      final l10n = context.l10n;
      String? errorMessage;

      bool isSubmitting = false;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            Future<void> submit() async {
              final text = controller.text.trim();
              if (text.isEmpty || isSubmitting) return;

              if (text.toLowerCase() == chapter.title.trim().toLowerCase()) {
                Navigator.of(dialogCtx).pop(true);
                return;
              }

              final currentState = context.read<ContentCubit>().state;
              if (currentState is ContentLoaded) {
                final isDuplicate = currentState.chapters.any(
                  (c) =>
                      c.id != chapter.id &&
                      c.title.trim().toLowerCase() == text.toLowerCase(),
                );
                if (isDuplicate) {
                  setDialogState(() {
                    errorMessage = l10n.chapterNameAlreadyExists;
                  });
                  return;
                }
              }

              setDialogState(() {
                isSubmitting = true;
                errorMessage = null;
              });

              final success = await context.read<ContentCubit>().updateChapter(
                chapterId: chapter.id,
                title: text,
              );

              if (dialogCtx.mounted) {
                if (success) {
                  Navigator.of(dialogCtx).pop(true);
                } else {
                  setDialogState(() {
                    isSubmitting = false;
                    errorMessage = l10n.chapterUpdateFailed;
                  });
                }
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.s8),
                  Text(l10n.editChapterTitle),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.chapterTitleLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      labelText: l10n.chapterTitleLabel,
                      errorText: errorMessage,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setDialogState(() => errorMessage = null);
                      }
                    },
                    onSubmitted: (_) {
                      if (!isSubmitting) unawaited(submit());
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogCtx).pop(false),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : () => unawaited(submit()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.save),
                ),
              ],
            );
          },
        ),
      );

      if (confirmed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chapterUpdatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      _isEditingChapter = false;
    }
  }

  Future<void> _handleDeleteChapter(ChapterEntity chapter) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.s8),
            Text(l10n.deleteChapterTitle),
          ],
        ),
        content: Text(l10n.deleteChapterConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success =
          await context.read<ContentCubit>().deleteChapter(chapter.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chapterDeletedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _handleMoveLessonToChapter(
    ContentEntity lesson,
    List<ChapterEntity> chapters,
  ) async {
    if (_selectedGroupId == null) return;
    final l10n = context.l10n;

    final targetChapterId = await showDialog<String?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Row(
          children: [
            const Icon(Icons.drive_file_move_outlined, color: AppColors.primary),
            const SizedBox(width: AppSpacing.s8),
            Text(l10n.selectTargetChapter),
          ],
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('__NONE__'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.remove_circle_outline,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Text(
                    l10n.noChapterOption,
                    style: TextStyle(
                      fontWeight: lesson.chapterId == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: lesson.chapterId == null
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          for (int i = 0; i < chapters.length; i++) ...[
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(chapters[i].id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        chapters[i].title,
                        style: TextStyle(
                          fontWeight: lesson.chapterId == chapters[i].id
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: lesson.chapterId == chapters[i].id
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (lesson.chapterId == chapters[i].id)
                      const Icon(
                        Icons.check_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (targetChapterId != null && mounted) {
      final actualChapterId =
          targetChapterId == '__NONE__' ? null : targetChapterId;
      final success = await context.read<ContentCubit>().setLessonChapter(
        contentId: lesson.id,
        groupId: _selectedGroupId!,
        chapterId: actualChapterId,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.lectureMovedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _selectedGroupName != null
        ? context.l10n.groupContentPrefix(_selectedGroupName!)
        : context.l10n.courseBuilderTitle; // We will add this translation key

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
        maxWidth: ResponsiveBreakpoints.maxContentWidth,
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

                    Widget
                    bodyContent = BlocBuilder<ContentCubit, ContentState>(
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
                          final lessons = state.items
                              .where((i) => i.type == ContentType.video)
                              .toList();
                          final isDesktop =
                              MediaQuery.of(context).size.width >= 960;

                          final chapters = state.chapters;
                          final generalLessons = lessons
                              .where((l) =>
                                  l.chapterId == null ||
                                  !chapters.any((c) => c.id == l.chapterId))
                              .toList();
                          final isCourseEmpty =
                              chapters.isEmpty && generalLessons.isEmpty;

                          final Widget masterList = RefreshIndicator(
                            onRefresh: () => _loadContent(forceRefresh: true),
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                if (isCourseEmpty)
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 48,
                                      ),
                                      child: Center(
                                        child: AppEmptyView(
                                          message: context
                                              .l10n
                                              .courseBuilderEmptyTitle,
                                          subtitle: context
                                              .l10n
                                              .courseBuilderEmptySubtitle,
                                          icon: Icons.view_timeline_outlined,
                                          actionText:
                                              context.l10n.addLessonButton,
                                          onAction: _handleAddLesson,
                                        ),
                                      ),
                                    ),
                                  )
                                else ...[
                                  SliverPadding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.s8,
                                      bottom: 96,
                                    ),
                                    sliver: SliverList(
                                      delegate: SliverChildListDelegate([
                                        // 1. Chapters in sequence
                                        for (int chIdx = 0;
                                            chIdx < chapters.length;
                                            chIdx++) ...[
                                          () {
                                            final ch = chapters[chIdx];
                                            final chLessons = lessons
                                                .where((l) =>
                                                    l.chapterId == ch.id)
                                                .toList();
                                            return _buildChapterContainer(
                                              context: context,
                                              chapter: ch,
                                              chapterNumber: chIdx + 1,
                                              chapterLessons: chLessons,
                                              allChapters: chapters,
                                            );
                                          }(),
                                        ],

                                        // 2. Unassigned General Lessons
                                        if (generalLessons.isNotEmpty)
                                          _buildGeneralLessonsContainer(
                                            context: context,
                                            generalLessons: generalLessons,
                                            allChapters: chapters,
                                          ),
                                      ]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );

                          final publishedCount = lessons
                              .where((l) => l.isPublished)
                              .length;
                          final draftCount = lessons
                              .where((l) => l.isDraft)
                              .length;

                          final bulkVisibilityMenu = PopupMenuButton<String>(
                            tooltip: context.l10n.lessonStatusLabel,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'publish_all',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.visibility_rounded,
                                      color: AppColors.success,
                                      size: 18,
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    Text(ctx.l10n.publishAllLessonsAction),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'hide_all',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.visibility_off_rounded,
                                      color: AppColors.warning,
                                      size: 18,
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    Text(ctx.l10n.hideAllLessonsAction),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (val) {
                              if (val == 'publish_all') {
                                _handleBulkVisibility(true);
                              } else if (val == 'hide_all') {
                                _handleBulkVisibility(false);
                              }
                            },
                          );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Course Overview Banner Card
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s12,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s16,
                                    vertical: AppSpacing.s12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMedium,
                                    ),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: isDesktop
                                      ? Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(
                                                AppSpacing.s8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.menu_book_rounded,
                                                color: AppColors.primary,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.s12,
                                            ),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    _selectedGroupName ??
                                                        context
                                                            .l10n
                                                            .courseBuilderTitle,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: AppSpacing.s12,
                                                    runSpacing: AppSpacing.s4,
                                                    children: [
                                                      _buildBannerStat(
                                                        icon: Icons
                                                            .video_collection_rounded,
                                                        label: context.l10n
                                                            .nLessonsCount(
                                                              lessons.length,
                                                            ),
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                      _buildBannerStat(
                                                        icon: Icons
                                                            .check_circle_outline_rounded,
                                                        label: context.l10n
                                                            .publishedCountBadge(
                                                              publishedCount,
                                                            ),
                                                        color:
                                                            AppColors.success,
                                                      ),
                                                      if (draftCount > 0)
                                                        _buildBannerStat(
                                                          icon: Icons
                                                              .visibility_off_outlined,
                                                          label: context.l10n
                                                              .draftCountBadge(
                                                                draftCount,
                                                              ),
                                                          color:
                                                              AppColors.warning,
                                                        ),
                                                      _buildBannerStat(
                                                        icon: Icons
                                                            .picture_as_pdf_rounded,
                                                        label:
                                                            '${lessons.where((l) => l.file != null).length} ${context.l10n.hasStudyMaterial}',
                                                        color: const Color(
                                                          0xFFEA580C,
                                                        ),
                                                      ),
                                                      _buildBannerStat(
                                                        icon:
                                                            Icons.quiz_rounded,
                                                        label:
                                                            '${lessons.where((l) => l.associatedExamTitle != null).length} ${context.l10n.hasLessonQuiz}',
                                                        color:
                                                            AppColors.success,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.s8,
                                            ),
                                            IconButton(
                                              tooltip: _collapsedChapterIds.length >= chapters.length
                                                  ? context.l10n.expandAllChapters
                                                  : context.l10n.collapseAllChapters,
                                              icon: Icon(
                                                _collapsedChapterIds.length >= chapters.length
                                                    ? Icons.unfold_more_rounded
                                                    : Icons.unfold_less_rounded,
                                                size: 20,
                                                color: AppColors.textPrimary,
                                              ),
                                              onPressed: () =>
                                                  _toggleAllChaptersCollapse(chapters),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.s4,
                                            ),
                                            bulkVisibilityMenu,
                                            const SizedBox(
                                              width: AppSpacing.s8,
                                            ),
                                            AppButton(
                                              text: context.l10n.groupAnalytics,
                                              icon: Icons.insights_rounded,
                                              variant: AppButtonVariant.outlined,
                                              onPressed: () =>
                                                  _openGroupAnalytics(chapters, lessons),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.s8,
                                            ),
                                            AppButton(
                                              text:
                                                  context.l10n.addNewChapter,
                                              icon: Icons
                                                  .create_new_folder_rounded,
                                              variant:
                                                  AppButtonVariant.outlined,
                                              onPressed: _handleCreateChapter,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.s8,
                                            ),
                                            AppButton(
                                              text:
                                                  context.l10n.addLessonButton,
                                              icon: Icons.add_rounded,
                                              onPressed: _handleAddLesson,
                                            ),
                                          ],
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    AppSpacing.s6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.menu_book_rounded,
                                                    color: AppColors.primary,
                                                    size: 18,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.s8,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    _selectedGroupName ??
                                                        context
                                                            .l10n
                                                            .courseBuilderTitle,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppColors
                                                              .textPrimary,
                                                        ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: _collapsedChapterIds.length >= chapters.length
                                                      ? context.l10n.expandAllChapters
                                                      : context.l10n.collapseAllChapters,
                                                  icon: Icon(
                                                    _collapsedChapterIds.length >= chapters.length
                                                        ? Icons.unfold_more_rounded
                                                        : Icons.unfold_less_rounded,
                                                    size: 20,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  onPressed: () =>
                                                      _toggleAllChaptersCollapse(chapters),
                                                ),
                                                const SizedBox(width: 4),
                                                bulkVisibilityMenu,
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                IconButton(
                                                  onPressed: () =>
                                                      _openGroupAnalytics(chapters, lessons),
                                                  tooltip: context.l10n.groupAnalytics,
                                                  icon: const Icon(
                                                    Icons.insights_rounded,
                                                    color: AppColors.primary,
                                                    size: 20,
                                                  ),
                                                  style: IconButton.styleFrom(
                                                    backgroundColor: AppColors.primary
                                                        .withValues(alpha: 0.08),
                                                    padding: const EdgeInsets.all(8),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.s6,
                                                ),
                                                Expanded(
                                                  child: AppButton(
                                                    text: context
                                                        .l10n
                                                        .addNewChapter,
                                                    icon: Icons
                                                        .create_new_folder_rounded,
                                                    variant:
                                                        AppButtonVariant
                                                            .outlined,
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 8,
                                                        ),
                                                    onPressed:
                                                        _handleCreateChapter,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.s6,
                                                ),
                                                Expanded(
                                                  child: AppButton(
                                                    text: context
                                                        .l10n
                                                        .addLessonButton,
                                                    icon: Icons.add_rounded,
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                          horizontal: 8,
                                                        ),
                                                    onPressed:
                                                        _handleAddLesson,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: AppSpacing.s10,
                                              runSpacing: AppSpacing.s4,
                                              children: [
                                                _buildBannerStat(
                                                  icon: Icons
                                                      .video_collection_rounded,
                                                  label: context.l10n
                                                      .nLessonsCount(
                                                        lessons.length,
                                                      ),
                                                  color: AppColors.primary,
                                                ),
                                                _buildBannerStat(
                                                  icon: Icons
                                                      .check_circle_outline_rounded,
                                                  label: context.l10n
                                                      .publishedCountBadge(
                                                        publishedCount,
                                                      ),
                                                  color: AppColors.success,
                                                ),
                                                if (draftCount > 0)
                                                  _buildBannerStat(
                                                    icon: Icons
                                                        .visibility_off_outlined,
                                                    label: context.l10n
                                                        .draftCountBadge(
                                                          draftCount,
                                                        ),
                                                    color: AppColors.warning,
                                                  ),
                                                _buildBannerStat(
                                                  icon: Icons
                                                      .picture_as_pdf_rounded,
                                                  label:
                                                      '${lessons.where((l) => l.file != null).length} ${context.l10n.hasStudyMaterial}',
                                                  color: const Color(
                                                    0xFFEA580C,
                                                  ),
                                                ),
                                                _buildBannerStat(
                                                  icon: Icons.quiz_rounded,
                                                  label:
                                                      '${lessons.where((l) => l.associatedExamTitle != null).length} ${context.l10n.hasLessonQuiz}',
                                                  color: AppColors.success,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              // Content Area: Clean, full-width course syllabus
                              Expanded(child: masterList),
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

  Widget _buildBannerStat({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterContainer({
    required BuildContext context,
    required ChapterEntity chapter,
    required int chapterNumber,
    required List<ContentEntity> chapterLessons,
    required List<ChapterEntity> allChapters,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isCollapsed = _collapsedChapterIds.contains(chapter.id);
    final chIdx = chapterNumber - 1;
    final canMoveUp = chIdx > 0;
    final canMoveDown = chIdx < allChapters.length - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Chapter Header Bar (Clickable for quick expand/collapse)
          InkWell(
            onTap: () => _toggleChapterCollapse(chapter.id),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.6),
                border: Border(
                  bottom: isCollapsed
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  // Chapter Number Badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        chapterNumber.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),

                  // Chapter Title & Counter
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chapter.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 15.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.chapterLessonsCount(chapterLessons.length),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: (chapter.isPublished
                                        ? AppColors.success
                                        : AppColors.warning)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (chapter.isPublished
                                          ? AppColors.success
                                          : AppColors.warning)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    chapter.isPublished
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    size: 11,
                                    color: chapter.isPublished
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    chapter.isPublished
                                        ? l10n.chapterVisibilityPublished
                                        : l10n.chapterVisibilityDraft,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: chapter.isPublished
                                          ? AppColors.success
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),

                  // Actions: Move Chapter Up / Down
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    tooltip: l10n.moveChapterUp,
                    visualDensity: VisualDensity.compact,
                    onPressed: canMoveUp
                        ? () => _moveChapter(allChapters, chIdx, -1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                    tooltip: l10n.moveChapterDown,
                    visualDensity: VisualDensity.compact,
                    onPressed: canMoveDown
                        ? () => _moveChapter(allChapters, chIdx, 1)
                        : null,
                  ),
                  const SizedBox(width: 2),

                  // Actions: Chapter Analytics
                  IconButton(
                    icon: const Icon(
                      Icons.analytics_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    tooltip: l10n.chapterAnalytics,
                    visualDensity: VisualDensity.compact,
                    onPressed: () =>
                        _openChapterAnalytics(chapter, chapterLessons),
                  ),
                  const SizedBox(width: 2),

                  // Actions: Add lecture to chapter
                  if (MediaQuery.of(context).size.width < 500)
                    IconButton(
                      onPressed: () => _handleAddLesson(chapterId: chapter.id),
                      tooltip: l10n.addLectureToChapter,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.08),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _handleAddLesson(chapterId: chapter.id),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(
                        l10n.addLectureToChapter,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.s4),

                  // Chapter Options Menu
                  PopupMenuButton<String>(
                    tooltip: l10n.more,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'toggle_visibility',
                        child: Row(
                          children: [
                            Icon(
                              chapter.isPublished
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: chapter.isPublished
                                  ? AppColors.warning
                                  : AppColors.success,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              chapter.isPublished
                                  ? l10n.hideChapterAction
                                  : l10n.publishChapterAction,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_note_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(l10n.editChapterTitle),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              l10n.deleteChapterTitle,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (val) {
                      if (val == 'toggle_visibility') {
                        final messenger = ScaffoldMessenger.of(context);
                        unawaited(() async {
                          final success = await context
                              .read<ContentCubit>()
                              .toggleChapterVisibility(
                                chapterId: chapter.id,
                                isPublished: !chapter.isPublished,
                              );
                          if (success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  !chapter.isPublished
                                      ? l10n.chapterPublishedToast
                                      : l10n.chapterHiddenToast,
                                ),
                                backgroundColor: !chapter.isPublished
                                    ? AppColors.success
                                    : AppColors.warning,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }());
                      } else if (val == 'edit') {
                        _handleEditChapter(chapter);
                      } else if (val == 'delete') {
                        _handleDeleteChapter(chapter);
                      }
                    },
                  ),

                  // Expand/Collapse Chevron Indicator
                  IconButton(
                    icon: Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    tooltip: isCollapsed
                        ? l10n.expandAllChapters
                        : l10n.collapseAllChapters,
                    onPressed: () => _toggleChapterCollapse(chapter.id),
                  ),
                ],
              ),
            ),
          ),

          // Chapter Body with Animated CrossFade Accordion
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: chapterLessons.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_open_rounded,
                            size: 36,
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            l10n.emptyChapterPlaceholder,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          TextButton.icon(
                            onPressed: () =>
                                _handleAddLesson(chapterId: chapter.id),
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text(l10n.emptyChapterTeacherAction),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s8,
                      horizontal: AppSpacing.s8,
                    ),
                    itemCount: chapterLessons.length,
                    itemBuilder: (context, idx) {
                      final lesson = chapterLessons[idx];
                      return CourseLessonTile(
                        key: ValueKey('chap_lesson_${lesson.id}'),
                        content: lesson,
                        index: idx,
                        isSelected: false,
                        onTap: () => _openEditLessonPage(lesson),
                        lessonTitle: lesson.title,
                        hasPdf: lesson.file != null,
                        quizTitle: lesson.associatedExamTitle,
                        canMoveUp: idx > 0,
                        canMoveDown: idx < chapterLessons.length - 1,
                        onMoveUp: () => _handleReorderLessonsInChapter(
                          chapterLessons,
                          idx,
                          idx - 1,
                        ),
                        onMoveDown: () => _handleReorderLessonsInChapter(
                          chapterLessons,
                          idx,
                          idx + 2,
                        ),
                        onMoveToChapter: () =>
                            _handleMoveLessonToChapter(lesson, allChapters),
                        onViewAnalytics: () => _openLessonAnalytics(lesson),
                        onEdit: () => _openEditLessonPage(lesson),
                        onDelete: () => _confirmDelete(lesson),
                        onToggleVisibility: () =>
                            _handleToggleVisibility(lesson),
                      );
                    },
                  ),
            crossFadeState: isCollapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralLessonsContainer({
    required BuildContext context,
    required List<ContentEntity> generalLessons,
    required List<ChapterEntity> allChapters,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: AppColors.border,
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              border: const Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.view_agenda_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.unassignedLecturesSection,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.unassignedLecturesDesc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    l10n.chapterLessonsCount(generalLessons.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.s8,
              horizontal: AppSpacing.s8,
            ),
            itemCount: generalLessons.length,
            itemBuilder: (context, idx) {
              final lesson = generalLessons[idx];
              return CourseLessonTile(
                key: ValueKey('gen_lesson_${lesson.id}'),
                content: lesson,
                index: idx,
                isSelected: false,
                onTap: () => _openEditLessonPage(lesson),
                lessonTitle: lesson.title,
                hasPdf: lesson.file != null,
                quizTitle: lesson.associatedExamTitle,
                canMoveUp: idx > 0,
                canMoveDown: idx < generalLessons.length - 1,
                onMoveUp: () => _handleReorderLessonsInChapter(
                  generalLessons,
                  idx,
                  idx - 1,
                ),
                onMoveDown: () => _handleReorderLessonsInChapter(
                  generalLessons,
                  idx,
                  idx + 2,
                ),
                onMoveToChapter: () =>
                    _handleMoveLessonToChapter(lesson, allChapters),
                onViewAnalytics: () => _openLessonAnalytics(lesson),
                onEdit: () => _openEditLessonPage(lesson),
                onDelete: () => _confirmDelete(lesson),
                onToggleVisibility: () => _handleToggleVisibility(lesson),
              );
            },
          ),
        ],
      ),
    );
  }
}
