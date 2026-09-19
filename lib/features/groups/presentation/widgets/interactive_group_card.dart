import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/math_tokens.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../domain/entities/group_entity.dart';

/// High-performance, tactile mathematical SaaS Group Card
/// Conforms to [docs/UI_UX_INTERACTION_MASTER_PLAYBOOK.md]:
/// - Isolated via [RepaintBoundary]
/// - Hardware-accelerated hover lift (-2.5px) & micro-scale (1.01)
/// - Tactile click downscale (0.985)
/// - Snappy 180ms easing curves (Zero Frame Drops)
/// - Subtle mathematical watermark glyph based on American track
class InteractiveGroupCard extends StatefulWidget {
  final GroupEntity group;
  final VoidCallback? onTap;

  const InteractiveGroupCard({super.key, required this.group, this.onTap});

  @override
  State<InteractiveGroupCard> createState() => _InteractiveGroupCardState();
}

class _InteractiveGroupCardState extends State<InteractiveGroupCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  // Track-specific mathematical watermark symbol
  String _getMathSymbol(String level) {
    final lower = level.toLowerCase();
    if (lower.contains('sat')) return 'f(x)';
    if (lower.contains('est')) return 'Δ';
    if (lower.contains('act')) return '√x';
    if (lower.contains('basic')) return '∑';
    if (lower.contains('advance') || lower.contains('calc')) return '∫';
    return 'π';
  }

  // Track-specific subtle accent border tint on hover
  Color _getTrackAccentColor(String level) {
    final lower = level.toLowerCase();
    if (lower.contains('sat')) return AppColors.primary;
    if (lower.contains('est')) return const Color(0xFF0D9488); // Teal 600
    if (lower.contains('act')) return const Color(0xFFD97706); // Amber 600
    if (lower.contains('basic')) return const Color(0xFF2563EB); // Blue 600
    if (lower.contains('advance') || lower.contains('calc')) {
      return const Color(0xFF7C3AED); // Purple 600
    }
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final mathTokens =
        Theme.of(context).extension<MathTokens>() ?? MathTokens.light;
    final accentColor = _getTrackAccentColor(group.level);
    final mathSymbol = _getMathSymbol(group.level);

    // Compute active scale based on press & hover states
    final double scale = _isPressed ? 0.985 : (_isHovered ? 1.012 : 1.0);

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() {
          _isHovered = false;
          _isPressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap:
              widget.onTap ??
              () {
                context.go(
                  '${AppRoutes.groupsList}/${group.id}',
                  extra: group,
                );
              },
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, _isHovered ? -2.5 : 0, 0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: _isHovered
                      ? accentColor.withValues(alpha: 0.35)
                      : mathTokens.cardBorderColor,
                  width: _isHovered ? 1.5 : 1.0,
                ),
                boxShadow: _isHovered
                    ? const [
                        BoxShadow(
                          color: Color(0x0C0F172A),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: Stack(
                  children: [
                    // Subtle mathematical background glyph watermark
                    PositionedDirectional(
                      top: -12,
                      end: -10,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _isHovered
                              ? 0.08
                              : mathTokens.formulaSymbolOpacity,
                          child: Text(
                            mathSymbol,
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: accentColor,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Main Card Content
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top Header: Group Name & Level Badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  group.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _isHovered
                                        ? accentColor
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              AppBadge(
                                label: group.level,
                                variant: AppBadgeVariant.active,
                              ),
                            ],
                          ),

                          // Description (if present)
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
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.s8),

                          // Bottom Metadata Row: Members Count, Content Policy & Quick Attendance
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: AppSpacing.s8,
                            runSpacing: AppSpacing.s8,
                            children: [
                              Wrap(
                                spacing: AppSpacing.s8,
                                runSpacing: AppSpacing.s4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // Members Count Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusSmall,
                                      ),
                                      border: Border.all(
                                        color: AppColors.border.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.people_alt_outlined,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${group.membersCount}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Content Policy Pill
                                  AppBadge(
                                    label: group.isPreviousContentAllowed
                                        ? context.l10n.previousContentAllowedPill
                                        : context.l10n.newOnlyPill,
                                    variant: group.isPreviousContentAllowed
                                        ? AppBadgeVariant.active
                                        : AppBadgeVariant.neutral,
                                  ),
                                ],
                              ),

                              // Quick One-Click Attendance Action Button
                              Tooltip(
                                message: context.l10n.quickAttendanceTooltip,
                                waitDuration: const Duration(milliseconds: 400),
                                child: IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primaryLight
                                        .withValues(alpha: 0.15),
                                    foregroundColor: AppColors.primary,
                                    minimumSize: const Size(36, 36),
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: const Icon(
                                    Icons.fact_check_outlined,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    context.go(
                                      '${AppRoutes.teacherAttendance}?groupId=${group.id}',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
