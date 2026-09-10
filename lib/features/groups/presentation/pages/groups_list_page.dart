import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../cubit/groups_cubit.dart';
import '../cubit/groups_state.dart';
import '../widgets/create_group_dialog.dart';
import '../widgets/interactive_group_card.dart';

class GroupsListPage extends StatefulWidget {
  const GroupsListPage({super.key});

  @override
  State<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends State<GroupsListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<GroupsCubit>().loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const List<String> _filters = [
    'ALL',
    'SAT',
    'EST',
    'ACT',
    'Basics',
    'Advanced',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.groupsListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refresh,
            onPressed: () => context.read<GroupsCubit>().loadGroups(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.newGroupButton),
        backgroundColor: AppColors.primary,
        onPressed: () => CreateGroupDialog.show(context),
      ),
      body: BlocBuilder<GroupsCubit, GroupsState>(
        builder: (context, state) {
          if (state is GroupsLoading || state is GroupsInitial) {
            return ResponsiveContainer(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: AppLoadingView(
                  style: AppLoadingStyle.skeletonList,
                  message: context.l10n.loadingGroupsList,
                ),
              ),
            );
          }

          if (state is GroupsError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<GroupsCubit>().loadGroups(),
            );
          }

          if (state is GroupsLoaded) {
            final filteredGroups = state.filteredGroups;

            // Apply client-side search query
            final displayedGroups = filteredGroups.where((g) {
              if (_searchQuery.isEmpty) return true;
              final q = _searchQuery.toLowerCase();
              return g.name.toLowerCase().contains(q) ||
                  (g.description?.toLowerCase().contains(q) ?? false);
            }).toList();

            return ResponsiveContainer(
              maxWidth: 1200,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search & Quick Filters Header
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: context.l10n.searchGroupsHint,
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: AppSpacing.s8,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() => _searchQuery = val.trim());
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.s12),

                  // Filter chips list for American tracks
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.s8),
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final isAll = filter == 'ALL';
                        final filterLabel = isAll ? context.l10n.filterAll : filter;
                        final isSelected =
                            (state.filterLevel == null && isAll) ||
                            state.filterLevel == filter;

                        return FilterChip(
                          label: Text(filterLabel),
                          selected: isSelected,
                          selectedColor: AppColors.primaryLight.withValues(
                            alpha: 0.18,
                          ),
                          checkmarkColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                          onSelected: (_) {
                            context.read<GroupsCubit>().setFilterLevel(
                              isAll ? null : filter,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s12),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.s12),

                  // Groups Grid / List / Empty View
                  Expanded(
                    child: displayedGroups.isEmpty
                        ? (state.groups.isEmpty
                              ? AppEmptyView(
                                  message: context.l10n.noGroupsYet,
                                  actionText: context.l10n.createFirstGroup,
                                  onAction: () =>
                                      CreateGroupDialog.show(context),
                                )
                              : AppEmptyView(
                                  message: context.l10n.noGroupsMatchingFilter,
                                  actionText: context.l10n.resetFilters,
                                  onAction: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                    context.read<GroupsCubit>().setFilterLevel(
                                      null,
                                    );
                                  },
                                ))
                        : SingleChildScrollView(
                            child: ResponsiveGrid(
                              mobileColumns: 1,
                              tabletColumns: 2,
                              desktopColumns: 3,
                              spacing: AppSpacing.s16,
                              runSpacing: AppSpacing.s16,
                              children: displayedGroups
                                  .map(
                                    (group) =>
                                        InteractiveGroupCard(group: group),
                                  )
                                  .toList(),
                            ),
                          ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
