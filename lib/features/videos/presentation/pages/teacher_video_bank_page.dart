import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../domain/entities/library_video_entity.dart';
import '../cubit/video_bank_cubit.dart';
import '../cubit/video_bank_state.dart';
import '../utils/teacher_video_bank_actions_coordinator.dart';
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
                        TeacherVideoBankActionsCoordinator.assignFolderAsChapter(
                          context,
                          loaded.currentFolder!,
                        );
                      }
                    },
                    onCreateFolder: () =>
                        TeacherVideoBankActionsCoordinator.createFolder(context),
                    onUploadVideo: () =>
                        TeacherVideoBankActionsCoordinator.uploadVideo(
                      context,
                      loaded.currentFolder?.name,
                    ),
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
                      onAssignAsChapter: (f) =>
                          TeacherVideoBankActionsCoordinator.assignFolderAsChapter(
                        context,
                        f,
                      ),
                      onChangeColor: (f) =>
                          TeacherVideoBankActionsCoordinator.changeFolderColor(
                        context,
                        f,
                      ),
                      onRename: (f) =>
                          TeacherVideoBankActionsCoordinator.renameFolder(
                        context,
                        f,
                      ),
                      onDelete: (f) =>
                          TeacherVideoBankActionsCoordinator.deleteFolder(
                        context,
                        f,
                      ),
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
                    onPreview: (v) =>
                        TeacherVideoBankActionsCoordinator.previewVideo(
                      context,
                      v,
                    ),
                    onAddToCourse: (v) =>
                        TeacherVideoBankActionsCoordinator.addToCourse(
                      context,
                      v,
                    ),
                    onMove: (v) =>
                        TeacherVideoBankActionsCoordinator.moveVideo(
                      context,
                      v,
                    ),
                    onRename: (v) =>
                        TeacherVideoBankActionsCoordinator.renameVideo(
                      context,
                      v,
                    ),
                    onDelete: (v) =>
                        TeacherVideoBankActionsCoordinator.deleteVideo(
                      context,
                      v,
                    ),
                    onSync: (v) =>
                        TeacherVideoBankActionsCoordinator.syncVideo(
                      context,
                      v,
                    ),
                    onUploadVideo: () =>
                        TeacherVideoBankActionsCoordinator.uploadVideo(
                      context,
                      loaded.currentFolder?.name,
                    ),
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
