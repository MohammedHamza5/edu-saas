import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../../videos/domain/entities/video_folder_entity.dart';
import '../../../videos/presentation/cubit/video_bank_cubit.dart';
import '../../../videos/presentation/cubit/video_bank_state.dart';
import '../../../videos/presentation/dialogs/assign_folder_as_chapter_dialog.dart';
import '../../../videos/presentation/dialogs/upload_video_to_bank_dialog.dart';
import '../../../videos/presentation/dialogs/video_bank_folder_dialogs.dart';
import '../../../videos/presentation/dialogs/video_preview_dialog.dart';
import '../../../videos/presentation/widgets/video_bank_cards.dart';
import '../../domain/entities/content_entity.dart';
import '../dialogs/add_to_course_flow.dart';

/// Filter mode for the library videos
enum _VideoFilter { all, ready, processing, usedInCourses, unused }

class TeacherVideoBankPage extends StatefulWidget {
  const TeacherVideoBankPage({super.key});

  @override
  State<TeacherVideoBankPage> createState() => _TeacherVideoBankPageState();
}

class _TeacherVideoBankPageState extends State<TeacherVideoBankPage> {
  final TextEditingController _searchController = TextEditingController();
  _VideoFilter _filter = _VideoFilter.all;

  @override
  void initState() {
    super.initState();
    context.read<VideoBankCubit>().loadFolder();
    context.read<GroupsCubit>().loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LibraryVideoEntity> _applyFilter(List<LibraryVideoEntity> items) {
    switch (_filter) {
      case _VideoFilter.ready:
        return items.where((v) => v.isReady).toList();
      case _VideoFilter.processing:
        return items.where((v) => v.isProcessing).toList();
      case _VideoFilter.usedInCourses:
        return items.where((v) => v.assignedLecturesCount > 0).toList();
      case _VideoFilter.unused:
        return items.where((v) => v.assignedLecturesCount == 0).toList();
      case _VideoFilter.all:
        return items;
    }
  }

  Future<void> _handleCreateFolder() async {
    final name = await CreateFolderDialog.show(context);
    if (name != null && name.trim().isNotEmpty && mounted) {
      final success = await context.read<VideoBankCubit>().createFolder(name);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.folderCreatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _handleAssignFolderAsChapter(VideoFolderEntity folder) async {
    final success = await AssignFolderAsChapterDialog.show(
      context,
      folder: folder,
    );
    if (success == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.assignFolderAsChapterSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleRenameFolder(VideoFolderEntity folder) async {
    final newName = await RenameFolderDialog.show(
      context,
      currentName: folder.name,
    );
    if (newName != null && newName.trim().isNotEmpty && mounted) {
      await context.read<VideoBankCubit>().renameFolder(folder.id, newName);
    }
  }

  Future<void> _handleDeleteFolder(VideoFolderEntity folder) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteFolderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<VideoBankCubit>().deleteFolder(folder.id);
    }
  }

  Future<void> _handleUploadVideo(String? currentFolderName) async {
    await UploadVideoToBankDialog.show(
      context,
      currentFolderName: currentFolderName,
    );
  }

  Future<void> _handlePreviewVideo(LibraryVideoEntity video) async {
    final cubit = context.read<VideoBankCubit>();
    await VideoPreviewDialog.show(
      context,
      videoId: video.id,
      videoTitle: video.title,
      cubit: cubit,
    );
  }

  Future<void> _handleMoveVideo(LibraryVideoEntity video) async {
    final cubit = context.read<VideoBankCubit>();
    final loaded = cubit.currentLoadedState;
    if (loaded == null) return;

    // Fetch all folders to let teacher pick destination
    await cubit.loadFolder(); // ensures state is fresh
    if (!mounted) return;
    final targetFolderId = await MoveVideoDialog.show(
      context,
      allFolders: loaded.folders,
      currentFolderId: video.folderId,
    );

    if (targetFolderId != null && mounted) {
      final actualTargetId = targetFolderId == '__ROOT__'
          ? null
          : targetFolderId;
      final success = await cubit.moveVideo(
        videoId: video.id,
        targetFolderId: actualTargetId,
      );
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.videoMovedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _handleRenameVideo(LibraryVideoEntity video) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: video.title);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameVideo),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.videoTitleHint),
            validator: (v) =>
                v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          AppButton(
            text: l10n.save,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<VideoBankCubit>().renameVideo(
        videoId: video.id,
        newTitle: controller.text.trim(),
      );
    }
  }

  Future<void> _handleDeleteVideo(LibraryVideoEntity video) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteVideoConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<VideoBankCubit>().deleteVideo(video.id);
    }
  }

  Future<void> _handleSyncVideo(LibraryVideoEntity video) async {
    final l10n = context.l10n;
    final success = await context.read<VideoBankCubit>().syncVideo(video.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? l10n.videoStatusRefreshed : l10n.videoStatusRefreshFailed,
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleAddToCourse(LibraryVideoEntity video) async {
    // Map LibraryVideoEntity to ContentEntity for the AddToCourseFlow
    final contentEntity = ContentEntity(
      id: video.id,
      tenantId: video.tenantId,
      title: video.title,
      description: video.description,
      type: ContentType.video,
      status: ContentStatus.published,
      videoProvider: video.provider,
      videoProviderId: video.providerVideoId,
      videoId: video.id,
      createdAt: video.createdAt,
      updatedAt: video.updatedAt,
      assignedGroupNames: video.assignedGroupNames,
    );

    await AddToCourseFlow.show(context, video: contentEntity);
    if (mounted) {
      await context.read<VideoBankCubit>().loadFolder(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<VideoBankCubit, VideoBankState>(
        listener: (context, state) {
          if (state is VideoBankError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is VideoBankInitial || state is VideoBankLoading) {
            return const Center(child: AppLoadingView());
          }

          if (state is VideoBankError && state.lastLoaded == null) {
            return AppErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<VideoBankCubit>().loadFolder(forceRefresh: true),
            );
          }

          final VideoBankLoaded loaded;
          if (state is VideoBankLoaded) {
            loaded = state;
          } else if (state is VideoBankError && state.lastLoaded != null) {
            loaded = state.lastLoaded!;
          } else {
            return const Center(child: AppLoadingView());
          }

          final allVideos = loaded.videos;
          final filteredVideos = _applyFilter(allVideos);
          final folders = loaded.folders;
          final breadcrumbs = loaded.breadcrumbs;
          final isInsideFolder = loaded.currentFolder != null;
          final isUploading = loaded.isUploading;
          final progress = loaded.uploadProgress;

          final readyCount = allVideos.where((v) => v.isReady).length;
          final processingCount = allVideos.where((v) => v.isProcessing).length;
          final usedCount = allVideos
              .where((v) => v.assignedLecturesCount > 0)
              .length;
          final unusedCount = allVideos
              .where((v) => v.assignedLecturesCount == 0)
              .length;

          final isMobile = MediaQuery.of(context).size.width < 650;
          final hPadding = isMobile ? AppSpacing.s16 : AppSpacing.s24;

          return RefreshIndicator(
            onRefresh: () =>
                context.read<VideoBankCubit>().loadFolder(forceRefresh: true),
            child: CustomScrollView(
              slivers: [
                if (loaded.isActionLoading)
                  const SliverToBoxAdapter(
                    child: LinearProgressIndicator(
                      minHeight: 2.5,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                // ── Header Banner ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.surface,
                    padding: EdgeInsets.fromLTRB(
                      hPadding,
                      AppSpacing.s16,
                      hPadding,
                      AppSpacing.s16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row & action buttons (Responsive for Mobile)
                        if (isMobile) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.video_library_rounded,
                                  color: AppColors.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.videoBankCmsTitle,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.videoBankCmsSubtitle,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _handleCreateFolder,
                                  icon: const Icon(
                                    Icons.create_new_folder_outlined,
                                    size: 18,
                                  ),
                                  label: Text(l10n.createFolder),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: AppButton(
                                  text: l10n.uploadToBank,
                                  icon: Icons.cloud_upload_outlined,
                                  onPressed: () => _handleUploadVideo(
                                    loaded.currentFolder?.name,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.video_library_rounded,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.videoBankCmsTitle,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.videoBankCmsSubtitle,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isInsideFolder && loaded.currentFolder != null) ...[
                                OutlinedButton.icon(
                                  onPressed: () => _handleAssignFolderAsChapter(
                                    loaded.currentFolder!,
                                  ),
                                  icon: const Icon(
                                    Icons.auto_stories_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  label: Text(
                                    l10n.assignFolderAsChapter,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                              ],
                              OutlinedButton.icon(
                                onPressed: _handleCreateFolder,
                                icon: const Icon(
                                  Icons.create_new_folder_outlined,
                                  size: 18,
                                ),
                                label: Text(l10n.createFolder),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              AppButton(
                                text: l10n.uploadToBank,
                                icon: Icons.cloud_upload_outlined,
                                onPressed: () => _handleUploadVideo(
                                  loaded.currentFolder?.name,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.s16),

                        // Stats row
                        _BankStatsRow(
                          totalVideos: allVideos.length,
                          totalFolders: folders.length,
                          readyVideos: readyCount,
                          usedVideos: usedCount,
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Live Upload Progress Banner
                        if (isUploading && progress != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.cloud_upload_rounded,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${l10n.uploadingVideo} ${loaded.uploadingTitle ?? ""}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.primary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${(progress * 100).toInt()}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 6,
                                    backgroundColor: AppColors.surfaceVariant,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppColors.primary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                        ],

                        // Search Bar & Filter chips
                        TextField(
                          controller: _searchController,
                          onChanged: (v) =>
                              context.read<VideoBankCubit>().search(v),
                          decoration: InputDecoration(
                            hintText: l10n.videoPickerSearchHint,
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      context.read<VideoBankCubit>().search('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.surfaceVariant.withValues(
                              alpha: 0.4,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),

                        // Filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                label: l10n.filterAll,
                                count: allVideos.length,
                                filter: _VideoFilter.all,
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              _buildFilterChip(
                                label: l10n.statusReady,
                                count: readyCount,
                                filter: _VideoFilter.ready,
                                activeColor: AppColors.success,
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              _buildFilterChip(
                                label: l10n.statusProcessing,
                                count: processingCount,
                                filter: _VideoFilter.processing,
                                activeColor: Colors.blue.shade700,
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              _buildFilterChip(
                                label: l10n.filterUsedInCourses,
                                count: usedCount,
                                filter: _VideoFilter.usedInCourses,
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              _buildFilterChip(
                                label: l10n.notUsedInAnyCourse,
                                count: unusedCount,
                                filter: _VideoFilter.unused,
                                activeColor: Colors.amber.shade700,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Breadcrumbs Navigation Bar ────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: hPadding,
                      vertical: AppSpacing.s8,
                    ),
                    color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (isInsideFolder)
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                              ),
                              tooltip: l10n.backTooltip,
                              onPressed: () =>
                                  context.read<VideoBankCubit>().navigateUp(),
                            ),
                          InkWell(
                            onTap: () => context
                                .read<VideoBankCubit>()
                                .navigateToBreadcrumb(-1),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.home_outlined,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.rootFolderTitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          for (int i = 0; i < breadcrumbs.length; i++) ...[
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            InkWell(
                              onTap: () => context
                                  .read<VideoBankCubit>()
                                  .navigateToBreadcrumb(i),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Text(
                                  breadcrumbs[i].name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: i == breadcrumbs.length - 1
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: i == breadcrumbs.length - 1
                                        ? AppColors.textPrimary
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.s16),
                ),

                // ── Folders Section ────────────────────────────────────────
                if (folders.isNotEmpty) ...[
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: hPadding),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isMobile ? 600 : 320,
                        mainAxisSpacing: AppSpacing.s12,
                        crossAxisSpacing: AppSpacing.s12,
                        mainAxisExtent: 72,
                      ),
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final f = folders[i];
                        return VideoBankFolderCard(
                          key: ValueKey('folder_${f.id}'),
                          folder: f,
                          onOpen: () =>
                              context.read<VideoBankCubit>().openFolder(f),
                          onAssignAsChapter: () =>
                              _handleAssignFolderAsChapter(f),
                          onRename: () => _handleRenameFolder(f),
                          onDelete: () => _handleDeleteFolder(f),
                        );
                      }, childCount: folders.length),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.s20),
                  ),
                ],

                // ── Videos Grid ────────────────────────────────────────────
                if (filteredVideos.isEmpty && folders.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyView(
                      icon: Icons.video_library_outlined,
                      message: l10n.noVideosInFolder,
                      actionText: l10n.uploadToBank,
                      onAction: () =>
                          _handleUploadVideo(loaded.currentFolder?.name),
                    ),
                  )
                else if (filteredVideos.isNotEmpty) ...[
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: hPadding),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 360,
                            mainAxisSpacing: AppSpacing.s16,
                            crossAxisSpacing: AppSpacing.s16,
                            mainAxisExtent: 320,
                          ),
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final v = filteredVideos[i];
                        return VideoBankVideoCard(
                          key: ValueKey('lib_${v.id}'),
                          video: v,
                          onPreview: () => _handlePreviewVideo(v),
                          onAddToCourse: () => _handleAddToCourse(v),
                          onMove: () => _handleMoveVideo(v),
                          onRename: () => _handleRenameVideo(v),
                          onDelete: () => _handleDeleteVideo(v),
                          onSync: () => _handleSyncVideo(v),
                        );
                      }, childCount: filteredVideos.length),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.s32),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required _VideoFilter filter,
    Color? activeColor,
  }) {
    final isSelected = _filter == filter;
    final color = activeColor ?? AppColors.primary;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        fontSize: 12,
        color: isSelected ? color : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _filter = filter),
    );
  }
}

class _BankStatsRow extends StatelessWidget {
  final int totalVideos;
  final int totalFolders;
  final int readyVideos;
  final int usedVideos;

  const _BankStatsRow({
    required this.totalVideos,
    required this.totalFolders,
    required this.readyVideos,
    required this.usedVideos,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        final card1 = _StatCard(
          icon: Icons.video_collection_outlined,
          value: '$totalVideos',
          label: l10n.videoBankCmsTitle,
          color: AppColors.primary,
        );
        final card2 = _StatCard(
          icon: Icons.folder_rounded,
          value: '$totalFolders',
          label: l10n.rootFolderTitle,
          color: Colors.amber.shade700,
        );
        final card3 = _StatCard(
          icon: Icons.check_circle_outline_rounded,
          value: '$readyVideos',
          label: l10n.statusReady,
          color: AppColors.success,
        );
        final card4 = _StatCard(
          icon: Icons.school_rounded,
          value: '$usedVideos',
          label: l10n.filterUsedInCourses,
          color: Colors.purple.shade600,
        );

        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: card4),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: card2),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: card3),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: card4),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
