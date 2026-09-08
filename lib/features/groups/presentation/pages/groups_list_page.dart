import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../cubit/groups_cubit.dart';
import '../cubit/groups_state.dart';
import '../widgets/create_group_dialog.dart';

class GroupsListPage extends StatefulWidget {
  const GroupsListPage({super.key});

  @override
  State<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends State<GroupsListPage> {
  @override
  void initState() {
    super.initState();
    context.read<GroupsCubit>().loadGroups();
  }

  static const List<String> _filters = [
    'الكل',
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
        title: const Text('المجموعات الدراسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: () => context.read<GroupsCubit>().loadGroups(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('مجموعة جديدة'),
        backgroundColor: AppColors.primary,
        onPressed: () => CreateGroupDialog.show(context),
      ),
      body: BlocBuilder<GroupsCubit, GroupsState>(
        builder: (context, state) {
          if (state is GroupsLoading || state is GroupsInitial) {
            return const AppLoadingView(message: 'جاري تحميل المجموعات الدراسية...');
          }

          if (state is GroupsError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<GroupsCubit>().loadGroups(),
            );
          }

          if (state is GroupsLoaded) {
            final filteredGroups = state.filteredGroups;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Filter chips
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s8,
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected =
                          (state.filterLevel == null && filter == 'الكل') ||
                              state.filterLevel == filter;

                      return FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        selectedColor: AppColors.primaryLight.withValues(alpha: 0.3),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          context
                              .read<GroupsCubit>()
                              .setFilterLevel(filter == 'الكل' ? null : filter);
                        },
                      );
                    },
                  ),
                ),

                const Divider(height: 1),

                // Groups list / empty view
                Expanded(
                  child: filteredGroups.isEmpty
                      ? AppEmptyView(
                          message: 'لا توجد مجموعات دراسية مطابقة حالياً',
                          actionText: 'إنشاء أول مجموعة',
                          onAction: () => CreateGroupDialog.show(context),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          itemCount: filteredGroups.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.s12),
                          itemBuilder: (context, index) {
                            final group = filteredGroups[index];
                            return AppCard(
                              onTap: () {
                                context.push(
                                  '${AppRouter.groupsList}/${group.id}',
                                  extra: group,
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          group.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      AppBadge(
                                        label: group.level,
                                        variant: AppBadgeVariant.active,
                                      ),
                                    ],
                                  ),
                                  if (group.description != null &&
                                      group.description!.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.s8),
                                    Text(
                                      group.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.s12),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.people_outline,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: AppSpacing.s4),
                                      Text(
                                        '${group.membersCount} طلاب',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const Spacer(),
                                      AppBadge(
                                        label: group.isPreviousContentAllowed
                                            ? 'المحتوى السابق متاح'
                                            : 'محتوى جديد فقط',
                                        variant: group.isPreviousContentAllowed
                                            ? AppBadgeVariant.active
                                            : AppBadgeVariant.neutral,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
