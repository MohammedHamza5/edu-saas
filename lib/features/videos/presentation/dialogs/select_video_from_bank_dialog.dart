import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/library_video_entity.dart';
import '../cubit/video_bank_cubit.dart';
import '../cubit/video_bank_state.dart';

class SelectVideoFromBankDialog extends StatefulWidget {
  const SelectVideoFromBankDialog({super.key});

  static Future<LibraryVideoEntity?> show(BuildContext context) {
    return showDialog<LibraryVideoEntity>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => BlocProvider(
        create: (_) =>
            InjectionContainer.createVideoBankCubit()..loadFolder(),
        child: const SelectVideoFromBankDialog(),
      ),
    );
  }

  @override
  State<SelectVideoFromBankDialog> createState() =>
      _SelectVideoFromBankDialogState();
}

class _SelectVideoFromBankDialogState extends State<SelectVideoFromBankDialog> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.video_library_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.selectFromBank,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.selectFromBankSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (v) => context.read<VideoBankCubit>().search(v),
                decoration: InputDecoration(
                  hintText: l10n.videoPickerSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            context.read<VideoBankCubit>().search('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),

              // Breadcrumbs
              BlocBuilder<VideoBankCubit, VideoBankState>(
                builder: (context, state) {
                  if (state is! VideoBankLoaded) return const SizedBox.shrink();
                  final trail = state.breadcrumbs;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => context
                                .read<VideoBankCubit>()
                                .navigateToBreadcrumb(-1),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          for (int i = 0; i < trail.length; i++) ...[
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            InkWell(
                              onTap: () => context
                                  .read<VideoBankCubit>()
                                  .navigateToBreadcrumb(i),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Text(
                                  trail[i].name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: i == trail.length - 1
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: i == trail.length - 1
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
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s12),

              // Main Explorer Content
              Expanded(
                child: BlocBuilder<VideoBankCubit, VideoBankState>(
                  builder: (context, state) {
                    if (state is VideoBankLoading) {
                      return const Center(child: AppLoadingView());
                    }
                    if (state is VideoBankError && state.lastLoaded == null) {
                      return AppErrorView(
                        message: state.message,
                        onRetry: () =>
                            context.read<VideoBankCubit>().loadFolder(),
                      );
                    }

                    final loaded = state is VideoBankLoaded
                        ? state
                        : (state as VideoBankError).lastLoaded!;

                    final folders = loaded.folders;
                    // Only show ready videos for lecture selection
                    final readyVideos = loaded.videos
                        .where((v) => v.isReady)
                        .toList();

                    if (folders.isEmpty && readyVideos.isEmpty) {
                      return AppEmptyView(
                        icon: Icons.video_library_outlined,
                        message: l10n.noVideosInFolder,
                      );
                    }

                    return CustomScrollView(
                      slivers: [
                        // Folders Section
                        if (folders.isNotEmpty) ...[
                          SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              mainAxisExtent: 64,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final f = folders[i];
                                return InkWell(
                                  onTap: () => context
                                      .read<VideoBankCubit>()
                                      .openFolder(f),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.folder_rounded,
                                          color: Colors.amber.shade700,
                                          size: 26,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                f.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                l10n.nVideos(f.videoCount),
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
                                  ),
                                );
                              },
                              childCount: folders.length,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.s12),
                          ),
                        ],

                        // Videos Section
                        if (readyVideos.isNotEmpty) ...[
                          SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 180,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final v = readyVideos[i];
                                return InkWell(
                                  onTap: () => Navigator.of(context).pop(v),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Thumbnail
                                        AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              if (v.thumbnailUrl != null)
                                                CachedNetworkImage(
                                                  imageUrl: v.thumbnailUrl!,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) =>
                                                      _thumbPlaceholder(),
                                                )
                                              else
                                                _thumbPlaceholder(),
                                              // Duration badge
                                              PositionedDirectional(
                                                bottom: 4,
                                                end: 4,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(
                                                      alpha: 0.75,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      4,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    v.formattedDuration,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Body
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  v.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const Spacer(),
                                                if (v.assignedLecturesCount >
                                                    0)
                                                  Text(
                                                    l10n.usedInNCourses(
                                                      v.assignedLecturesCount,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  )
                                                else
                                                  Text(
                                                    l10n.notUsedInAnyCourse,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors
                                                          .amber.shade800,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: readyVideos.length,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: AppColors.textMuted,
          size: 32,
        ),
      ),
    );
  }
}
