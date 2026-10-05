import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../../../videos/presentation/dialogs/select_video_from_bank_dialog.dart';

/// A bottom sheet that shows all videos in the central Video Bank,
/// allowing the teacher to pick one for adding as a lesson.
class VideoPickerSheet extends StatefulWidget {
  final String? currentGroupId;
  final String? currentGroupName;
  final Set<String>? alreadyAddedVideoIds;
  final Set<String>? alreadyAddedTitles;
  final Set<String>? excludedVideoIds;

  const VideoPickerSheet({
    super.key,
    this.currentGroupId,
    this.currentGroupName,
    this.alreadyAddedVideoIds,
    this.alreadyAddedTitles,
    this.excludedVideoIds,
  });

  /// Shows the picker and returns the selected [ContentEntity], or null if cancelled.
  static Future<ContentEntity?> show(
    BuildContext context, {
    String? currentGroupId,
    String? currentGroupName,
    Set<String>? alreadyAddedVideoIds,
    Set<String>? alreadyAddedTitles,
    Set<String>? excludedVideoIds,
  }) {
    final pickerCubit = InjectionContainer.createContentCubit();

    return showModalBottomSheet<ContentEntity>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => pickerCubit..loadCentralVideoBank(forceRefresh: true),
        child: VideoPickerSheet(
          currentGroupId: currentGroupId,
          currentGroupName: currentGroupName,
          alreadyAddedVideoIds: alreadyAddedVideoIds,
          alreadyAddedTitles: alreadyAddedTitles,
          excludedVideoIds: excludedVideoIds,
        ),
      ),
    );
  }

  @override
  State<VideoPickerSheet> createState() => _VideoPickerSheetState();
}

