import 'package:cached_network_image/cached_network_image.dart';
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
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/add_to_course_flow.dart';
import '../dialogs/add_video_to_bank_dialog.dart';

/// Video Library page — the central bank of reusable video assets.
///
/// Teachers create a video once here and add it to as many courses as needed.
/// The UX language is:
///   - "Video Library" (not "Bank")
///   - "Add to Course" (not "Assign to Groups")
///   - Filter: All / Used in Courses / Unused
class TeacherVideoBankPage extends StatefulWidget {
  const TeacherVideoBankPage({super.key});

  @override
  State<TeacherVideoBankPage> createState() => _TeacherVideoBankPageState();
}

/// Filter mode for the library
enum _LibraryFilter { all, usedInCourses, unused }

class _TeacherVideoBankPageState extends State<TeacherVideoBankPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _LibraryFilter _filter = _LibraryFilter.all;

  @override
  void initState() {
    super.initState();
    context.read<ContentCubit>().loadCentralVideoBank();
    context.read<GroupsCubit>().loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ContentEntity> _applyFilter(List<ContentEntity> items) {
    var result = items;

    // 1. Search
    if (_searchQuery.isNotEmpty) {
      result = result.where((i) {
        final q = _searchQuery;
        return i.title.toLowerCase().contains(q) ||
            (i.description?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    // 2. Usage filter
    switch (_filter) {
      case _LibraryFilter.usedInCourses:
        result = result.where((i) => !i.isUnassigned).toList();
        break;
      case _LibraryFilter.unused:
        result = result.where((i) => i.isUnassigned).toList();
        break;
      case _LibraryFilter.all:
        break;
    }

    return result;
  }

  Future<void> _addVideo() async {
    final added = await AddVideoToBankDialog.show(context);
    if (added == true && mounted) {
      await context.read<ContentCubit>().loadCentralVideoBank(forceRefresh: true);
    }
  }

  Future<void> _addToCourse(ContentEntity video) async {
    await AddToCourseFlow.show(context, video: video);
    if (mounted) {
      await context.read<ContentCubit>().loadCentralVideoBank(forceRefresh: true);
    }
  }

  Future<void> _handleDelete(ContentEntity item) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteItemConfirmMessage(item.title)),
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
      await context.read<ContentCubit>().deleteContent(item.id);
      if (mounted) {
        await context.read<ContentCubit>().loadCentralVideoBank(forceRefresh: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<ContentCubit, ContentState>(
        listener: (context, state) {
          if (state is ContentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error),
            );
          }
        },
        builder: (context, state) {
          if (state is ContentLoading) {
            return const Center(child: AppLoadingView());
          }
          if (state is ContentError && state is! ContentLoaded) {
            return AppErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<ContentCubit>().loadCentralVideoBank(forceRefresh: true),
            );
          }

          final all = state is ContentLoaded
              ? state.items.where((i) => i.type == ContentType.video).toList()
              : <ContentEntity>[];
          final filtered = _applyFilter(all);
          final usedCount = all.where((i) => !i.isUnassigned).length;
          final unusedCount = all.where((i) => i.isUnassigned).length;

          return RefreshIndicator(
            onRefresh: () =>
                context.read<ContentCubit>().loadCentralVideoBank(forceRefresh: true),
            child: CustomScrollView(
              slivers: [
                // ─── Header Banner ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s24, AppSpacing.s16,
                        AppSpacing.s24, AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
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
                                    l10n.videoLibraryTitle,
                                    style: theme.textTheme.titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.videoLibrarySubtitle,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            AppButton(
                              text: l10n.addVideo,
                              icon: Icons.add_rounded,
                              onPressed: _addVideo,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Stats row
                        _StatsRow(
                          total: all.length,
                          usedInCourses: usedCount,
                          unused: unusedCount,
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Search
                        TextField(
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
                                horizontal: 16, vertical: 12),
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
                              _filterChip(
                                label: l10n.filterAll,
                                count: all.length,
                                filter: _LibraryFilter.all,
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              _filterChip(
                                label: l10n.filterUsedInCourses,
                                count: usedCount,
                                filter: _LibraryFilter.usedInCourses,
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              _filterChip(
                                label: l10n.notUsedInAnyCourse,
                                count: unusedCount,
                                filter: _LibraryFilter.unused,
                                activeColor: Colors.amber.shade700,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.s16)),

                // ─── Content ──────────────────────────────────────────────
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyView(
                      icon: Icons.video_library_outlined,
                      message: all.isEmpty
                          ? l10n.videoLibraryEmpty
                          : l10n.noResultsFound,
                      subtitle: all.isEmpty
                          ? l10n.videoLibraryEmptySubtitle
                          : null,
                      actionText: all.isEmpty ? l10n.addVideo : null,
                      onAction: all.isEmpty ? _addVideo : null,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        mainAxisSpacing: AppSpacing.s16,
                        crossAxisSpacing: AppSpacing.s16,
                        mainAxisExtent: 340,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final video = filtered[index];
                          return _VideoLibraryCard(
                            key: ValueKey('lib_${video.id}'),
                            video: video,
                            onAddToCourse: () => _addToCourse(video),
                            onDelete: () => _handleDelete(video),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.s32)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required _LibraryFilter filter,
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

// ─── Stats Row ──────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int total;
  final int usedInCourses;
  final int unused;

  const _StatsRow({
    required this.total,
    required this.usedInCourses,
    required this.unused,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        return Row(
          children: [
            Expanded(
              child: _Stat(
                icon: Icons.video_collection_outlined,
                value: '$total',
                label: context.l10n.videoLibraryTitle,
                color: AppColors.primary,
                isNarrow: isNarrow,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _Stat(
                icon: Icons.school_rounded,
                value: '$usedInCourses',
                label: context.l10n.filterUsedInCourses,
                color: AppColors.success,
                isNarrow: isNarrow,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: _Stat(
                icon: Icons.folder_open_rounded,
                value: '$unused',
                label: context.l10n.notUsedInAnyCourse,
                color: Colors.amber.shade700,
                isNarrow: isNarrow,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isNarrow;

  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isNarrow ? 18 : 22),
          const SizedBox(width: AppSpacing.s6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isNarrow ? 15 : 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isNarrow ? 9 : 10,
                    color: color.withValues(alpha: 0.7),
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

// ─── Video Library Card ─────────────────────────────────────────────────────

class _VideoLibraryCard extends StatefulWidget {
  final ContentEntity video;
  final VoidCallback onAddToCourse;
  final VoidCallback onDelete;

  const _VideoLibraryCard({
    super.key,
    required this.video,
    required this.onAddToCourse,
    required this.onDelete,
  });

  @override
  State<_VideoLibraryCard> createState() => _VideoLibraryCardState();
}

class _VideoLibraryCardState extends State<_VideoLibraryCard> {
  bool _isHovered = false;

  ContentEntity get v => widget.video;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    final youtubeId = v.videoProviderId;
    final thumbUrl = (youtubeId != null && youtubeId.isNotEmpty)
        ? 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg'
        : null;

    final courseCount = v.assignedGroupIds.length;
    final isUsed = courseCount > 0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(
            color: _isHovered
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.border,
            width: _isHovered ? 1.5 : 1,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  const BoxShadow(
                    color: AppColors.shadowSoft,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  )
                ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Thumbnail ──────────────────────────────
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: thumbUrl != null
                      ? CachedNetworkImage(
                          imageUrl: thumbUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _thumbFallback(),
                        )
                      : _thumbFallback(),
                ),
                // Play overlay
                Positioned.fill(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _isHovered ? 1 : 0.7,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                // Usage badge
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUsed ? AppColors.primary : Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isUsed
                          ? l10n.usedInNCourses(courseCount)
                          : l10n.notUsedInAnyCourse,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Provider badge
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      v.videoProvider == 'youtube'
                          ? l10n.videoSourceYoutube
                          : l10n.videoSourceBunny,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Card Body ─────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),

                    // Course name badges
                    if (v.assignedGroupNames.isNotEmpty) ...[
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ...v.assignedGroupNames.take(2).map((name) =>
                              _CourseBadge(name: name)),
                          if (v.assignedGroupNames.length > 2)
                            _CourseBadge(
                              name: l10n.usedInMoreCourses(
                                  v.assignedGroupNames.length - 2),
                              isOverflow: true,
                            ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        l10n.notUsedInAnyCourse,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // ── Actions Row ──────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onAddToCourse,
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 15),
                      label: Text(
                        l10n.addToCourse,
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.4)),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        minimumSize: const Size(0, 34),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.error),
                    tooltip: l10n.deleteAction,
                    onPressed: widget.onDelete,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 34, minHeight: 34),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      color: AppColors.surfaceVariant,
      child: const Center(
        child: Icon(Icons.videocam_rounded,
            size: 40, color: AppColors.textMuted),
      ),
    );
  }
}

class _CourseBadge extends StatelessWidget {
  final String name;
  final bool isOverflow;

  const _CourseBadge({required this.name, this.isOverflow = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOverflow
            ? AppColors.surfaceVariant
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isOverflow
              ? AppColors.border
              : AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isOverflow ? AppColors.textSecondary : AppColors.primary,
        ),
      ),
    );
  }
}
