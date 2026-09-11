import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/responsive_breakpoints.dart';
import 'app_card.dart';
import 'responsive_container.dart';
import 'responsive_grid.dart';

/// A performant, mathematical shimmer container using ShaderMask and LinearGradient.
///
/// Features:
/// - Pure Flutter (Zero external dependencies).
/// - Mathematical gradient angle and smooth sweeping motion.
/// - RepaintBoundary for GPU paint isolation.
/// - Static in test mode so widget tests don't time out on pumpAndSettle.
class AcademicShimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const AcademicShimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE2E8F0),
    this.highlightColor = const Color(0xFFEDF2F7),
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<AcademicShimmer> createState() => _AcademicShimmerState();
}

class _AcademicShimmerState extends State<AcademicShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _controller.repeat();
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: const Alignment(-1.0, -0.3),
                end: const Alignment(1.0, 0.3),
                colors: [
                  widget.baseColor,
                  widget.highlightColor,
                  widget.baseColor,
                ],
                stops: const [0.25, 0.5, 0.75],
                transform: _SlidingGradientTransform(
                  slidePercent: _controller.value,
                ),
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}

/// Primitive skeleton shape widget (rectangle or circle).
class AppSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Color? color;

  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.color,
  });

  const AppSkeleton.circle({
    super.key,
    required double size,
    this.color,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = BoxShape.circle;

  const AppSkeleton.rect({
    super.key,
    this.width,
    required double this.height,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppSpacing.radiusSmall),
    ),
    this.color,
  }) : shape = BoxShape.rectangle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFE2E8F0),
        borderRadius: shape == BoxShape.circle
            ? null
            : (borderRadius ?? BorderRadius.circular(AppSpacing.radiusSmall)),
        shape: shape,
      ),
    );
  }
}

/// Pre-built skeleton layout for entity cards (Exams, Assignments, Groups, Content).
/// The card frame remains static white, while only the internal skeleton bars shimmer.
class AcademicCardSkeleton extends StatelessWidget {
  const AcademicCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      variant: AppCardVariant.elevated,
      child: AcademicShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Title + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppSkeleton.rect(height: 18, width: 140),
                AppSkeleton.rect(
                  height: 22,
                  width: 65,
                  borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusFull)),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.s8),
            // Subtitle / Group tag
            AppSkeleton.rect(height: 12, width: 90),
            SizedBox(height: AppSpacing.s16),
            // Thin divider
            AppSkeleton.rect(height: 1, width: double.infinity),
            SizedBox(height: AppSpacing.s12),
            // Meta pills row
            Row(
              children: [
                AppSkeleton.rect(
                  height: 24,
                  width: 72,
                  borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusSmall)),
                ),
                SizedBox(width: AppSpacing.s8),
                AppSkeleton.rect(
                  height: 24,
                  width: 72,
                  borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusSmall)),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.s12),
            // Footer line
            AppSkeleton.rect(height: 12, width: 120),
          ],
        ),
      ),
    );
  }
}

/// Pre-built skeleton layout for list items (Students, Pending students, Notifications).
/// The list tile container remains static white, while internal placeholder shapes shimmer.
class AcademicListTileSkeleton extends StatelessWidget {
  final bool hasAvatar;
  final bool hasBadge;

  const AcademicListTileSkeleton({
    super.key,
    this.hasAvatar = true,
    this.hasBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: AcademicShimmer(
        child: Row(
          children: [
            if (hasAvatar) ...[
              const AppSkeleton.circle(size: 42),
              const SizedBox(width: AppSpacing.s12),
            ],
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton.rect(height: 16, width: 130),
                  SizedBox(height: AppSpacing.s6),
                  AppSkeleton.rect(height: 12, width: 190),
                ],
              ),
            ),
            if (hasBadge)
              const AppSkeleton.rect(
                height: 24,
                width: 68,
                borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusFull)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pre-built skeleton layout for profile / detail pages (Student 360, Group Details).
class AcademicProfileSkeleton extends StatelessWidget {
  final double maxWidth;

  const AcademicProfileSkeleton({
    super.key,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      maxWidth: maxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          const AppCard(
            variant: AppCardVariant.elevated,
            child: AcademicShimmer(
              child: Row(
                children: [
                  AppSkeleton.circle(size: 64),
                  SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeleton.rect(height: 22, width: 180),
                        SizedBox(height: AppSpacing.s8),
                        AppSkeleton.rect(height: 14, width: 220),
                      ],
                    ),
                  ),
                  AppSkeleton.rect(
                    height: 32,
                    width: 90,
                    borderRadius: BorderRadius.all(Radius.circular(AppSpacing.radiusMedium)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // 4 Metric Stats Grid
          ResponsiveGrid(
            mobileColumns: 2,
            tabletColumns: 4,
            desktopColumns: 4,
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s12,
            children: List.generate(
              4,
              (_) => const AppSkeletonCard(height: 90),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Detail Section Cards
          const AppCard(
            child: AcademicShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton.rect(height: 20, width: 140),
                  SizedBox(height: AppSpacing.s12),
                  AppSkeleton.rect(height: 14, width: double.infinity),
                  SizedBox(height: AppSpacing.s8),
                  AppSkeleton.rect(height: 14, width: 260),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pre-built skeleton layout for dashboards (Teacher Dashboard, Parent Dashboard).
class AcademicDashboardSkeleton extends StatelessWidget {
  final double maxWidth;

  const AcademicDashboardSkeleton({
    super.key,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      maxWidth: maxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner Skeleton
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: const AcademicShimmer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppSkeleton.rect(height: 22, width: 220),
                  SizedBox(height: AppSpacing.s8),
                  AppSkeleton.rect(height: 14, width: 160),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Metric Stats Cards Grid
          ResponsiveGrid(
            mobileColumns: 2,
            tabletColumns: 4,
            desktopColumns: 4,
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s12,
            children: List.generate(
              4,
              (_) => const AppSkeletonCard(height: 100),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Content Cards Grid
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 3,
            spacing: AppSpacing.s16,
            runSpacing: AppSpacing.s16,
            children: List.generate(
              3,
              (_) => const AcademicCardSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Backward-compatible skeleton list item.
class AppSkeletonListItem extends StatelessWidget {
  final double avatarSize;
  final int textLines;

  const AppSkeletonListItem({
    super.key,
    this.avatarSize = 40,
    this.textLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: AcademicShimmer(
        child: Row(
          children: [
            AppSkeleton.circle(size: avatarSize),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSkeleton.rect(height: 16, width: 140),
                  if (textLines >= 2) ...[
                    const SizedBox(height: AppSpacing.s8),
                    const AppSkeleton.rect(height: 12, width: 200),
                  ],
                  if (textLines >= 3) ...[
                    const SizedBox(height: AppSpacing.s8),
                    const AppSkeleton.rect(height: 12, width: 100),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backward-compatible skeleton card.
class AppSkeletonCard extends StatelessWidget {
  final double height;

  const AppSkeletonCard({
    super.key,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: const AcademicShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton.rect(height: 16, width: 70),
            SizedBox(height: AppSpacing.s8),
            AppSkeleton.rect(height: 24, width: 50),
            Spacer(),
            AppSkeleton.rect(height: 10, width: 90),
          ],
        ),
      ),
    );
  }
}
