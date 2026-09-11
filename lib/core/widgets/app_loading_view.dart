import 'package:flutter/material.dart';
import '../extensions/responsive_context_extension.dart';
import '../localization/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/responsive_breakpoints.dart';
import 'app_skeleton.dart';
import 'math_loading_indicator.dart';
import 'responsive_container.dart';
import 'responsive_grid.dart';

enum AppLoadingStyle {
  spinner,
  skeletonCard,
  skeletonList,
  mathCurve,
  cardsGrid,
  list,
  profile,
  dashboard,
  compact,
}

/// The unified loading view component for the EduSaaS academic platform.
///
/// Provides both signature mathematical animated loaders and structured academic shimmer skeletons.
class AppLoadingView extends StatelessWidget {
  final String? message;
  final AppLoadingStyle style;
  final int count;
  final int columns;
  final double maxWidth;
  final double size;
  final Color? color;
  final bool hasAvatar;
  final bool hasBadge;

  const AppLoadingView({
    super.key,
    this.message,
    this.style = AppLoadingStyle.mathCurve,
    this.count = 4,
    this.columns = 2,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
    this.size = 90,
    this.color,
    this.hasAvatar = true,
    this.hasBadge = true,
  });

  /// Responsive grid of shimmering academic entity cards (Exams, Assignments, Groups, Content).
  const AppLoadingView.cardsGrid({
    super.key,
    this.count = 4,
    this.columns = 2,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
  })  : style = AppLoadingStyle.cardsGrid,
        message = null,
        size = 90,
        color = null,
        hasAvatar = false,
        hasBadge = false;

  /// Shimmering list items (Students, Pending students, Notifications, Attendance).
  const AppLoadingView.list({
    super.key,
    this.count = 6,
    this.hasAvatar = true,
    this.hasBadge = true,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
  })  : style = AppLoadingStyle.list,
        message = null,
        columns = 1,
        size = 90,
        color = null;

  /// Shimmering detail/profile page layout (Student 360, Group Detail).
  const AppLoadingView.profile({
    super.key,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
  })  : style = AppLoadingStyle.profile,
        message = null,
        count = 1,
        columns = 1,
        size = 90,
        color = null,
        hasAvatar = true,
        hasBadge = true;

  /// Shimmering dashboard layout (Teacher Dashboard, Parent Dashboard).
  const AppLoadingView.dashboard({
    super.key,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
  })  : style = AppLoadingStyle.dashboard,
        message = null,
        count = 1,
        columns = 3,
        size = 90,
        color = null,
        hasAvatar = true,
        hasBadge = true;

  /// Bespoke mathematical sinusoidal curve tracer for modal or full-screen loading.
  const AppLoadingView.signature({
    super.key,
    this.message,
    this.size = 90,
    this.color,
  })  : style = AppLoadingStyle.mathCurve,
        count = 1,
        columns = 1,
        maxWidth = ResponsiveBreakpoints.maxContentWidth,
        hasAvatar = false,
        hasBadge = false;

  /// Precision mathematical compass spinner for inline slots, buttons, and chips.
  const AppLoadingView.compact({
    super.key,
    this.size = 20,
    this.color,
  })  : style = AppLoadingStyle.compact,
        message = null,
        count = 1,
        columns = 1,
        maxWidth = ResponsiveBreakpoints.maxContentWidth,
        hasAvatar = false,
        hasBadge = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayMessage =
        message ?? (l10n != null ? l10n.loading : 'Loading...');

    return switch (style) {
      AppLoadingStyle.compact => MathLoadingIndicator.compact(
          size: size,
          color: color,
        ),
      AppLoadingStyle.mathCurve => Center(
          child: MathLoadingIndicator(
            message: displayMessage,
            size: size,
            color: color,
          ),
        ),
      AppLoadingStyle.spinner => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MathLoadingIndicator.compact(
                size: 28,
                color: color ?? AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                displayMessage,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      AppLoadingStyle.cardsGrid => SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: context.responsivePagePadding,
          child: ResponsiveContainer(
            maxWidth: maxWidth,
            child: ResponsiveGrid(
              mobileColumns: 1,
              tabletColumns: columns == 3 ? 2 : 2,
              desktopColumns: columns,
              spacing: AppSpacing.s16,
              runSpacing: AppSpacing.s16,
              children: List.generate(
                count,
                (_) => const AcademicCardSkeleton(),
              ),
            ),
          ),
        ),
      AppLoadingStyle.list => SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: context.responsivePagePadding,
          child: ResponsiveContainer(
            maxWidth: maxWidth,
            child: Column(
              children: List.generate(
                count,
                (_) => AcademicListTileSkeleton(
                  hasAvatar: hasAvatar,
                  hasBadge: hasBadge,
                ),
              ),
            ),
          ),
        ),
      AppLoadingStyle.profile => SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: context.responsivePagePadding,
          child: AcademicProfileSkeleton(maxWidth: maxWidth),
        ),
      AppLoadingStyle.dashboard => SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: context.responsivePagePadding,
          child: AcademicDashboardSkeleton(maxWidth: maxWidth),
        ),
      AppLoadingStyle.skeletonCard => const Padding(
          padding: EdgeInsets.all(AppSpacing.s16),
          child: AcademicCardSkeleton(),
        ),
      AppLoadingStyle.skeletonList => Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            children: List.generate(
              4,
              (_) => const AcademicListTileSkeleton(),
            ),
          ),
        ),
    };
  }
}