class _VideoPickerSheetState extends State<VideoPickerSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ContentEntity? _selected;

  @override
  void initState() {
    super.initState();
    context.read<ContentCubit>().loadCentralVideoBank(forceRefresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isAlreadyAddedToCurrentGroup(ContentEntity video) {
    // 1. Direct group ID match
    if (widget.currentGroupId != null &&
        widget.currentGroupId!.isNotEmpty &&
        video.assignedGroupIds.contains(widget.currentGroupId)) {
      return true;
    }

    // 2. Direct group Name match
    if (widget.currentGroupName != null &&
        widget.currentGroupName!.isNotEmpty &&
        video.assignedGroupNames.any(
          (name) =>
              name.trim().toLowerCase() ==
              widget.currentGroupName!.trim().toLowerCase(),
        )) {
      return true;
    }

    // 3. Matched in alreadyAddedVideoIds set (e.g. from current group lessons)
    if (widget.alreadyAddedVideoIds != null &&
        widget.alreadyAddedVideoIds!.isNotEmpty) {
      if (widget.alreadyAddedVideoIds!.contains(video.id)) return true;
      if (video.videoId != null &&
          widget.alreadyAddedVideoIds!.contains(video.videoId)) {
        return true;
      }
      if (video.videoProviderId != null &&
          widget.alreadyAddedVideoIds!.contains(video.videoProviderId)) {
        return true;
      }
    }

    // 4. Same title already exists in the group
    if (widget.alreadyAddedTitles != null &&
        widget.alreadyAddedTitles!.isNotEmpty) {
      if (widget.alreadyAddedTitles!.contains(
        video.title.trim().toLowerCase(),
      )) {
        return true;
      }
    }

    // 5. Explicitly excluded IDs
    if (widget.excludedVideoIds != null &&
        widget.excludedVideoIds!.isNotEmpty) {
      if (widget.excludedVideoIds!.contains(video.id) ||
          (video.videoId != null &&
              widget.excludedVideoIds!.contains(video.videoId)) ||
          (video.videoProviderId != null &&
              widget.excludedVideoIds!.contains(video.videoProviderId))) {
        return true;
      }
    }

    return false;
  }

  List<ContentEntity> _filter(List<ContentEntity> items) {
    if (_searchQuery.isEmpty) return items;
    final q = _searchQuery.toLowerCase();
    return items
        .where(
          (i) =>
              i.title.toLowerCase().contains(q) ||
              (i.description?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: AppSpacing.s12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.videoPickerTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await SelectVideoFromBankDialog.show(
                      context,
                      currentGroupId: widget.currentGroupId,
                      currentGroupName: widget.currentGroupName,
                    );
                    if (picked != null && context.mounted) {
                      final mapped = ContentEntity(
                        id: picked.id,
                        tenantId: picked.tenantId,
                        title: picked.title,
                        description: picked.description,
                        type: ContentType.video,
                        status: ContentStatus.published,
                        videoProvider: picked.provider,
                        videoProviderId: picked.providerVideoId,
                        videoId: picked.id,
                        videoStatus: picked.status.name,
                        createdAt: picked.createdAt,
                        updatedAt: picked.updatedAt,
                        assignedGroupNames: picked.assignedGroupNames,
                      );
                      Navigator.of(context).pop(mapped);
                    }
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(l10n.selectFromBank),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  setState(() => _searchQuery = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: l10n.videoPickerSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
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
          ),
          const SizedBox(height: AppSpacing.s12),

          const Divider(height: 1),

          // List
          Expanded(
            child: BlocBuilder<ContentCubit, ContentState>(
              builder: (context, state) {
                if (state is ContentLoading) {
                  return const Center(child: AppLoadingView());
                }
                final all = state is ContentLoaded
                    ? state.items
                          .where(
                            (i) =>
                                (i.type == ContentType.video ||
                                    (i.videoProviderId != null &&
                                        i.videoProviderId!.isNotEmpty) ||
                                    (i.videoId != null &&
                                        i.videoId!.isNotEmpty)),
                          )
                          .toList()
                    : <ContentEntity>[];
                final filtered = _filter(all);

                if (all.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.video_library_outlined,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Text(
                            l10n.videoLibraryEmpty,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            l10n.videoLibraryEmptySubtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked =
                                  await SelectVideoFromBankDialog.show(
                                context,
                                currentGroupId: widget.currentGroupId,
                                currentGroupName: widget.currentGroupName,
                              );
                              if (picked != null && context.mounted) {
                                final mapped = ContentEntity(
                                  id: picked.id,
                                  tenantId: picked.tenantId,
                                  title: picked.title,
                                  description: picked.description,
                                  type: ContentType.video,
                                  status: ContentStatus.published,
                                  videoProvider: picked.provider,
                                  videoProviderId: picked.providerVideoId,
                                  videoId: picked.id,
                                  videoStatus: picked.status.name,
                                  createdAt: picked.createdAt,
                                  updatedAt: picked.updatedAt,
                                  assignedGroupNames: picked.assignedGroupNames,
                                );
                                Navigator.of(context).pop(mapped);
                              }
                            },
                            icon: const Icon(
                              Icons.folder_open_rounded,
                              size: 18,
                            ),
                            label: Text(l10n.selectFromBank),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.noResultsFound,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s8,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s6),
                  itemBuilder: (context, index) {
                    final video = filtered[index];
                    final isSelected = _selected?.id == video.id;
                    final isAlreadyAdded = _isAlreadyAddedToCurrentGroup(video);
                    final youtubeId = video.videoProviderId;
                    final thumbUrl = (youtubeId != null && youtubeId.isNotEmpty)
                        ? 'https://img.youtube.com/vi/$youtubeId/mqdefault.jpg'
                        : null;

                    return InkWell(
                      onTap: () => setState(() {
                        _selected = isSelected ? null : video;
                      }),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : isAlreadyAdded
                              ? AppColors.success.withValues(alpha: 0.04)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : isAlreadyAdded
                                ? AppColors.success.withValues(alpha: 0.35)
                                : AppColors.border.withValues(alpha: 0.5),
                            width: isSelected ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 72,
                                height: 48,
                                color: isAlreadyAdded
                                    ? AppColors.success.withValues(alpha: 0.08)
                                    : AppColors.primary.withValues(alpha: 0.08),
                                child: thumbUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: thumbUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const Center(
                                          child: Icon(
                                            Icons.play_circle_fill_rounded,
                                            color: AppColors.primary,
                                            size: 24,
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          isAlreadyAdded
                                              ? Icons.task_alt_rounded
                                              : Icons.play_circle_fill_rounded,
                                          color: isAlreadyAdded
                                              ? AppColors.success
                                              : AppColors.primary,
                                          size: 24,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video.title,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    video.videoProvider == 'youtube'
                                        ? context.l10n.videoSourceYoutube
                                        : context.l10n.videoSourceBunny,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (isAlreadyAdded) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: AppColors.success.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            size: 13,
                                            color: AppColors.success,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              context
                                                  .l10n
                                                  .videoAlreadyAddedToThisGroup,
                                              style: const TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (video
                                      .assignedGroupNames
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.videoAddedToGroups(
                                        video.assignedGroupNames.join('، '),
                                      ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.videoNotAddedToAnyGroup,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 22,
                              )
                            else
                              const Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: AppColors.border,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Bottom action
          Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.s24,
              right: AppSpacing.s24,
              top: AppSpacing.s16,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom + AppSpacing.s24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selected != null &&
                    _isAlreadyAddedToCurrentGroup(_selected!)) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.videoAlreadyAddedNotice,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _selected == null
                            ? null
                            : () => Navigator.of(context).pop(_selected),
                        child: Text(l10n.save),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
