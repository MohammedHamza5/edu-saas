import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';

/// A bottom sheet that shows all videos in the central Video Bank,
/// allowing the teacher to pick one for adding as a lesson.
class VideoPickerSheet extends StatefulWidget {
  final Set<String>? excludedVideoIds;
  const VideoPickerSheet({super.key, this.excludedVideoIds});

  /// Shows the picker and returns the selected [ContentEntity], or null if cancelled.
  static Future<ContentEntity?> show(BuildContext context, {Set<String>? excludedVideoIds}) {
    final pickerCubit = InjectionContainer.createContentCubit();

    return showModalBottomSheet<ContentEntity>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (_) => pickerCubit..loadCentralVideoBank(forceRefresh: true),
        child: VideoPickerSheet(excludedVideoIds: excludedVideoIds),
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
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        .where((i) =>
                            (i.type == ContentType.video ||
                            (i.videoProviderId != null &&
                                i.videoProviderId!.isNotEmpty) ||
                            (i.videoId != null && i.videoId!.isNotEmpty)) &&
                            !(widget.excludedVideoIds?.contains(i.id) ?? false))
                        .toList()
                    : <ContentEntity>[];
                final filtered = _filter(all);

                if (all.isEmpty) {
                  return AppEmptyView(
                    icon: Icons.video_library_outlined,
                    message: l10n.videoLibraryEmpty,
                    subtitle: l10n.videoLibraryEmptySubtitle,
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
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s4),
                  itemBuilder: (context, index) {
                    final video = filtered[index];
                    final isSelected = _selected?.id == video.id;
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
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.4)
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
                              child: SizedBox(
                                width: 72,
                                height: 48,
                                child: thumbUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: thumbUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          color: AppColors.surfaceVariant,
                                          child: const Icon(Icons.videocam_rounded, size: 20),
                                        ),
                                      )
                                    : Container(
                                        color: AppColors.surfaceVariant,
                                        child: const Icon(Icons.videocam_rounded, size: 20),
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
                                    style: theme.textTheme.bodyMedium?.copyWith(
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
              bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s24,
            ),
            child: Row(
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
          ),
        ],
      ),
    );
  }
}
