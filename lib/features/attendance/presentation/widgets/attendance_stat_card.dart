import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';

class AttendanceStatCard extends StatefulWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Color? color;
  final IconData? icon;

  const AttendanceStatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.color,
    this.icon,
  });

  @override
  State<AttendanceStatCard> createState() => _AttendanceStatCardState();
}

class _AttendanceStatCardState extends State<AttendanceStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? AppColors.primary;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0.0, 0),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              child: Stack(
                children: [
                  // Top Accent Indicator Line
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: _isHovered ? 3.0 : 2.0,
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? effectiveColor
                            : effectiveColor.withValues(alpha: 0.6),
                        boxShadow: _isHovered
                            ? [
                                BoxShadow(
                                  color: effectiveColor.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),

                  // Main Content
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (widget.icon != null) ...[
                              const SizedBox(width: AppSpacing.s4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.all(AppSpacing.s4),
                                decoration: BoxDecoration(
                                  color: _isHovered
                                      ? effectiveColor.withValues(alpha: 0.18)
                                      : effectiveColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSmall,
                                  ),
                                ),
                                child: Icon(
                                  widget.icon,
                                  size: 16,
                                  color: effectiveColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          widget.value,
                          style: AppTypography.statFigureLarge.copyWith(
                            color: effectiveColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
