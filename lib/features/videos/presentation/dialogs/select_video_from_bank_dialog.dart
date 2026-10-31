import 'dart:async';
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
import '../widgets/video_bank_breadcrumbs_bar.dart';
import '../widgets/video_bank_folder_grid_tile.dart';
import '../widgets/video_bank_video_grid_card.dart';

class SelectVideoFromBankDialog extends StatefulWidget {
  final String? currentGroupId;
  final String? currentGroupName;

  const SelectVideoFromBankDialog({
    super.key,
    this.currentGroupId,
    this.currentGroupName,
  });

  static Future<LibraryVideoEntity?> show(
    BuildContext context, {
    String? currentGroupId,
    String? currentGroupName,
  }) {
    return showDialog<LibraryVideoEntity>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => BlocProvider(
        create: (_) =>
            InjectionContainer.createVideoBankCubit()..loadFolder(),
        child: SelectVideoFromBankDialog(
          currentGroupId: currentGroupId,
          currentGroupName: currentGroupName,
        ),
      ),
    );
  }

  @override
  State<SelectVideoFromBankDialog> createState() =>
      _SelectVideoFromBankDialogState();
}

class _SelectVideoFromBankDialogState extends State<SelectVideoFromBankDialog> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
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
                  return VideoBankBreadcrumbsBar(
                    hPadding: 0,
                    isInsideFolder: state.currentFolder != null,
                    breadcrumbs: state.breadcrumbs,
                    onNavigateUp: () =>
                        context.read<VideoBankCubit>().navigateUp(),
                    onNavigateToBreadcrumb: (index) => context
                        .read<VideoBankCubit>()
                        .navigateToBreadcrumb(index),
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
                      controller: _scrollController,
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
                                return VideoBankFolderGridTile(
                                  folder: f,
                                  onTap: () => context
                                      .read<VideoBankCubit>()
                                      .openFolder(f),
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
                                return VideoBankVideoGridCard(
                                  video: v,
                                  currentGroupName: widget.currentGroupName,
                                  onTap: () => Navigator.of(context).pop(v),
                                );
                              },
                              childCount: readyVideos.length,
                            ),
                          ),
                        ],
                        if (loaded.isLoadingMore)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.s12,
                              ),
                              child: Center(
                                child: AppLoadingView.compact(size: 20),
                              ),
                            ),
                          ),
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
}
