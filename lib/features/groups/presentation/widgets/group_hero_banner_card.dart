import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/math_tokens.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/group_entity.dart';

/// Hero Academic Group Banner Card with mathematical watermark glyph.
class GroupHeroBannerCard extends StatelessWidget {
  final GroupEntity group;
  final String mathSymbol;

  const GroupHeroBannerCard({
    super.key,
    required this.group,
    required this.mathSymbol,
  });

  @override
  Widget build(BuildContext context) {
    final mathTokens =
        Theme.of(context).extension<MathTokens>() ?? MathTokens.light;

    return RepaintBoundary(
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Background subtle watermark glyph
            PositionedDirectional(
              top: -10,
              end: -8,
              child: IgnorePointer(
                child: Opacity(
                  opacity: mathTokens.formulaSymbolOpacity,
                  child: Text(
                    mathSymbol,
                    style: const TextStyle(
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
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
                  if (group.description != null &&
                      group.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s12),
                    Text(
                      group.description!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
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
