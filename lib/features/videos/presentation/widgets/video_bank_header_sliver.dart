import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/video_folder_entity.dart';
import 'video_bank_stats_row.dart';

/// Filter mode for the library videos.
enum VideoFilter { all, ready, processing, usedInCourses, unused }

/// Sliver header displaying the video bank actions, statistics,
/// live upload progress banner, search field, and status filter chips.
class VideoBankHeaderSliver extends StatelessWidget {
  final bool isActionLoading;
  final bool isMobile;
  final double hPadding;
  final bool isInsideFolder;
  final VideoFolderEntity? currentFolder;
  final int totalVideos;
  final int totalFolders;
  final int readyCount;
  final int usedCount;
  final int processingCount;
  final int unusedCount;
  final bool isUploading;
  final double? uploadProgress;
  final String? uploadingTitle;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VideoFilter currentFilter;
  final ValueChanged<VideoFilter> onFilterChanged;
  final VoidCallback onAssignFolderAsChapter;
  final VoidCallback onCreateFolder;
  final VoidCallback onUploadVideo;

  const VideoBankHeaderSliver({
    super.key,
    required this.isActionLoading,
    required this.isMobile,
    required this.hPadding,
    required this.isInsideFolder,
    required this.currentFolder,
    required this.totalVideos,
    required this.totalFolders,
    required this.readyCount,
    required this.usedCount,
    required this.processingCount,
    required this.unusedCount,
    required this.isUploading,
    required this.uploadProgress,
    required this.uploadingTitle,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.currentFilter,
    required this.onFilterChanged,
    required this.onAssignFolderAsChapter,
    required this.onCreateFolder,
    required this.onUploadVideo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      key: const PageStorageKey('video_bank_header_sliver'),
      child: Container(
        color: AppColors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isActionLoading)
              const LinearProgressIndicator(
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              )
            else
              const SizedBox(height: 2.5),
            Padding(
              padding: EdgeInsets.fromLTRB(
                hPadding,
                AppSpacing.s16,
                hPadding,
                AppSpacing.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row & action buttons (Responsive for Mobile/Desktop)
                  if (isMobile) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
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
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.videoBankCmsSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
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
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: [
                        if (isInsideFolder && currentFolder != null)
                          OutlinedButton.icon(
                            onPressed: onAssignFolderAsChapter,
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
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: onCreateFolder,
                          icon: const Icon(
                            Icons.create_new_folder_outlined,
                            size: 18,
                          ),
                          label: Text(l10n.createFolder),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        AppButton(
                          text: l10n.uploadToBank,
                          icon: Icons.cloud_upload_outlined,
                          onPressed: onUploadVideo,
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
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
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.videoBankCmsSubtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isInsideFolder && currentFolder != null) ...[
                          OutlinedButton.icon(
                            onPressed: onAssignFolderAsChapter,
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
                          onPressed: onCreateFolder,
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
                          onPressed: onUploadVideo,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s16),

                  // Stats row
                  VideoBankStatsRow(
                    totalVideos: totalVideos,
                    totalFolders: totalFolders,
                    readyVideos: readyCount,
                    usedVideos: usedCount,
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Live Upload Progress Banner
                  if (isUploading && uploadProgress != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
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
                                  '${l10n.uploadingVideo} ${uploadingTitle ?? ""}',
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
                                '${(uploadProgress! * 100).toInt()}%',
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
                              value: uploadProgress,
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                  ],

                  // Search Bar
                  TextField(
                    key: const ValueKey('video_bank_search_field'),
                    controller: searchController,
                    focusNode: searchFocusNode,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l10n.videoBankSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: onClearSearch,
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
                          count: totalVideos,
                          filter: VideoFilter.all,
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        _buildFilterChip(
                          label: l10n.statusReady,
                          count: readyCount,
                          filter: VideoFilter.ready,
                          activeColor: AppColors.success,
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        _buildFilterChip(
                          label: l10n.statusProcessing,
                          count: processingCount,
                          filter: VideoFilter.processing,
                          activeColor: Colors.blue.shade700,
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        _buildFilterChip(
                          label: l10n.filterUsedInCourses,
                          count: usedCount,
                          filter: VideoFilter.usedInCourses,
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        _buildFilterChip(
                          label: l10n.notUsedInAnyCourse,
                          count: unusedCount,
                          filter: VideoFilter.unused,
                          activeColor: Colors.amber.shade700,
                        ),
                      ],
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
    required int count,
    required VideoFilter filter,
    Color? activeColor,
  }) {
    final isSelected = currentFilter == filter;
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
      onSelected: (_) => onFilterChanged(filter),
    );
  }
}
