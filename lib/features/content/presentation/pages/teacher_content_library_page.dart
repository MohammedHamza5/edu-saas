import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/create_edit_content_dialog.dart';
import '../widgets/content_item_card.dart';
import '../widgets/material_viewer_sheet.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../../videos/presentation/widgets/video_upload_dialog.dart';

class TeacherContentLibraryPage extends StatefulWidget {
  final String? groupId;
  final String? groupName;

  const TeacherContentLibraryPage({super.key, this.groupId, this.groupName});

  @override
  State<TeacherContentLibraryPage> createState() =>
      _TeacherContentLibraryPageState();
}

class _TeacherContentLibraryPageState extends State<TeacherContentLibraryPage> {
  String? _selectedGroupId;
  String? _selectedGroupName;
  ContentStatus? _activeFilter;
  ContentType? _activeTypeFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final initialId = widget.groupId ?? TeacherGroupFilterBar.lastSelectedGroupId;
    GroupsState? groupsState;
    try {
      groupsState = context.read<GroupsCubit>().state;
    } catch (_) {}
    if (initialId != null) {
      _selectedGroupId = initialId;
      _selectedGroupName = widget.groupName;
      if (_selectedGroupName == null && groupsState is GroupsLoaded) {
        _selectedGroupName = groupsState.groups.where((g) => g.id == initialId).firstOrNull?.name;
      }
    } else if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
      _selectedGroupId = groupsState.groups.first.id;
      _selectedGroupName = groupsState.groups.first.name;
    }

    if (_selectedGroupId != null) {
      context.read<ContentCubit>().loadGroupContent(_selectedGroupId!);
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

  void _loadContent() {
    if (_selectedGroupId != null) {
      context.read<ContentCubit>().loadGroupContent(_selectedGroupId!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateDialog() {
    if (_selectedGroupId == null) return;
    showDialog<bool>(
      context: context,
      builder: (ctx) => CreateEditContentDialog(
        groupId: _selectedGroupId!,
        onSave:
            ({
              required title,
              description,
              required type,
              required status,
              fileName,
              storagePath,
              mimeType,
              fileSize,
              fileBytes,
            }) {
              return context.read<ContentCubit>().createContent(
                groupId: _selectedGroupId!,
                title: title,
                description: description,
                type: type,
                status: status,
                fileName: fileName,
                storagePath: storagePath,
                mimeType: mimeType,
                fileSize: fileSize,
                fileBytes: fileBytes,
              );
            },
      ),
    ).then((created) {
      if (created == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(context.l10n.contentCreatedToast),
          ),
        );
      }
    });
  }

  void _openEditDialog(ContentEntity content) {
    if (_selectedGroupId == null) return;
    showDialog<bool>(
      context: context,
      builder: (ctx) => CreateEditContentDialog(
        groupId: _selectedGroupId!,
        initialContent: content,
        onSave:
            ({
              required title,
              description,
              required type,
              required status,
              fileName,
              storagePath,
              mimeType,
              fileSize,
              fileBytes,
            }) {
              return context.read<ContentCubit>().updateContent(
                contentId: content.id,
                title: title,
                description: description,
                type: type,
                status: status,
              );
            },
      ),
    ).then((updated) {
      if (updated == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.contentUpdatedToast)),
        );
      }
    });
  }

  Future<void> _handleOpenFile(ContentEntity item) async {
    await MaterialViewerSheet.show(
      context,
      content: item,
      onGetSignedUrl: (storagePath) =>
          context.read<ContentCubit>().getSignedUrl(storagePath),
    );
  }

  Future<void> _handleUploadVideo(ContentEntity item) async {
    await VideoUploadDialog.show(
      context,
      contentId: item.id,
      onUploadSuccess: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(context.l10n.videoProcessingStartedToast),
            ),
          );
          _loadContent();
        }
      },
    );
  }

  Future<void> _handleItemTap(ContentEntity item) async {
    if (item.type == ContentType.video) {
      await context.push('${AppRouter.videoPlayer}?id=${item.id}');
    } else if (item.file != null) {
      await _handleOpenFile(item);
    } else {
      _openEditDialog(item);
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
        : context.l10n.teacherContentLibraryTitle;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.backTooltip,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRouter.teacherDashboard),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.folder_special_rounded,
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
            onPressed: _loadContent,
          ),
        ],
      ),
      floatingActionButton: _selectedGroupId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.l10n.addContentAction),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
      body: Center(
        child: ResponsiveContainer(
          maxWidth: ResponsiveBreakpoints.maxContentWidth,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
          ),
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
                  onRefresh: () async => _loadContent(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s12),
                          child: TeacherGroupFilterBar(
                            selectedGroupId: _selectedGroupId,
                            onGroupChanged: _onGroupChanged,
                            onRefresh: _loadContent,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: AppSpacing.s16),
                          child: AppLoadingView.cardsGrid(count: 4, columns: 2),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (state is ContentError) {
                return RefreshIndicator(
                  onRefresh: () async => _loadContent(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s12),
                          child: TeacherGroupFilterBar(
                            selectedGroupId: _selectedGroupId,
                            onGroupChanged: _onGroupChanged,
                            onRefresh: _loadContent,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: AppErrorView(
                              message: state.message,
                              onRetry: _loadContent,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (state is ContentLoaded) {
                var items = state.filteredItems;

                // Secondary filter by type
                if (_activeTypeFilter != null) {
                  items = items
                      .where((i) => i.type == _activeTypeFilter)
                      .toList();
                }

                // Filter by live search query
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
                            (i.file?.fileName.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ??
                                false),
                      )
                      .toList();
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadContent(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // 1. Group Selector Bar (Scrolls away with the page)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s12),
                          child: TeacherGroupFilterBar(
                            selectedGroupId: _selectedGroupId,
                            onGroupChanged: _onGroupChanged,
                            onRefresh: _loadContent,
                          ),
                        ),
                      ),

                      // 2. Summary Stat Cards Row
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s12),
                          child: Builder(
                            builder: (context) {
                              final isCompact = MediaQuery.sizeOf(context).width < 600;
                              if (isCompact) {
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 140,
                                        child: _buildStatMiniCard(
                                          label: context.l10n.totalMaterials,
                                          count: state.items.length,
                                          color: AppColors.primary,
                                          icon: Icons.layers_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.s8),
                                      SizedBox(
                                        width: 140,
                                        child: _buildStatMiniCard(
                                          label: context.l10n.publishedToStudents,
                                          count: state.publishedCount,
                                          color: AppColors.success,
                                          icon: Icons
                                              .check_circle_outline_rounded,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.s8),
                                      SizedBox(
                                        width: 150,
                                        child: _buildStatMiniCard(
                                          label: context.l10n.draftsInProgress,
                                          count: state.draftCount,
                                          color: AppColors.warning,
                                          icon: Icons.edit_note_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child: _buildStatMiniCard(
                                      label: context.l10n.totalMaterials,
                                      count: state.items.length,
                                      color: AppColors.primary,
                                      icon: Icons.layers_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s8),
                                  Expanded(
                                    child: _buildStatMiniCard(
                                      label: context.l10n.publishedToStudents,
                                      count: state.publishedCount,
                                      color: AppColors.success,
                                      icon: Icons.check_circle_outline_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s8),
                                  Expanded(
                                    child: _buildStatMiniCard(
                                      label: context.l10n.draftsInProgress,
                                      count: state.draftCount,
                                      color: AppColors.warning,
                                      icon: Icons.edit_note_rounded,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                      // 3. Search Field
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s12),
                          child: AppTextField(
                            controller: _searchController,
                            hintText: context.l10n.searchContentTeacherHint,
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            onChanged: (val) {
                              setState(() => _searchQuery = val.trim());
                            },
                          ),
                        ),
                      ),

                      // 4. Status Filter Chips
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  label: context.l10n.filterAllWithCount(state.items.length),
                                  isSelected: _activeFilter == null,
                                  onSelected: () {
                                    setState(() => _activeFilter = null);
                                    context.read<ContentCubit>().setFilter(
                                      null,
                                    );
                                  },
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterPublishedWithCount(state.publishedCount),
                                  isSelected:
                                      _activeFilter == ContentStatus.published,
                                  onSelected: () {
                                    setState(
                                      () => _activeFilter =
                                          ContentStatus.published,
                                    );
                                    context.read<ContentCubit>().setFilter(
                                      ContentStatus.published,
                                    );
                                  },
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterDraftsWithCount(state.draftCount),
                                  isSelected:
                                      _activeFilter == ContentStatus.draft,
                                  onSelected: () {
                                    setState(
                                      () => _activeFilter = ContentStatus.draft,
                                    );
                                    context.read<ContentCubit>().setFilter(
                                      ContentStatus.draft,
                                    );
                                  },
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterArchivedWithCount(state.archivedCount),
                                  isSelected:
                                      _activeFilter == ContentStatus.archived,
                                  onSelected: () {
                                    setState(
                                      () => _activeFilter =
                                          ContentStatus.archived,
                                    );
                                    context.read<ContentCubit>().setFilter(
                                      ContentStatus.archived,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 5. Content List / Empty States
                      if (state.items.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: AppEmptyView(
                                message: context.l10n.emptyContentCategory,
                                icon: Icons.folder_open_rounded,
                                actionText: context.l10n.addFirstContent,
                                onAction: _openCreateDialog,
                              ),
                            ),
                          ),
                        )
                      else if (items.isEmpty)
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
                                    context.l10n.noMaterialsMatchFilter,
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
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 96),
                          sliver: SliverReorderableList(
                            itemCount: items.length,
                            onReorder: (oldIdx, newIdx) {
                              context.read<ContentCubit>().reorderItems(
                                oldIdx,
                                newIdx,
                              );
                            },
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Padding(
                                key: ValueKey(item.id),
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s10,
                                ),
                                child: ContentItemCard(
                                  content: item,
                                  isTeacher: true,
                                  index: index,
                                  onEdit: () => _openEditDialog(item),
                                  onOpenFile: (_) => _handleOpenFile(item),
                                  onUploadVideo: () => _handleUploadVideo(item),
                                  onTap: () => _handleItemTap(item),
                                  onTogglePublish: () {
                                    final newStatus = item.isPublished
                                        ? ContentStatus.draft
                                        : ContentStatus.published;
                                    context
                                        .read<ContentCubit>()
                                        .updateContent(
                                          contentId: item.id,
                                          status: newStatus,
                                        );
                                  },
                                  onToggleArchive: () {
                                    final newStatus = item.isArchived
                                        ? ContentStatus.draft
                                        : ContentStatus.archived;
                                    context
                                        .read<ContentCubit>()
                                        .updateContent(
                                          contentId: item.id,
                                          status: newStatus,
                                        );
                                  },
                                  onDelete: () => _confirmDelete(item),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await context.read<GroupsCubit>().loadGroups();
                  _loadContent();
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
                          onRefresh: _loadContent,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: AppSpacing.s16),
                        child: AppLoadingView.cardsGrid(count: 4, columns: 2),
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
                  if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
                    if (_selectedGroupId == null ||
                        !groupsState.groups.any((g) => g.id == _selectedGroupId)) {
                      final targetGroup = (widget.groupId != null &&
                              groupsState.groups.any((g) => g.id == widget.groupId))
                          ? groupsState.groups.firstWhere((g) => g.id == widget.groupId)
                          : groupsState.groups.first;
                      TeacherGroupFilterBar.lastSelectedGroupId = targetGroup.id;
                      setState(() {
                        _selectedGroupId = targetGroup.id;
                        _selectedGroupName = targetGroup.name;
                      });
                      _loadContent();
                    }
                  }
                },
                child: bodyContent,
              );
            }

            return BlocListener<ContentCubit, ContentState>(
              listener: (context, state) {
                if (state is ContentError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: bodyContent,
            );
          },
        ),
      ),
    ),
  );
  }

  Widget _buildStatMiniCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s6),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
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

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withAlpha(35),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }
}
