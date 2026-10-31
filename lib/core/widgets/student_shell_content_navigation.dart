import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/groups/domain/entities/group_entity.dart';
import '../../features/groups/presentation/cubit/groups_cubit.dart';
import '../../features/groups/presentation/cubit/groups_state.dart';
import '../di/injection_container.dart';
import '../extensions/localized_context_extension.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/cache_manager.dart';
import '../utils/group_slug_resolver.dart';

/// Handles student course navigation and multi-group bottom sheet selection.
class StudentShellContentNavigation {
  StudentShellContentNavigation._();

  static Future<void> handleContentNavigation(BuildContext context) async {
    // 1. Try resolving groups instantly from GroupsCubit state or AppCache (0ms response)
    List<GroupEntity> groups = [];
    try {
      final groupsState = context.read<GroupsCubit>().state;
      if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
        groups = groupsState.groups;
      }
    } catch (_) {}

    if (groups.isEmpty) {
      final cached = AppCache.groups.getStale(AppCache.userKey('groups'));
      if (cached is List<GroupEntity> && cached.isNotEmpty) {
        groups = cached;
      }
    }

    // 2. Fallback: if cache is empty, load silently and wait
    if (groups.isEmpty) {
      try {
        await context.read<GroupsCubit>().loadGroups();
        if (!context.mounted) return;
        final freshState = context.read<GroupsCubit>().state;
        if (freshState is GroupsLoaded) {
          groups = freshState.groups;
        }
      } catch (_) {
        final result = await InjectionContainer.groupsRepository.getGroups();
        groups = result.dataOrNull ?? [];
      }
    }

    if (!context.mounted) return;

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.studentNoGroupsAssigned),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }

    // 3. Single-group fast path (direct 0ms jump)
    if (groups.length == 1) {
      final g = groups.first;
      final slug = GroupSlugResolver.toSlug(g.id, g.name);
      context.go(
        AppRoutes.studentGroupContent.replaceAll(':groupId', slug),
        extra: g.name,
      );
      return;
    }

    // 4. Multi-group selector sheet
    showCourseSelectorSheet(context, groups);
  }

  static void showCourseSelectorSheet(
    BuildContext context,
    List<GroupEntity> groups,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: const Icon(
                      Icons.play_circle_filled_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.myLecturesSectionTitle,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.myLecturesSectionSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              ...groups.map((g) {
                final slug = GroupSlugResolver.toSlug(g.id, g.name);
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(
                        Icons.play_lesson_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      g.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(g.level),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.go(
                        AppRoutes.studentGroupContent.replaceAll(
                          ':groupId',
                          slug,
                        ),
                        extra: g.name,
                      );
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
