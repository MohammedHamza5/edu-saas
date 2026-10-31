import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../extensions/localized_context_extension.dart';
import '../network/supabase_service.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'language_switcher_button.dart';

/// Renders the expanded and collapsed sidebar footers with user profile, language switcher, and logout dialog.
class StudentShellFooter extends StatelessWidget {
  final bool isCollapsed;
  final String currentLocation;

  const StudentShellFooter({
    super.key,
    this.isCollapsed = false,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return _buildCollapsed(context);
    }
    return _buildExpanded(context);
  }

  Widget _buildExpanded(BuildContext context) {
    final theme = Theme.of(context);
    final studentName =
        SupabaseService.currentUser?.userMetadata?['full_name'] as String? ??
        context.l10n.roleStudent;
    final userEmail =
        SupabaseService.currentUser?.email ?? context.l10n.roleStudent;
    final isProfileActive = currentLocation.startsWith(AppRoutes.studentProfile);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155).withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.go(AppRoutes.studentProfile),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isProfileActive ? AppColors.primary : const Color(0xFF334155),
                    child: const Icon(
                      Icons.school_rounded,
                      size: 20,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isProfileActive ? AppColors.primaryLight : Colors.white,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          userEmail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          const LanguageSwitcherButton(compact: true),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 18),
            tooltip: context.l10n.logout,
            color: const Color(0xFFF87171),
            visualDensity: VisualDensity.compact,
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context) {
    final studentName =
        SupabaseService.currentUser?.userMetadata?['full_name'] as String? ??
        context.l10n.roleStudent;
    final userEmail =
        SupabaseService.currentUser?.email ?? context.l10n.roleStudent;
    final isProfileActive = currentLocation.startsWith(AppRoutes.studentProfile);

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s8,
        horizontal: AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155).withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Tooltip(
            message: '$studentName\n$userEmail',
            preferBelow: false,
            child: InkWell(
              onTap: () => context.go(AppRoutes.studentProfile),
              borderRadius: BorderRadius.circular(18),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isProfileActive ? AppColors.primary : const Color(0xFF334155),
                child: const Icon(
                  Icons.school_rounded,
                  size: 20,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          const Divider(height: 1, color: Color(0xFF334155)),
          const SizedBox(height: AppSpacing.s8),
          const LanguageSwitcherButton(compact: true),
          const SizedBox(height: AppSpacing.s4),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 18),
            tooltip: context.l10n.logout,
            color: const Color(0xFFF87171),
            visualDensity: VisualDensity.compact,
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.logoutDialogTitle),
        content: Text(ctx.l10n.logoutDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthCubit>().logout();
      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    }
  }
}
