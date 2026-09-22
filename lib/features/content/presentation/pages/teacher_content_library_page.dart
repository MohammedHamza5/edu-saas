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

import '../widgets/lesson_editor_pane.dart';

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
  String? _selectedLessonId;
  ContentEntity? _selectedLesson;
  bool _isAddingLesson = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedVideo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_selectedGroupId != null) {
          _openEditLessonDialog(widget.preselectedVideo);
        }
      });
    }
    final initialId = widget.groupId ?? TeacherGroupFilterBar.lastSelectedGroupId;
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
      unawaited(context.read<ContentCubit>().loadGroupContent(_selectedGroupId!));
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
      _selectedLesson = null;
      _selectedLessonId = null;
      _isAddingLesson = false;
    });
    _loadContent();
  }

  Future<void> _loadContent({bool forceRefresh = false}) async {
    if (_selectedGroupId != null) {
      unawaited(context.read<ContentCubit>().loadGroupContent(
            _selectedGroupId!,
            forceRefresh: forceRefresh,
          ));
    }
  }

  void _handleAddLesson() {
    if (_selectedGroupId == null) return;
    final isDesktop = MediaQuery.of(context).size.width >= 960;
    if (isDesktop) {
      setState(() {
        _selectedLesson = null;
        _selectedLessonId = null;
        _isAddingLesson = true;
      });
    } else {
      _showLessonEditorSheet(null);
    }
  }

  void _openEditLessonDialog(ContentEntity? content) {
    if (_selectedGroupId == null) return;
    final isDesktop = MediaQuery.of(context).size.width >= 960;
    if (isDesktop) {
      setState(() {
        _selectedLesson = content;
        _selectedLessonId = content?.id;
        _isAddingLesson = (content == null);
      });
    } else {
      _showLessonEditorSheet(content);
    }
  }

  void _showLessonEditorSheet(ContentEntity? lesson) {
    if (_selectedGroupId == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.9,
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: BlocProvider.value(
                  value: context.read<ContentCubit>(),
                  child: LessonEditorPane(
                    editingLesson: lesson,
                    groupId: _selectedGroupId!,
                    groupName: _selectedGroupName ?? '',
                    defaultPassingScore: 70,
                    onOpenFullPage: lesson != null
                        ? () {
                            Navigator.of(ctx).pop();
                            context.push(
                              '/teacher/groups/$_selectedGroupId/lessons/${lesson.id}?name=${Uri.encodeComponent(_selectedGroupName ?? "")}',
                            );
                          }
                        : null,
                    onSaved: () {
                      Navigator.of(ctx).pop();
                      _onLessonSaved();
                    },
                    onCancel: () {
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onLessonSaved() async {
    await _loadContent(forceRefresh: true);
    if (mounted) {
      setState(() {
        _selectedLesson = null;
        _selectedLessonId = null;
        _isAddingLesson = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.contentUpdatedToast)),
      );
    }
  }

  Future<void> _confirmDelete(ContentEntity item) async {
    final cubit = context.read<ContentCubit>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteConfirmTitle),
        content: Text(ctx.l10n.deleteItemConfirmMessage(item.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: Text(ctx.l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirm == true) {
      unawaited(cubit.deleteContent(item.id));
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
          }
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
      floatingActionButton: (_selectedGroupId == null || MediaQuery.of(context).size.width >= 960)
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
                    return RefreshIndicator(
                      onRefresh: () => _loadContent(forceRefresh: true),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.s12),
                              child: TeacherGroupFilterBar(
                                selectedGroupId: _selectedGroupId,
                                onGroupChanged: _onGroupChanged,
                                onRefresh: () => _loadContent(forceRefresh: true),
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: AppSpacing.s16),
                              child: AppLoadingView.cardsGrid(count: 4, columns: 1),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is ContentError) {
                    return RefreshIndicator(
                      onRefresh: () => _loadContent(forceRefresh: true),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.s12),
                              child: TeacherGroupFilterBar(
                                selectedGroupId: _selectedGroupId,
                                onGroupChanged: _onGroupChanged,
                                onRefresh: () => _loadContent(forceRefresh: true),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Center(
                                child: AppErrorView(
                                  message: state.message,
                                  onRetry: () => _loadContent(forceRefresh: true),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is ContentLoaded) {
                    // Only show Videos as Lessons in Course Builder
                    final lessons = state.items.where((i) => i.type == ContentType.video).toList();
                    final isDesktop = MediaQuery.of(context).size.width >= 960;

                    final Widget masterList = RefreshIndicator(
                      onRefresh: () => _loadContent(forceRefresh: true),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // 1. Group Selector Bar
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.s12, bottom: AppSpacing.s16),
                              child: TeacherGroupFilterBar(
                                selectedGroupId: _selectedGroupId,
                                onGroupChanged: _onGroupChanged,
                                onRefresh: () => _loadContent(forceRefresh: true),
                              ),
                            ),
                          ),

                          // 2. Empty State
                          if (lessons.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 48),
                                child: Center(
                                  child: AppEmptyView(
                                    message: context.l10n.courseBuilderEmptyTitle,
                                    subtitle: context.l10n.courseBuilderEmptySubtitle,
                                    icon: Icons.view_timeline_outlined,
                                    actionText: context.l10n.addLessonButton,
                                    onAction: _handleAddLesson,
                                  ),
                                ),
                              ),
                            )
                          else
                            // 3. Reorderable Lesson List
                            SliverPadding(
                              padding: const EdgeInsets.only(bottom: 96),
                              sliver: SliverReorderableList(
                                itemCount: lessons.length,
                                onReorder: (oldIdx, newIdx) {
                                  context.read<ContentCubit>().reorderItems(
                                    oldIdx,
                                    newIdx,
                                  );
                                },
                                proxyDecorator: (child, index, animation) {
                                  return AnimatedBuilder(
                                    animation: animation,
                                    builder: (context, child) {
                                      return Material(
                                        elevation: 8,
                                        color: Colors.transparent,
                                        shadowColor: Colors.black.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                        child: child,
                                      );
                                    },
                                    child: child,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  final lesson = lessons[index];
                                  final isSelected = _selectedLessonId == lesson.id;
                                  return CourseLessonTile(
                                    key: ValueKey(lesson.id),
                                    content: lesson,
                                    index: index,
                                    isSelected: isSelected,
                                    onTap: () => _openEditLessonDialog(lesson),
                                    lessonTitle: lesson.title, // If group configs had overrides, we'd pass it here
                                    hasPdf: lesson.file != null,
                                    quizTitle: lesson.associatedExamTitle,
                                    canMoveUp: index > 0,
                                    canMoveDown: index < lessons.length - 1,
                                    onMoveUp: () => context.read<ContentCubit>().reorderItems(index, index - 1),
                                    onMoveDown: () => context.read<ContentCubit>().reorderItems(index, index + 2),
                                    onEdit: () => _openEditLessonDialog(lesson),
                                    onDelete: () => _confirmDelete(lesson),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    );

                    if (isDesktop && _selectedGroupId != null) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: masterList),
                          const SizedBox(width: AppSpacing.s16),
                          SizedBox(
                            width: 440,
                            child: Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.s12, bottom: AppSpacing.s24),
                              child: (_selectedLesson != null || _isAddingLesson)
                                  ? LessonEditorPane(
                                      key: ValueKey(_selectedLesson?.id ?? 'new_lesson'),
                                      editingLesson: _selectedLesson,
                                      groupId: _selectedGroupId!,
                                      groupName: _selectedGroupName ?? '',
                                      defaultPassingScore: 70,
                                      onOpenFullPage: _selectedLesson != null
                                          ? () {
                                              context.push(
                                                '/teacher/groups/$_selectedGroupId/lessons/${_selectedLesson!.id}?name=${Uri.encodeComponent(_selectedGroupName ?? "")}',
                                              );
                                            }
                                          : null,
                                      onSaved: () {
                                        _onLessonSaved();
                                      },
                                      onCancel: () {
                                        setState(() {
                                          _selectedLesson = null;
                                          _selectedLessonId = null;
                                          _isAddingLesson = false;
                                        });
                                      },
                                      onClose: () {
                                        setState(() {
                                          _selectedLesson = null;
                                          _selectedLessonId = null;
                                          _isAddingLesson = false;
                                        });
                                      },
                                    )
                                  : _buildInspectorPlaceholder(lessons),
                            ),
                          ),
                        ],
                      );
                    }

                    return masterList;
                  }

                  // Default state
                  return RefreshIndicator(
                    onRefresh: () async {
                      await context.read<GroupsCubit>().loadGroups(forceRefresh: true);
                      await _loadContent(forceRefresh: true);
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s12),
                            child: TeacherGroupFilterBar(
                              selectedGroupId: _selectedGroupId,
                              onGroupChanged: _onGroupChanged,
                              onRefresh: () => _loadContent(forceRefresh: true),
                            ),
                          ),
                        ),
                      ],
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
                        _selectedGroupName = groupsState.groups.first.name;
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
      ),
    );
  }

  Widget _buildInspectorPlaceholder(List<ContentEntity> lessons) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            l10n.courseSummary,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            l10n.selectLessonToEdit,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.s24),
          _buildSummaryStatRow(
            icon: Icons.video_collection_rounded,
            title: l10n.nLessonsCount(lessons.length),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.s12),
          _buildSummaryStatRow(
            icon: Icons.picture_as_pdf_rounded,
            title: '${lessons.where((l) => l.file != null).length} ${l10n.hasStudyMaterial}',
            color: const Color(0xFFEA580C),
          ),
          const SizedBox(height: AppSpacing.s12),
          _buildSummaryStatRow(
            icon: Icons.quiz_rounded,
            title: '${lessons.where((l) => l.associatedExamTitle != null).length} ${l10n.hasLessonQuiz}',
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.s32),
          AppButton(
            text: l10n.addLessonButton,
            icon: Icons.add_rounded,
            onPressed: _handleAddLesson,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatRow({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
