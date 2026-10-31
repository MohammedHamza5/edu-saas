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
import 'video_picker_bottom_bar.dart';
import 'video_picker_empty_view.dart';
import 'video_picker_item_tile.dart';

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

  Future<void> _openSelectFromBank(BuildContext context) async {
    final picked = await SelectVideoFromBankDialog.show(
      context,
      currentGroupId: widget.currentGroupId,
      currentGroupName: widget.currentGroupName,
    );
    if (!context.mounted) return;
    if (picked != null) {
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
                  onPressed: () => _openSelectFromBank(context),
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
                  return VideoPickerEmptyView(
                    onSelectFromBank: () => _openSelectFromBank(context),
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

                    return VideoPickerItemTile(
                      video: video,
                      isSelected: isSelected,
                      isAlreadyAdded: isAlreadyAdded,
                      onTap: () => setState(() {
                        _selected = isSelected ? null : video;
                      }),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Bottom action
          VideoPickerBottomBar(
            selected: _selected,
            isAlreadyAdded: _selected != null && _isAlreadyAddedToCurrentGroup(_selected!),
            onCancel: () => Navigator.of(context).pop(),
            onSave: () => Navigator.of(context).pop(_selected),
          ),
        ],
      ),
    );
  }
}
