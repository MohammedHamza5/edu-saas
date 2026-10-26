import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';

import '../../../../core/theme/app_colors.dart';

import '../../../../core/theme/app_spacing.dart';



class TeacherExamsStatsBanner extends StatelessWidget {

  final int totalCount;

  final int generalCount;

  final int lectureCount;

  final int unlinkedLectureCount;

  final String activeTypeFilter;

  final void Function(String filter) onSelectFilter;

  final VoidCallback? onAlertTap;



  const TeacherExamsStatsBanner({

    super.key,

    required this.totalCount,

    required this.generalCount,

    required this.lectureCount,

    required this.unlinkedLectureCount,

    required this.activeTypeFilter,

    required this.onSelectFilter,

    this.onAlertTap,

  });



  @override

  Widget build(BuildContext context) {

    return LayoutBuilder(

      builder: (context, constraints) {

        final isCompact = constraints.maxWidth < 600;



        final cards = [

          _buildStatCard(

            title: context.l10n.statTotalExamsTitle,

            count: totalCount,

            subtitle: context.l10n.statTotalExamsDesc,

            color: AppColors.primary,

            icon: Icons.quiz_rounded,

            isSelected: activeTypeFilter == 'all',

            onTap: () => onSelectFilter('all'),

          ),

          _buildStatCard(

            title: context.l10n.statGeneralExamsTitle,

            count: generalCount,

            subtitle: context.l10n.statGeneralExamsDesc,

            color: const Color(0xFF7C3AED),

            icon: Icons.assignment_rounded,

            isSelected: activeTypeFilter == 'general',

            onTap: () => onSelectFilter('general'),

          ),

          _buildStatCard(

            title: context.l10n.statLectureQuizzesTitle,

            count: lectureCount,

            subtitle: context.l10n.statLectureQuizzesDesc,

            color: const Color(0xFF0284C7),

            icon: Icons.ondemand_video_rounded,

            isSelected: activeTypeFilter == 'lecture',

            onTap: () => onSelectFilter('lecture'),

            alertText: unlinkedLectureCount > 0

                ? context.l10n.statUnlinkedAlert(unlinkedLectureCount)

                : null,

            onAlertTap: onAlertTap,

          ),

        ];



        if (isCompact) {

          return SizedBox(

            height: 120,

            child: ListView.separated(

              scrollDirection: Axis.horizontal,

              itemCount: cards.length,

              separatorBuilder: (_, __) =>

                  const SizedBox(width: AppSpacing.s12),

              itemBuilder: (_, index) =>

                  SizedBox(width: 220, child: cards[index]),

            ),

          );

        }



        return Row(

          children: [

            Expanded(child: cards[0]),

            const SizedBox(width: AppSpacing.s12),

            Expanded(child: cards[1]),

            const SizedBox(width: AppSpacing.s12),

            Expanded(child: cards[2]),

          ],

        );

      },

    );

  }



  Widget _buildStatCard({

    required String title,

    required int count,

    required String subtitle,

    required Color color,

    required IconData icon,

    required bool isSelected,

    required VoidCallback onTap,

    String? alertText,

    VoidCallback? onAlertTap,

  }) {

    return Material(

      color: Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),

        child: AnimatedContainer(

          duration: const Duration(milliseconds: 200),

          padding: const EdgeInsets.all(AppSpacing.s14),

          decoration: BoxDecoration(

            color: isSelected

                ? color.withValues(alpha: 0.08)

                : AppColors.surface,

            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),

            border: Border.all(

              color: isSelected ? color : AppColors.border,

              width: isSelected ? 1.8 : 1.0,

            ),

          ),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Container(

                    padding: const EdgeInsets.all(6),

                    decoration: BoxDecoration(

                      color: color.withValues(alpha: 0.12),

                      borderRadius:

                          BorderRadius.circular(AppSpacing.radiusSmall),

                    ),

                    child: Icon(icon, color: color, size: 18),

                  ),

                  Text(

                    count.toString(),

                    style: TextStyle(

                      fontSize: 22,

                      fontWeight: FontWeight.w900,

                      color: color,

                      letterSpacing: -0.5,

                    ),

                  ),

                ],

              ),

              const SizedBox(height: AppSpacing.s8),

              Text(

                title,

                style: const TextStyle(

                  fontSize: 13,

                  fontWeight: FontWeight.bold,

                  color: AppColors.textPrimary,

                ),

              ),

              const SizedBox(height: 2),

              Text(

                subtitle,

                style: const TextStyle(

                  fontSize: 11,

                  color: AppColors.textMuted,

                ),

                maxLines: 1,

                overflow: TextOverflow.ellipsis,

              ),

              if (alertText != null) ...[

                const SizedBox(height: AppSpacing.s8),

                InkWell(

                  onTap: onAlertTap,

                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),

                  child: Container(

                    padding: const EdgeInsets.symmetric(

                      horizontal: 8,

                      vertical: 4,

                    ),

                    decoration: BoxDecoration(

                      color: AppColors.warning.withValues(alpha: 0.15),

                      borderRadius:

                          BorderRadius.circular(AppSpacing.radiusSmall),

                      border: Border.all(

                        color: AppColors.warning.withValues(alpha: 0.35),

                      ),

                    ),

                    child: Row(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        const Icon(

                          Icons.warning_amber_rounded,

                          color: AppColors.warning,

                          size: 13,

                        ),

                        const SizedBox(width: 4),

                        Text(

                          alertText,

                          style: const TextStyle(

                            fontSize: 11,

                            fontWeight: FontWeight.bold,

                            color: AppColors.warning,

                          ),

                        ),

                      ],

                    ),

                  ),

                ),

              ],

            ],

          ),

        ),

      ),

    );

  }

}

