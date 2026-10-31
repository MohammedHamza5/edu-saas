import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Top AppBar for the Teacher Course Builder view.
class TeacherCourseAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String? selectedGroupName;
  final VoidCallback onRefresh;

  const TeacherCourseAppBar({
    super.key,
    required this.selectedGroupName,
    required this.onRefresh,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = selectedGroupName != null
        ? context.l10n.groupContentPrefix(selectedGroupName!)
        : context.l10n.courseBuilderTitle;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: context.l10n.backTooltip,
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(AppRoutes.teacherDashboard);
          }
        },
      ),
      title: Row(
        children: [
          const Icon(
            Icons.school_rounded,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: context.l10n.refreshTooltip,
          onPressed: onRefresh,
        ),
      ],
    );
  }
}
