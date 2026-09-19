import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/add_video_to_bank_dialog.dart';
import '../dialogs/assign_groups_dialog.dart';

class TeacherVideoBankPage extends StatefulWidget {
  const TeacherVideoBankPage({super.key});

  @override
  State<TeacherVideoBankPage> createState() => _TeacherVideoBankPageState();
}

class _TeacherVideoBankPageState extends State<TeacherVideoBankPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedGroupFilter; // null = all, 'unassigned' = bank only, or groupId

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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });
  }

  List<ContentEntity> _filterItems(List<ContentEntity> items) {
    return items.where((item) {
      // 1. Search Query Filter
      if (_searchQuery.isNotEmpty) {
        final titleMatch = item.title.toLowerCase().contains(_searchQuery);
        final descMatch = item.description?.toLowerCase().contains(_searchQuery) ?? false;
        if (!titleMatch && !descMatch) return false;
      }

      // 2. Group / Bank Status Filter
      if (_selectedGroupFilter == 'unassigned') {
        return item.isUnassigned;
      } else if (_selectedGroupFilter != null) {
        return item.assignedGroupIds.contains(_selectedGroupFilter) ||
            item.groupId == _selectedGroupFilter;
      }

      return true;
    }).toList();
  }

  Future<void> _handleDelete(ContentEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.deleteConfirmTitle),
        content: Text(context.l10n.deleteItemConfirmMessage(item.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              context.l10n.deleteAction,
              style: const TextStyle(color: AppColors.error),
            ),
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
              SnackBar(content: Text(state.message), backgroundColor: AppColors.error),
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
              onRetry: () => context.read<ContentCubit>().loadCentralVideoBank(forceRefresh: true),
            );
          }

          final allItems = state is ContentLoaded ? state.items : <ContentEntity>[];
          final filteredItems = _filterItems(allItems);

          final totalCount = allItems.length;
          final assignedCount = allItems.where((i) => !i.isUnassigned).length;
          final unassignedCount = allItems.where((i) => i.isUnassigned).length;

          return RefreshIndicator(
            onRefresh: () =>
                context.read<ContentCubit>().loadCentralVideoBank(forceRefresh: true),
            child: CustomScrollView(
              slivers: [
                // Top App Header Banner
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s24,
                      vertical: AppSpacing.s16,
                    ),
                    color: AppColors.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.videoBankTitle,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.videoBankSubtitle,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppButton(
                              text: l10n.addVideoToBankAction,
                              icon: Icons.add_rounded,
                              onPressed: () async {
                                final added = await AddVideoToBankDialog.show(context);
                                if (added == true && context.mounted) {
                                  await context
                                      .read<ContentCubit>()
                                      .loadCentralVideoBank(forceRefresh: true);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Stats Cards Row
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 600;
                            return Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    title: l10n.totalVideosCount(totalCount),
                                    count: totalCount,
                                    icon: Icons.video_collection_outlined,
                                    color: AppColors.primary,
                                    isNarrow: isNarrow,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: _StatCard(
                                    title: l10n.assignedVideosCount(assignedCount),
                                    count: assignedCount,
                                    icon: Icons.verified_outlined,
                                    color: AppColors.success,
                                    isNarrow: isNarrow,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: _StatCard(
                                    title: l10n.unassignedVideosCount(unassignedCount),
                                    count: unassignedCount,
                                    icon: Icons.folder_open_rounded,
                                    color: Colors.amber.shade700,
                                    isNarrow: isNarrow,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Search Field & Filter Chips
                        TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: MaterialLocalizations.of(context).searchFieldLabel,
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
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
                        const SizedBox(height: AppSpacing.s8),

                        // Filter Pills
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: Text(l10n.filterAllVideos(totalCount)),
                                selected: _selectedGroupFilter == null,
                                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: _selectedGroupFilter == null
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: _selectedGroupFilter == null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (_) => setState(() => _selectedGroupFilter = null),
                              ),
                              const SizedBox(width: AppSpacing.s4),
                              ChoiceChip(
                                label: Text(l10n.filterUnassignedOnly(unassignedCount)),
                                selected: _selectedGroupFilter == 'unassigned',
                                selectedColor: Colors.amber.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: _selectedGroupFilter == 'unassigned'
                                      ? Colors.amber.shade800
                                      : AppColors.textPrimary,
                                  fontWeight: _selectedGroupFilter == 'unassigned'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                onSelected: (_) =>
                                    setState(() => _selectedGroupFilter = 'unassigned'),
                              ),
                              const SizedBox(width: AppSpacing.s4),
                              BlocBuilder<GroupsCubit, GroupsState>(
                                builder: (context, gState) {
                                  if (gState is GroupsLoaded) {
                                    return Row(
                                      children: gState.groups.map((g) {
                                        final isSel = _selectedGroupFilter == g.id;
                                        return Padding(
                                          padding: const EdgeInsetsDirectional.only(end: 6),
                                          child: ChoiceChip(
                                            label: Text(g.name),
                                            selected: isSel,
                                            selectedColor:
                                                AppColors.primary.withValues(alpha: 0.15),
                                            labelStyle: TextStyle(
                                              fontSize: 12,
                                              color: isSel
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                              fontWeight:
                                                  isSel ? FontWeight.bold : FontWeight.normal,
                                            ),
                                            onSelected: (_) => setState(
                                              () => _selectedGroupFilter = isSel ? null : g.id,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s16)),

                // Videos Grid / List
                if (filteredItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyView(
                      icon: Icons.video_collection_outlined,
                      message: l10n.noVideosInBankTitle,
                      subtitle: l10n.noVideosInBankDesc,
                      actionText: l10n.addVideoToBankAction,
                      onAction: () async {
                        final added = await AddVideoToBankDialog.show(context);
                        if (added == true && context.mounted) {
                          await context
                              .read<ContentCubit>()
                              .loadCentralVideoBank(forceRefresh: true);
                        }
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        mainAxisSpacing: AppSpacing.s16,
                        crossAxisSpacing: AppSpacing.s16,
                        mainAxisExtent: 370,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = filteredItems[index];
                          return _VideoBankItemCard(
                            key: ValueKey('video_bank_${item.id}'),
                            item: item,
                            onAssignGroups: () async {
                              final changed =
                                  await AssignGroupsDialog.show(context, content: item);
                              if (changed == true && context.mounted) {
                                await context
                                    .read<ContentCubit>()
                                    .loadCentralVideoBank(forceRefresh: true);
                              }
                            },
                            onDelete: () => _handleDelete(item),
                          );
                        },
                        childCount: filteredItems.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s32)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final bool isNarrow;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.isNarrow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: isNarrow ? 18 : 22),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isNarrow ? 11 : 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoBankItemCard extends StatelessWidget {
  final ContentEntity item;
  final VoidCallback onAssignGroups;
  final VoidCallback onDelete;

  const _VideoBankItemCard({
    super.key,
    required this.item,
    required this.onAssignGroups,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final youtubeId = item.videoProviderId;
    final thumbnailUrl = (youtubeId != null && youtubeId.isNotEmpty)
        ? 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg'
        : null;

    return SizedBox.expand(
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Video Thumbnail Area
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surfaceVariant,
                            child: const Icon(Icons.video_library, size: 36),
                          ),
                        )
                      : Container(
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.play_circle_outline, size: 40),
                        ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final vidId = item.videoId ?? item.id;
                        context.push('/video/$vidId');
                      },
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
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
                ),
                // Status / Unassigned Badge
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isUnassigned
                          ? Colors.amber.shade700
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.isUnassigned
                          ? l10n.unassignedBadge
                          : '${item.assignedGroupNames.length} Groups',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content Information
            Expanded(
              child: InkWell(
                onTap: () {
                  final vidId = item.videoId ?? item.id;
                  context.push('/video/$vidId');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s8,
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Assigned Group Badges
                        if (item.assignedGroupNames.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: item.assignedGroupNames.take(2).map((name) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        else
                          Text(
                            l10n.noVideosInBankDesc,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                        // Attached Handout (PDF) or Lesson Quiz Badge
                        if (item.file != null || item.associatedExamTitle != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (item.file != null) ...[
                                const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  color: Colors.redAccent,
                                  size: 14,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    item.file!.fileName,
                                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              if (item.associatedExamTitle != null) ...[
                                const Icon(
                                  Icons.quiz_outlined,
                                  color: AppColors.primaryLight,
                                  size: 14,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    item.associatedExamTitle!,
                                    style: const TextStyle(fontSize: 10, color: AppColors.primaryLight),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAssignGroups,
                      icon: const Icon(Icons.group_add_rounded, size: 16),
                      label: Text(
                        l10n.assignToGroupsAction,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                    tooltip: l10n.deleteAction,
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
