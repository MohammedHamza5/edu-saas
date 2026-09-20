import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/all_in_one_lecture_dialog.dart';
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
  final ScrollController _scrollController = ScrollController();
  String? _selectedGroupId;
  String? _selectedGroupName;
  ContentStatus? _activeFilter;
  ContentType? _activeTypeFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<ContentCubit>().loadMoreContent();
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
      await context.read<ContentCubit>().loadGroupContent(
            _selectedGroupId!,
            forceRefresh: forceRefresh,
          );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateDialog({ContentType? preselectedType}) {
    if (_selectedGroupId == null) return;
    showDialog<bool>(
      context: context,
      builder: (ctx) => CreateEditContentDialog(
        groupId: _selectedGroupId!,
        initialType: preselectedType ?? _activeTypeFilter,
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
              associatedExamId,
              prerequisiteExamId,
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
                associatedExamId: associatedExamId,
                prerequisiteExamId: prerequisiteExamId,
              );
            },
      ),
    ).then((created) {
      if (created == true && mounted) {
        _loadContent(forceRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(context.l10n.contentCreatedToast),
          ),
        );
      }
    });
  }

  void _openAllInOneStudio() {
    if (_selectedGroupId == null) return;
    AllInOneLectureDialog.show(
      context,
      groupId: _selectedGroupId!,
      groupName: _selectedGroupName,
    ).then((created) {
      if (created == true && mounted) {
        _loadContent(forceRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(context.l10n.lectureCreatedSuccessToast),
          ),
        );
      }
    });
  }

  void _showAddMaterialSheet() {
    if (_selectedGroupId == null) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    context.l10n.addNewMaterialTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  // Prominent All-in-One Lecture Creator Option
                  _buildAddOptionTile(
                    icon: Icons.auto_stories_rounded,
                    color: AppColors.primaryLight,
                    title: context.l10n.addNewLectureHero,
                    subtitle: context.l10n.curriculumRoadmapSubtitle,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openAllInOneStudio();
                    },
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  _buildAddOptionTile(
                    icon: Icons.play_circle_fill_rounded,
                    color: AppColors.primary,
                    title: context.l10n.uploadBunnyVideoTitle,
                    subtitle: context.l10n.uploadBunnyVideoSubtitle,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _openCreateDialog(preselectedType: ContentType.video);
                    },
                  ),
                const SizedBox(height: AppSpacing.s8),
                _buildAddOptionTile(
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFEA580C),
                  title: context.l10n.uploadPdfFileTitle,
                  subtitle: context.l10n.uploadPdfFileSubtitle,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openCreateDialog(preselectedType: ContentType.pdf);
                  },
                ),
                const SizedBox(height: AppSpacing.s8),
                _buildAddOptionTile(
                  icon: Icons.image_rounded,
                  color: Colors.purple,
                  title: context.l10n.imagesCategory,
                  subtitle: context.l10n.uploadPdfFileSubtitle,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _openCreateDialog(preselectedType: ContentType.image);
                  },
                ),
                const SizedBox(height: AppSpacing.s8),
                _buildAddOptionTile(
                  icon: Icons.assignment_rounded,
                  color: AppColors.warning,
                  title: context.l10n.createAssignmentShortcut,
                  subtitle: context.l10n.createAssignmentShortcutSubtitle,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.go(
                      '${AppRoutes.teacherGroupAssignments.replaceAll(':groupId', _selectedGroupId!)}?name=${Uri.encodeComponent(_selectedGroupName ?? '')}',
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s8),
                _buildAddOptionTile(
                  icon: Icons.quiz_rounded,
                  color: const Color(0xFF6366F1),
                  title: context.l10n.createExamShortcut,
                  subtitle: context.l10n.createExamShortcutSubtitle,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.go(
                      '${AppRoutes.teacherGroupExams.replaceAll(':groupId', _selectedGroupId!)}?name=${Uri.encodeComponent(_selectedGroupName ?? '')}',
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  }

  Widget _buildAddOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
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
              associatedExamId,
              prerequisiteExamId,
            }) {
              return context.read<ContentCubit>().updateContent(
                contentId: content.id,
                title: title,
                description: description,
                type: type,
                status: status,
                fileName: fileName,
                storagePath: storagePath,
                mimeType: mimeType,
                fileSize: fileSize,
                fileBytes: fileBytes,
                associatedExamId: associatedExamId,
                prerequisiteExamId: prerequisiteExamId,
              );
            },
      ),
    ).then((updated) {
      if (updated == true && mounted) {
        _loadContent(forceRefresh: true);
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
          _loadContent(forceRefresh: true);
        }
      },
    );
  }

  Future<void> _handleItemTap(ContentEntity item) async {
    if (item.type == ContentType.video) {
      await context.push('${AppRoutes.videoPlayer}?id=${item.id}');
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
              : context.go(AppRoutes.teacherDashboard),
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
            onPressed: () => _loadContent(forceRefresh: true),
          ),
        ],
      ),
      floatingActionButton: _selectedGroupId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddMaterialSheet,
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
                          child: AppLoadingView.cardsGrid(count: 4, columns: 2),
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
                var items = state.filteredItems;

                // Secondary filter by type
                if (_activeTypeFilter != null) {
                  items = items
                      .where((i) => i.type == _activeTypeFilter)
                      .toList();
                }

                // Filter by live search query
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  items = items
                      .where(
                        (i) =>
                            i.title.toLowerCase().contains(q) ||
                            (i.description?.toLowerCase().contains(q) ?? false) ||
                            (i.file?.fileName.toLowerCase().contains(q) ?? false),
                      )
                      .toList();
                }

                final totalCount = state.items.length;
                final videosCount = state.items.where((i) => i.type == ContentType.video).length;
                final pdfsCount = state.items.where((i) => i.type == ContentType.pdf).length;
                final imagesCount = state.items.where((i) => i.type == ContentType.image).length;
                final assignmentsCount = state.items.where((i) => i.type == ContentType.assignment).length;
                final examsCount = state.items.where((i) => i.type == ContentType.exam).length;

                final hasActiveFilters = _activeTypeFilter != null ||
                    _activeFilter != null ||
                    _searchQuery.isNotEmpty;

                return RefreshIndicator(
                  onRefresh: () => _loadContent(forceRefresh: true),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // 1. Group Selector Bar (Scrolls away with the page)
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

                      // 1.1 Hero All-in-One Lecture Creator Card (Prominent action banner)
                      if (_selectedGroupId != null)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s12),
                            child: InkWell(
                              onTap: _openAllInOneStudio,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.gradientStart, AppColors.gradientMid],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primaryLight.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.auto_stories_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            context.l10n.addNewLectureHero,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            context.l10n.curriculumRoadmapSubtitle,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 2. Summary Stat Cards Row (Interactive filtering)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 140,
                                  child: _buildStatMiniCard(
                                    label: context.l10n.totalMaterials,
                                    count: totalCount,
                                    color: AppColors.primary,
                                    icon: Icons.layers_rounded,
                                    isSelected: _activeTypeFilter == null && _activeFilter == null,
                                    onTap: () {
                                      setState(() {
                                        _activeTypeFilter = null;
                                        _activeFilter = null;
                                      });
                                      context.read<ContentCubit>().setFilter(null);
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                SizedBox(
                                  width: 140,
                                  child: _buildStatMiniCard(
                                    label: context.l10n.videosCategory,
                                    count: videosCount,
                                    color: AppColors.primary,
                                    icon: Icons.play_circle_fill_rounded,
                                    isSelected: _activeTypeFilter == ContentType.video,
                                    onTap: () {
                                      setState(() {
                                        _activeTypeFilter = _activeTypeFilter == ContentType.video
                                            ? null
                                            : ContentType.video;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                SizedBox(
                                  width: 140,
                                  child: _buildStatMiniCard(
                                    label: context.l10n.pdfDocumentsCategory,
                                    count: pdfsCount,
                                    color: const Color(0xFFEA580C),
                                    icon: Icons.picture_as_pdf_rounded,
                                    isSelected: _activeTypeFilter == ContentType.pdf,
                                    onTap: () {
                                      setState(() {
                                        _activeTypeFilter = _activeTypeFilter == ContentType.pdf
                                            ? null
                                            : ContentType.pdf;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                SizedBox(
                                  width: 140,
                                  child: _buildStatMiniCard(
                                    label: context.l10n.publishedToStudents,
                                    count: state.publishedCount,
                                    color: AppColors.success,
                                    icon: Icons.check_circle_outline_rounded,
                                    isSelected: _activeFilter == ContentStatus.published,
                                    onTap: () {
                                      final newStatus = _activeFilter == ContentStatus.published
                                          ? null
                                          : ContentStatus.published;
                                      setState(() => _activeFilter = newStatus);
                                      context.read<ContentCubit>().setFilter(newStatus);
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                SizedBox(
                                  width: 140,
                                  child: _buildStatMiniCard(
                                    label: context.l10n.draftsInProgress,
                                    count: state.draftCount,
                                    color: AppColors.warning,
                                    icon: Icons.edit_note_rounded,
                                    isSelected: _activeFilter == ContentStatus.draft,
                                    onTap: () {
                                      final newStatus = _activeFilter == ContentStatus.draft
                                          ? null
                                          : ContentStatus.draft;
                                      setState(() => _activeFilter = newStatus);
                                      context.read<ContentCubit>().setFilter(newStatus);
                                    },
                                  ),
                                ),
                              ],
                            ),
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
                                    tooltip: context.l10n.clearSearchAction,
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

                      // 4. Primary Content Type Filter Chips Bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  label: '${context.l10n.allCategories} ($totalCount)',
                                  icon: Icons.grid_view_rounded,
                                  isSelected: _activeTypeFilter == null,
                                  onSelected: () => setState(() => _activeTypeFilter = null),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterVideosWithCount(videosCount),
                                  icon: Icons.play_circle_fill_rounded,
                                  accentColor: AppColors.primary,
                                  isSelected: _activeTypeFilter == ContentType.video,
                                  onSelected: () => setState(
                                    () => _activeTypeFilter = _activeTypeFilter == ContentType.video
                                        ? null
                                        : ContentType.video,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterPdfsWithCount(pdfsCount),
                                  icon: Icons.picture_as_pdf_rounded,
                                  accentColor: const Color(0xFFEA580C),
                                  isSelected: _activeTypeFilter == ContentType.pdf,
                                  onSelected: () => setState(
                                    () => _activeTypeFilter = _activeTypeFilter == ContentType.pdf
                                        ? null
                                        : ContentType.pdf,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterImagesWithCount(imagesCount),
                                  icon: Icons.image_rounded,
                                  accentColor: Colors.purple,
                                  isSelected: _activeTypeFilter == ContentType.image,
                                  onSelected: () => setState(
                                    () => _activeTypeFilter = _activeTypeFilter == ContentType.image
                                        ? null
                                        : ContentType.image,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterAssignmentsWithCount(assignmentsCount),
                                  icon: Icons.assignment_rounded,
                                  accentColor: AppColors.warning,
                                  isSelected: _activeTypeFilter == ContentType.assignment,
                                  onSelected: () => setState(
                                    () => _activeTypeFilter = _activeTypeFilter == ContentType.assignment
                                        ? null
                                        : ContentType.assignment,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterExamsWithCount(examsCount),
                                  icon: Icons.quiz_rounded,
                                  accentColor: const Color(0xFF6366F1),
                                  isSelected: _activeTypeFilter == ContentType.exam,
                                  onSelected: () => setState(
                                    () => _activeTypeFilter = _activeTypeFilter == ContentType.exam
                                        ? null
                                        : ContentType.exam,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 5. Secondary Publication Status Filter Chips Bar
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
                                    context.read<ContentCubit>().setFilter(null);
                                  },
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterPublishedWithCount(state.publishedCount),
                                  accentColor: AppColors.success,
                                  isSelected: _activeFilter == ContentStatus.published,
                                  onSelected: () {
                                    setState(() => _activeFilter = ContentStatus.published);
                                    context.read<ContentCubit>().setFilter(ContentStatus.published);
                                  },
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterDraftsWithCount(state.draftCount),
                                  accentColor: AppColors.warning,
                                  isSelected: _activeFilter == ContentStatus.draft,
                                  onSelected: () {
                                    setState(() => _activeFilter = ContentStatus.draft);
                                    context.read<ContentCubit>().setFilter(ContentStatus.draft);
                                  },
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterArchivedWithCount(state.archivedCount),
                                  isSelected: _activeFilter == ContentStatus.archived,
                                  onSelected: () {
                                    setState(() => _activeFilter = ContentStatus.archived);
                                    context.read<ContentCubit>().setFilter(ContentStatus.archived);
                                  },
                                ),
                                if (hasActiveFilters) ...[
                                  const SizedBox(width: AppSpacing.s8),
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: AppColors.error,
                                    ),
                                    label: Text(
                                      context.l10n.clearSearchAction,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: AppColors.error.withAlpha(20),
                                    side: BorderSide(color: AppColors.error.withAlpha(50)),
                                    onPressed: () {
                                      setState(() {
                                        _activeFilter = null;
                                        _activeTypeFilter = null;
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                      context.read<ContentCubit>().setFilter(null);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 6. Content List / Targeted Empty States
                      if (state.items.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: AppEmptyView(
                                message: context.l10n.emptyContentCategory,
                                icon: Icons.folder_open_rounded,
                                actionText: context.l10n.addFirstContent,
                                onAction: _showAddMaterialSheet,
                              ),
                            ),
                          ),
                        )
                      else if (items.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: _buildEmptyFilteredState(context),
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
                                  onMoveUp: () => context.read<ContentCubit>().reorderItems(index, index - 1),
                                  onMoveDown: () => context.read<ContentCubit>().reorderItems(index, index + 1),
                                  canMoveUp: index > 0,
                                  canMoveDown: index < items.length - 1,
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
                      if (state.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                            child: Center(child: AppLoadingView.compact(size: 24)),
                          ),
                        ),
                    ],
                  ),
                );
              }

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

  Widget _buildEmptyFilteredState(BuildContext context) {
    if (_searchQuery.isNotEmpty) {
      return AppEmptyView(
        icon: Icons.search_off_rounded,
        message: context.l10n.noMatchingContentFound(_searchQuery),
        actionText: context.l10n.clearSearchAction,
        onAction: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
      );
    }

    if (_activeTypeFilter == ContentType.video) {
      return AppEmptyView(
        icon: Icons.video_library_rounded,
        message: context.l10n.noVideosInCategory,
        actionText: context.l10n.uploadFirstVideoAction,
        onAction: () => _openCreateDialog(preselectedType: ContentType.video),
      );
    }

    if (_activeTypeFilter == ContentType.pdf) {
      return AppEmptyView(
        icon: Icons.picture_as_pdf_rounded,
        message: context.l10n.noPdfsInCategory,
        actionText: context.l10n.uploadFirstPdfAction,
        onAction: () => _openCreateDialog(preselectedType: ContentType.pdf),
      );
    }

    if (_activeTypeFilter == ContentType.assignment) {
      return AppEmptyView(
        icon: Icons.assignment_rounded,
        message: context.l10n.noAssignmentsInCategory,
        actionText: context.l10n.createFirstAssignmentAction,
        onAction: () {
          if (_selectedGroupId != null) {
            context.go(
              '${AppRoutes.teacherGroupAssignments.replaceAll(':groupId', _selectedGroupId!)}?name=${Uri.encodeComponent(_selectedGroupName ?? '')}',
            );
          }
        },
      );
    }

    if (_activeTypeFilter == ContentType.exam) {
      return AppEmptyView(
        icon: Icons.quiz_rounded,
        message: context.l10n.noExamsInCategory,
        actionText: context.l10n.createFirstExamAction,
        onAction: () {
          if (_selectedGroupId != null) {
            context.go(
              '${AppRoutes.teacherGroupExams.replaceAll(':groupId', _selectedGroupId!)}?name=${Uri.encodeComponent(_selectedGroupName ?? '')}',
            );
          }
        },
      );
    }

    return AppEmptyView(
      icon: Icons.filter_alt_off_rounded,
      message: context.l10n.noMaterialsMatchFilter,
      actionText: context.l10n.clearSearchAction,
      onAction: () {
        setState(() {
          _activeFilter = null;
          _activeTypeFilter = null;
        });
        context.read<ContentCubit>().setFilter(null);
      },
    );
  }

  Widget _buildStatMiniCard({

    required String label,
    required int count,
    required Color color,
    required IconData icon,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(20) : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
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
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? color : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    IconData? icon,
    Color? accentColor,
  }) {
    final color = accentColor ?? AppColors.primary;
    return FilterChip(
      avatar: icon != null
          ? Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            )
          : null,
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: color,
      backgroundColor: AppColors.surfaceVariant,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? color : AppColors.border,
        ),
      ),
    );
  }
}
