import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../../videos/domain/entities/video_folder_entity.dart';
import '../../../videos/presentation/dialogs/upload_video_to_bank_dialog.dart';
import '../models/lesson_studio_models.dart';
import 'lesson_studio_library_folder_item.dart';
import 'lesson_studio_library_video_row.dart';

/// Left sidebar for browsing the video library and selecting videos into
/// the Lesson Studio staging workspace.
class LessonStudioLibrarySidebar extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final bool isLoadingLibrary;
  final Future<void> Function() onRefreshLibrary;
  final List<VideoFolderEntity> allFolders;
  final Map<String?, List<LibraryVideoEntity>> folderVideosCache;
  final Set<String> loadingFolderIds;
  final Map<String, LibraryVideoEntity> selectedVideos;
  final Map<String, StagedLecture> stagedLectures;
  final bool Function(LibraryVideoEntity video) isVideoAlreadyInCourse;
  final Future<void> Function(String? folderId) onLoadVideosForFolder;
  final void Function(VideoFolderEntity folder) onToggleFolderSelection;
  final void Function(LibraryVideoEntity video) onToggleVideoSelection;
  final VoidCallback onClearSelection;

  const LessonStudioLibrarySidebar({
    super.key,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.isLoadingLibrary,
    required this.onRefreshLibrary,
    required this.allFolders,
    required this.folderVideosCache,
    required this.loadingFolderIds,
    required this.selectedVideos,
    required this.stagedLectures,
    required this.isVideoAlreadyInCourse,
    required this.onLoadVideosForFolder,
    required this.onToggleFolderSelection,
    required this.onToggleVideoSelection,
    required this.onClearSelection,
  });

  @override
  State<LessonStudioLibrarySidebar> createState() =>
      _LessonStudioLibrarySidebarState();
}

class _LessonStudioLibrarySidebarState
    extends State<LessonStudioLibrarySidebar> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showOnlyUnused = false;
  final Set<String> _expandedFolderIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool? _getFolderCheckboxState(VideoFolderEntity folder) {
    final videos = widget.folderVideosCache[folder.id];
    if (videos == null || videos.isEmpty) return false;
    final selectedCount =
        videos.where((v) => widget.selectedVideos.containsKey(v.id)).length;
    if (selectedCount == 0) return false;
    if (selectedCount == videos.length) return true;
    return null; // Indeterminate
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsed) {
      return _buildCollapsedSidebar(context);
    }
    return _buildExpandedSidebar(context);
  }

  Widget _buildCollapsedSidebar(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.s12),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: context.l10n.expandSidebar,
          onPressed: widget.onToggleCollapse,
        ),
        const Divider(),
        RotatedBox(
          quarterTurns: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.l10n.videoBankSidebarTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedSidebar(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      children: [
        // Sidebar Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              const Icon(
                Icons.video_library_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  l10n.videoBankSidebarTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: l10n.collapseSidebar,
                onPressed: widget.onToggleCollapse,
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: _searchController,
            onChanged: (v) =>
                setState(() => _searchQuery = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: l10n.searchVideosAndFoldersHint,
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Filter & Batch Selection Shortcuts
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              FilterChip(
                selected: _showOnlyUnused,
                onSelected: (val) => setState(() => _showOnlyUnused = val),
                label: Text(
                  l10n.unusedVideosFilter,
                  style: const TextStyle(fontSize: 11),
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              if (widget.selectedVideos.isNotEmpty)
                TextButton(
                  onPressed: widget.onClearSelection,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    l10n.clearSelection,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tree Content List
        Expanded(
          child: widget.isLoadingLibrary
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: widget.onRefreshLibrary,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // Folders List
                      for (final folder in widget.allFolders)
                        _buildFolderTreeItem(context, folder),

                      // Root / General Videos (No Folder)
                      _buildRootVideosItem(context),
                    ],
                  ),
                ),
        ),

        // Bottom Upload Direct Action
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: OutlinedButton.icon(
            onPressed: () async {
              final uploaded = await UploadVideoToBankDialog.show(context);
              if (uploaded == true) {
                await widget.onRefreshLibrary();
              }
            },
            icon: const Icon(Icons.cloud_upload_outlined, size: 16),
            label: Text(
              l10n.uploadNewVideoShort,
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderTreeItem(BuildContext context, VideoFolderEntity folder) {
    final isExpanded = _expandedFolderIds.contains(folder.id);
    final isLoading = widget.loadingFolderIds.contains(folder.id);
    final videos = widget.folderVideosCache[folder.id] ?? [];

    final filteredVideos = videos.where((v) {
      if (_searchQuery.isNotEmpty &&
          !v.title.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_showOnlyUnused && widget.isVideoAlreadyInCourse(v)) {
        return false;
      }
      return true;
    }).toList();

    // If search active and matches folder name, or has filtered videos
    if (_searchQuery.isNotEmpty &&
        filteredVideos.isEmpty &&
        !folder.name.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    final triState = _getFolderCheckboxState(folder);

    return LessonStudioLibraryFolderItem(
      folder: folder,
      isExpanded: isExpanded,
      isLoading: isLoading,
      triState: triState,
      filteredVideos: filteredVideos,
      totalVideosCount: videos.length,
      onToggleExpand: () {
        setState(() {
          if (isExpanded) {
            _expandedFolderIds.remove(folder.id);
          } else {
            _expandedFolderIds.add(folder.id);
            unawaited(widget.onLoadVideosForFolder(folder.id));
          }
        });
      },
      onToggleCheckbox: () {
        if (!widget.folderVideosCache.containsKey(folder.id)) {
          widget.onLoadVideosForFolder(folder.id).then((_) {
            widget.onToggleFolderSelection(folder);
          });
        } else {
          widget.onToggleFolderSelection(folder);
        }
      },
      videoRowBuilder: _buildVideoRow,
    );
  }

  Widget _buildRootVideosItem(BuildContext context) {
    final l10n = context.l10n;
    final isExpanded = _expandedFolderIds.contains('__root__');
    final rootVideos = widget.folderVideosCache[null] ?? [];

    final filteredVideos = rootVideos.where((v) {
      if (_searchQuery.isNotEmpty &&
          !v.title.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_showOnlyUnused && widget.isVideoAlreadyInCourse(v)) {
        return false;
      }
      return true;
    }).toList();

    if (_searchQuery.isNotEmpty && filteredVideos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedFolderIds.remove('__root__');
              } else {
                _expandedFolderIds.add('__root__');
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.snippet_folder_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.unassignedFolderVideos,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    filteredVideos.length.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              children: [
                for (final video in filteredVideos)
                  _buildVideoRow(context, video),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVideoRow(BuildContext context, LibraryVideoEntity video) {
    final isSelected = widget.selectedVideos.containsKey(video.id);
    final isAlreadyAdded = widget.isVideoAlreadyInCourse(video);
    final staged = widget.stagedLectures[video.id];

    return LessonStudioLibraryVideoRow(
      video: video,
      isSelected: isSelected,
      isAlreadyAdded: isAlreadyAdded,
      staged: staged,
      onToggle: widget.onToggleVideoSelection,
    );
  }
}
