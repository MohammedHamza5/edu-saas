import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_badge.dart';
import '../widgets/app_card.dart';
import '../../features/groups/domain/entities/group_entity.dart';
import '../../features/groups/presentation/cubit/groups_cubit.dart';
import '../../features/groups/presentation/cubit/groups_state.dart';

/// Modern mathematical group filter bar.
/// Allows instant switching between groups directly on the page without dialogs or modals.
class TeacherGroupFilterBar extends StatelessWidget {
  final String? selectedGroupId;
  final ValueChanged<GroupEntity> onGroupChanged;
  final VoidCallback? onRefresh;
  final GroupsCubit? groupsCubit;

  const TeacherGroupFilterBar({
    super.key,
    required this.selectedGroupId,
    required this.onGroupChanged,
    this.onRefresh,
    this.groupsCubit,
  });

  @override
  Widget build(BuildContext context) {
    GroupsCubit? cubit = groupsCubit;
    if (cubit == null) {
      try {
        cubit = context.read<GroupsCubit>();
      } catch (_) {
        cubit = null;
      }
    }

    if (cubit == null) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<GroupsCubit, GroupsState>(
      bloc: cubit,
      builder: (context, state) {
        if (state is GroupsLoading && selectedGroupId == null) {
          return Container(
            height: 52,
            margin: const EdgeInsets.only(bottom: AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (state is GroupsLoaded) {
          final groups = state.groups;

          if (groups.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s16),
              child: AppCard(
                variant: AppCardVariant.standard,
                padding: const EdgeInsets.all(AppSpacing.s12),
                child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  const Expanded(
                    child: Text(
                      'لا توجد مجموعات دراسية حالياً. أنشئ مجموعة أولاً للبدء.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8,
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('إنشاء مجموعة', style: TextStyle(fontSize: 12)),
                    onPressed: () => context.push(AppRouter.groupsList),
                  ),
                ],
              ),
            ),
          );
        }

          // Auto-select first group if none selected or if selected is not found
          final currentGroup = groups.where((g) => g.id == selectedGroupId).firstOrNull;
          if (currentGroup == null && groups.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onGroupChanged(groups.first);
            });
          }

          final effectiveGroup = currentGroup ?? groups.first;

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s16),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Academic group icon
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),

                // Label
                const Text(
                  'المجموعة:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),

                // Group Dropdown Selector
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: effectiveGroup.id,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      onChanged: (String? newId) {
                        if (newId == null || newId == effectiveGroup.id) return;
                        final selected = groups.where((g) => g.id == newId).firstOrNull;
                        if (selected != null) {
                          onGroupChanged(selected);
                        }
                      },
                      items: groups.map((g) {
                        return DropdownMenuItem<String>(
                          value: g.id,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  g.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              AppBadge(
                                label: g.level,
                                variant: AppBadgeVariant.neutral,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Refresh button if provided
                if (onRefresh != null) ...[
                  const SizedBox(width: AppSpacing.s8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    tooltip: 'تحديث المحتوى',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: onRefresh,
                  ),
                ],
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
