import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/presentation/dialogs/add_to_course_flow.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../domain/entities/library_video_entity.dart';
import '../../domain/entities/video_folder_entity.dart';
import '../cubit/video_bank_cubit.dart';
import '../cubit/video_bank_state.dart';
import '../dialogs/assign_folder_as_chapter_dialog.dart';
import '../dialogs/upload_video_to_bank_dialog.dart';
import '../dialogs/video_bank_folder_dialogs.dart';
import '../dialogs/video_preview_dialog.dart';
import '../widgets/video_bank_breadcrumbs_bar.dart';
import '../widgets/video_bank_grid_slivers.dart';
import '../widgets/video_bank_header_sliver.dart';

class TeacherVideoBankPage extends StatefulWidget {
  const TeacherVideoBankPage({super.key});

  @override
  State<TeacherVideoBankPage> createState() => _TeacherVideoBankPageState();
}

class _TeacherVideoBankPageState extends State<TeacherVideoBankPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  VideoFilter _filter = VideoFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<VideoBankCubit>().loadFolder();
    context.read<GroupsCubit>().loadGroups();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      unawaited(context.read<VideoBankCubit>().loadMoreVideos());
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<VideoBankCubit>().search(query);
      }
    });
  }

  List<LibraryVideoEntity> _applyFilter(List<LibraryVideoEntity> items) {
    switch (_filter) {
      case VideoFilter.ready:
        return items.where((v) => v.isReady).toList();
      case VideoFilter.processing:
        return items.where((v) => v.isProcessing).toList();
      case VideoFilter.usedInCourses:
        return items.where((v) => v.assignedLecturesCount > 0).toList();
      case VideoFilter.unused:
        return items.where((v) => v.assignedLecturesCount == 0).toList();
      case VideoFilter.all:
        return items;
    }
  }

  Future<void> _handleCreateFolder() async {
    final cubit = context.read<VideoBankCubit>();
    final l10n = context.l10n;
    final result = await CreateFolderDialog.show(context);
    if (!mounted) return;
    if (result != null && result.name.trim().isNotEmpty) {
      final success = await cubit.createFolder(result.name, color: result.color);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.folderCreatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _handleChangeFolderColor(VideoFolderEntity folder) async {
    final cubit = context.read<VideoBankCubit>();
    final l10n = context.l10n;
    final newColor = await ChangeFolderColorDialog.show(
      context,
      folder: folder,
    );
    if (!mounted) return;
    if (newColor != null) {
      final actualColor = newColor.isEmpty ? null : newColor;
      final success = await cubit.updateFolderColor(folder.id, actualColor);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.folderColorUpdated),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
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
    final cubit = context.read<VideoBankCubit>();
    final newName = await RenameFolderDialog.show(
      context,
      currentName: folder.name,
    );
    if (!mounted) return;
    if (newName != null && newName.trim().isNotEmpty) {
      await cubit.renameFolder(folder.id, newName);
      if (!mounted) return;
    }
  }

  Future<void> _handleDeleteFolder(VideoFolderEntity folder) async {
    final cubit = context.read<VideoBankCubit>();
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
    if (!mounted) return;
    if (confirmed == true) {
      await cubit.deleteFolder(folder.id);
      if (!mounted) return;
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
    final cubit = context.read<VideoBankCubit>();
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

    if (!mounted) return;
    if (confirmed == true) {
      await cubit.deleteVideo(video.id);
      if (!mounted) return;
    }
  }

  Future<void> _handleSyncVideo(LibraryVideoEntity video) async {
    final l10n = context.l10n;
    final cubit = context.read<VideoBankCubit>();
    final success = await cubit.syncVideo(video.id);
    if (!mounted) return;
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

  Future<void> _handleAddToCourse(LibraryVideoEntity video) async {
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

    final cubit = context.read<VideoBankCubit>();
    await AddToCourseFlow.show(context, video: contentEntity);
    if (!mounted) return;
    await cubit.loadFolder(forceRefresh: true);
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
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

          final isMobile = MediaQuery.of(context).size.width < 800;
          final hPadding = isMobile ? AppSpacing.s16 : AppSpacing.s24;

          return RefreshIndicator(
            onRefresh: () =>
                context.read<VideoBankCubit>().loadFolder(forceRefresh: true),
            child: ResponsiveContainer(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // ── Header Banner ─────────────────────────────────────────
                  VideoBankHeaderSliver(
                    isActionLoading: loaded.isActionLoading,
                    isMobile: isMobile,
                    hPadding: hPadding,
                    isInsideFolder: isInsideFolder,
                    currentFolder: loaded.currentFolder,
                    totalVideos: allVideos.length,
                    totalFolders: folders.length,
                    readyCount: readyCount,
                    usedCount: usedCount,
                    processingCount: processingCount,
                    unusedCount: unusedCount,
                    isUploading: isUploading,
                    uploadProgress: progress,
                    uploadingTitle: loaded.uploadingTitle,
                    searchController: _searchController,
                    searchFocusNode: _searchFocusNode,
                    onSearchChanged: _onSearchChanged,
                    onClearSearch: () {
                      _searchDebounce?.cancel();
                      _searchController.clear();
                      context.read<VideoBankCubit>().search('');
                    },
                    currentFilter: _filter,
                    onFilterChanged: (filter) =>
                        setState(() => _filter = filter),
                    onAssignFolderAsChapter: () {
                      if (loaded.currentFolder != null) {
                        _handleAssignFolderAsChapter(loaded.currentFolder!);
                      }
                    },
                    onCreateFolder: _handleCreateFolder,
                    onUploadVideo: () =>
                        _handleUploadVideo(loaded.currentFolder?.name),
                  ),

                  // ── Breadcrumbs Navigation Bar ────────────────────────────
                  SliverToBoxAdapter(
                    child: VideoBankBreadcrumbsBar(
                      hPadding: hPadding,
                      isInsideFolder: isInsideFolder,
                      breadcrumbs: breadcrumbs,
                      onNavigateUp: () =>
                          context.read<VideoBankCubit>().navigateUp(),
                      onNavigateToBreadcrumb: (i) => context
                          .read<VideoBankCubit>()
                          .navigateToBreadcrumb(i),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.s16),
                  ),

                  // ── Folders Section ────────────────────────────────────────
                  if (folders.isNotEmpty) ...[
                    VideoBankFoldersGridSliver(
                      folders: folders,
                      isMobile: isMobile,
                      hPadding: hPadding,
                      onOpen: (f) {
                        if (_searchController.text.isNotEmpty) {
                          _searchDebounce?.cancel();
                          _searchController.clear();
                        }
                        context.read<VideoBankCubit>().openFolder(f);
                      },
                      onAssignAsChapter: _handleAssignFolderAsChapter,
                      onChangeColor: _handleChangeFolderColor,
                      onRename: _handleRenameFolder,
                      onDelete: _handleDeleteFolder,
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.s20),
                    ),
                  ],

                  // ── Videos Grid ────────────────────────────────────────────
                  VideoBankVideosGridSliver(
                    filteredVideos: filteredVideos,
                    hasFolders: folders.isNotEmpty,
                    hPadding: hPadding,
                    currentFolderName: loaded.currentFolder?.name,
                    isLoadingMore: loaded.isLoadingMore,
                    onPreview: _handlePreviewVideo,
                    onAddToCourse: _handleAddToCourse,
                    onMove: _handleMoveVideo,
                    onRename: _handleRenameVideo,
                    onDelete: _handleDeleteVideo,
                    onSync: _handleSyncVideo,
                    onUploadVideo: () =>
                        _handleUploadVideo(loaded.currentFolder?.name),
                  ),

                  if (loaded.isLoadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                        child: Center(
                          child: AppLoadingView.compact(size: 24),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.s32),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
