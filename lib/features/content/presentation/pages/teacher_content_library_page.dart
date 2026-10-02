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
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';

import '../widgets/course_lesson_tile.dart';
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

  Future<void> _handleAddLesson() async {
    if (_selectedGroupId == null) return;
    await context.push(
      '/teacher/groups/$_selectedGroupId/lessons/new?name=${Uri.encodeComponent(_selectedGroupName ?? "")}',
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
      body: Center(
        child: ResponsiveContainer(
          maxWidth: ResponsiveBreakpoints.maxContentWidth,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
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

                          final Widget masterList = RefreshIndicator(
                            onRefresh: () => _loadContent(forceRefresh: true),
                            child: CustomScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                if (lessons.isEmpty)
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
                                else
                                  SliverPadding(
                                    padding: const EdgeInsets.only(bottom: 96),
                                    sliver: SliverReorderableList(
                                      itemCount: lessons.length,
                                      onReorder: (oldIdx, newIdx) {
                                        context
                                            .read<ContentCubit>()
                                            .reorderItems(oldIdx, newIdx);
                                      },
                                      proxyDecorator:
                                          (child, index, animation) {
                                            return AnimatedBuilder(
                                              animation: animation,
                                              builder: (context, child) {
                                                return Material(
                                                  elevation: 8,
                                                  color: Colors.transparent,
                                                  shadowColor: Colors.black
                                                      .withValues(alpha: 0.3),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppSpacing.radiusMedium,
                                                      ),
                                                  child: child,
                                                );
                                              },
                                              child: child,
                                            );
                                          },
                                      itemBuilder: (context, index) {
                                        final lesson = lessons[index];
                                        return CourseLessonTile(
                                          key: ValueKey(lesson.id),
                                          content: lesson,
                                          index: index,
                                          isSelected: false,
                                          onTap: () =>
                                              _openEditLessonPage(lesson),
                                          lessonTitle: lesson.title,
                                          hasPdf: lesson.file != null,
                                          quizTitle: lesson.associatedExamTitle,
                                          canMoveUp: index > 0,
                                          canMoveDown:
                                              index < lessons.length - 1,
                                          onMoveUp: () => context
                                              .read<ContentCubit>()
                                              .reorderItems(index, index - 1),
                                          onMoveDown: () => context
                                              .read<ContentCubit>()
                                              .reorderItems(index, index + 2),
                                          onEdit: () =>
                                              _openEditLessonPage(lesson),
                                          onDelete: () =>
                                              _confirmDelete(lesson),
                                          onToggleVisibility: () =>
                                              _handleToggleVisibility(lesson),
                                        );
                                      },
                                    ),
                                  ),
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
                                              width: AppSpacing.s12,
                                            ),
                                            bulkVisibilityMenu,
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
                                                bulkVisibilityMenu,
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
      ),
    );
  }

  Widget _buildBannerStat({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
