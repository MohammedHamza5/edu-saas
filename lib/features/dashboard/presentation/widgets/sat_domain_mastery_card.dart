import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/tenant_registry.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_grid.dart';

/// كارت إتقان مجالات الرياضيات الأربعة المعتمدة من الـ College Board
/// (Heart of Algebra, Advanced Math, Problem-Solving & Data Analysis, Geometry & Trigonometry)
class SatDomainMasteryCard extends StatelessWidget {
  final int projectedScore;
  final int targetScore;
  final String nextExamDate;
  final String activeGroupName;

  const SatDomainMasteryCard({
    super.key,
    this.projectedScore = 720,
    this.targetScore = 800,
    this.nextExamDate = 'Digital SAT • August 2026',
    this.activeGroupName = 'Digital SAT Master (Target 800)',
  });

  @override
  Widget build(BuildContext context) {
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    final domains = [
      {
        'title': 'Heart of Algebra',
        'subtitle': context.l10n.domainAlgebraTitle,
        'progress': 0.92,
        'percentage': '92%',
        'status': context.l10n.domainMastered,
        'color': AppColors.success,
        'icon': Icons.functions_rounded,
      },
      {
        'title': 'Advanced Math',
        'subtitle': context.l10n.domainAdvancedMathTitle,
        'progress': 0.84,
        'percentage': '84%',
        'status': context.l10n.domainProficient,
        'color': AppColors.primary,
        'icon': Icons.auto_graph_rounded,
      },
      {
        'title': 'Problem-Solving & Data Analysis',
        'subtitle': context.l10n.domainDataAnalysisTitle,
        'progress': 0.78,
        'percentage': '78%',
        'status': context.l10n.domainInProgress,
        'color': AppColors.warning,
        'icon': Icons.pie_chart_rounded,
      },
      {
        'title': 'Geometry & Trigonometry',
        'subtitle': context.l10n.domainGeometryTitle,
        'progress': 0.88,
        'percentage': '88%',
        'status': context.l10n.domainProficient,
        'color': const Color(0xFF8B5CF6), // Royal purple
        'icon': Icons.change_history_rounded,
      },
    ];

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Projected Score & Goal
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          ),
                          child: const Center(
                            child: Text(
                              '∑',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.satMasteryIndicator,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                activeGroupName,
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
                    const SizedBox(height: AppSpacing.s12),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$projectedScore',
                          style: AppTypography.statFigureLarge.copyWith(
                            color: AppColors.primary,
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          '/ $targetScore',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        AppBadge(
                          label: nextExamDate,
                          variant: AppBadgeVariant.active,
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: const Center(
                      child: Text(
                        '∑',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.satMasteryPredictedScore,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.satMasteryDesc(activeGroupName),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$projectedScore',
                            style: AppTypography.statFigureLarge.copyWith(
                              color: AppColors.primary,
                              fontSize: 28,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ $targetScore',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      AppBadge(
                        label: nextExamDate,
                        variant: AppBadgeVariant.active,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AppSpacing.s20),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.s16),

          // 4 Domains Grid
          ResponsiveGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 2,
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s12,
            children: domains.map((d) {
              final color = d['color'] as Color;
              final progress = d['progress'] as double;
              final icon = d['icon'] as IconData;

              return Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                d['subtitle'] as String,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          d['percentage'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      d['status'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: AppSpacing.s20),

          // Next High-Priority Target Drill Alert Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, boxConstraints) {
                final isNarrow = boxConstraints.maxWidth < 450;
                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              context.l10n.nextMissionWithTeacher(branding.teacherName),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        context.l10n.drillHomeworkTitle,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                            ),
                          ),
                          onPressed: () => context.go(AppRouter.studentAssignments),
                          child: Text(context.l10n.uploadHomeworkSolutionNow, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.nextMissionWithTeacher(branding.teacherName),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            context.l10n.drillHomeworkTitle,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                        ),
                      ),
                      onPressed: () => context.go(AppRouter.studentAssignments),
                      child: Text(context.l10n.uploadHomeworkSolutionNow, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
