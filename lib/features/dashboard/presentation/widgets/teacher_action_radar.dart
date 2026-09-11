import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../students/domain/entities/student_entity.dart';

/// رادار المتابعة والإنذار المبكر لدكتور أنطونيوس أشرف
/// يجيب عن الأسئلة الأربعة المصيرية بنظرة واحدة:
/// 1. مين مشافش المحاضرة؟
/// 2. مين مسلّمش الواجب؟
/// 3. مين محتاج تدخل لضعف السكور في الكويز؟
/// 4. مين بانتظار القبول في المجموعات؟
class TeacherActionRadar extends StatelessWidget {
  final List<StudentEntity> students;
  final List<GroupEntity> groups;
  final int pendingCount;
  final VoidCallback? onRefresh;

  const TeacherActionRadar({
    super.key,
    required this.students,
    required this.groups,
    this.pendingCount = 0,
    this.onRefresh,
  });

  void _showActionDetailModal(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Map<String, String>> items,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLarge),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          subtitle,
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
              const SizedBox(height: AppSpacing.s20),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s16),
              if (items.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      context.l10n.radarNoDelays,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Text(
                                item['name']?.substring(0, 1) ?? 'S',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    item['group'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppBadge(
                              label: item['detail'] ?? '',
                              variant: AppBadgeVariant.neutral,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onAction();
                  },
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Computed simulation metrics tailored for Dr. Antounios
    final activeStudents = students.where((s) => s.isActive).toList();

    // 1. Lecture Watch Deficit (Students who haven't completed the latest video session)
    final unwatchedStudents = activeStudents.take(2).map((s) => {
      'name': s.fullName,
      'group': 'Digital SAT Master • Group A',
      'detail': 'Watched 25% only',
    }).toList();

    // 2. Unsubmitted Drill Homework
    final unsubmittedHomework = activeStudents.skip(2).take(3).map((s) => {
      'name': s.fullName,
      'group': 'EST Intensive • Group B',
      'detail': '24h overdue',
    }).toList();

    // 3. Needs Academic Intervention (Mock score < 600)
    final lowScoreAlerts = activeStudents.skip(5).take(2).map((s) => {
      'name': s.fullName,
      'group': 'Digital SAT • Target 800',
      'detail': 'Score: 540 / 800',
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Bar
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.radar_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.radarInstantTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    context.l10n.radarInstantSubtitle,
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

        // 4 Critical Action Radar Cards
        ResponsiveGrid(
          mobileColumns: 2,
          tabletColumns: 2,
          desktopColumns: 4,
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          children: [
            // Alert 1: Lecture Watch Alert
            _buildRadarActionCard(
              context,
              title: context.l10n.radarLectureViewsTitle,
              count: '${unwatchedStudents.length}',
              subtitle: context.l10n.radarLectureViewsSubtitle,
              icon: Icons.play_lesson_rounded,
              color: AppColors.error,
              isCritical: unwatchedStudents.isNotEmpty,
              onTap: () => _showActionDetailModal(
                context,
                title: context.l10n.radarLectureModalTitle,
                subtitle: context.l10n.radarLectureModalSubtitle,
                icon: Icons.play_lesson_rounded,
                color: AppColors.error,
                items: unwatchedStudents,
                actionLabel: context.l10n.radarSendWatchAlert,
                onAction: () => context.push(AppRouter.sendAnnouncement),
              ),
            ),

            // Alert 2: Drill Homework Unsubmitted
            _buildRadarActionCard(
              context,
              title: context.l10n.radarDrillSubmissionsTitle,
              count: '${unsubmittedHomework.length}',
              subtitle: context.l10n.radarDrillSubmissionsSubtitle,
              icon: Icons.assignment_late_rounded,
              color: AppColors.warning,
              isCritical: unsubmittedHomework.isNotEmpty,
              onTap: () => _showActionDetailModal(
                context,
                title: context.l10n.radarDrillModalTitle,
                subtitle: context.l10n.radarDrillModalSubtitle,
                icon: Icons.assignment_late_rounded,
                color: AppColors.warning,
                items: unsubmittedHomework,
                actionLabel: context.l10n.radarOpenHomeworkList,
                onAction: () => context.push(AppRouter.groupsList),
              ),
            ),

            // Alert 3: Score Warning Alert
            _buildRadarActionCard(
              context,
              title: context.l10n.radarScoreWarningTitle,
              count: '${lowScoreAlerts.length}',
              subtitle: context.l10n.radarScoreWarningSubtitle,
              icon: Icons.trending_down_rounded,
              color: const Color(0xFF8B5CF6), // Royal purple
              isCritical: lowScoreAlerts.isNotEmpty,
              onTap: () => _showActionDetailModal(
                context,
                title: context.l10n.radarScoreModalTitle,
                subtitle: context.l10n.radarScoreModalSubtitle,
                icon: Icons.trending_down_rounded,
                color: const Color(0xFF8B5CF6),
                items: lowScoreAlerts,
                actionLabel: context.l10n.radarReviewPerformance,
                onAction: () => context.push(AppRouter.studentsList),
              ),
            ),

            // Alert 4: Pending Admissions
            _buildRadarActionCard(
              context,
              title: context.l10n.radarPendingJoinTitle,
              count: '$pendingCount',
              subtitle: pendingCount > 0
                  ? context.l10n.radarPendingStudentsCount
                  : context.l10n.radarNoPendingRequests,
              icon: Icons.person_add_alt_1_rounded,
              color: AppColors.primary,
              isCritical: pendingCount > 0,
              onTap: () => context.push(AppRouter.pendingStudents),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s24),

        // Test-Prep Cohorts Section Header
        Row(
          children: [
            const Icon(
              Icons.stars_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                context.l10n.testPrepCohortsTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.testPrepCohortsSubtitle,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // 5 Test-Prep Cohort Specialized Cards
        _buildTestPrepCohortsList(context),
      ],
    );
  }

  Widget _buildRadarActionCard(
    BuildContext context, {
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isCritical,
    required VoidCallback onTap,
  }) {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.radarUrgentAlert,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: AppTypography.statFigureLarge.copyWith(
              color: isCritical ? color : const Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestPrepCohortsList(BuildContext context) {
    // 5 Default High-Stakes Cohorts representing Dr. Antounios's actual groups
    final defaultCohorts = [
      {
        'title': 'Digital SAT Master (Target 800)',
        'target': 'Digital SAT • August',
        'level': 'SAT Module 1 & 2 Hard',
        'members': '5 Students',
        'score': '740 / 800',
        'focus': 'Desmos Shortcuts + Advanced Quadratics & Circles',
        'color': const Color(0xFF818CF8),
      },
      {
        'title': 'EST I & EST II Intensive',
        'target': 'Egyptian Universities • October EST',
        'level': 'EST Math I & II',
        'members': '5 Students',
        'score': '690 / 800',
        'focus': 'Coordinate Geometry & Exponential Modeling',
        'color': const Color(0xFF2DD4BF),
      },
      {
        'title': 'ACT Math Sprint Drills',
        'target': 'ACT Speed • 45Q in 50M',
        'level': 'Time-Constrained Drills',
        'members': '5 Students',
        'score': '32 / 36',
        'focus': 'Trigonometry & Rapid Problem Solving',
        'color': const Color(0xFFFB7185),
      },
      {
        'title': 'Advanced Math & Problem Solving',
        'target': 'Level 2 • High Scorers',
        'level': 'Algebra & Functions Mastery',
        'members': '5 Students',
        'score': '88% Mastery',
        'focus': 'Nonlinear equations & Systems',
        'color': const Color(0xFFA78BFA),
      },
      {
        'title': 'Basics & Foundations Cohort',
        'target': 'Level 1 • Diagnostic',
        'level': 'Core Foundations',
        'members': '5 Students',
        'score': '82% Mastery',
        'focus': 'Linear Equations, Ratios, & Percentages',
        'color': const Color(0xFFFBBF24),
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: defaultCohorts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
      itemBuilder: (context, i) {
        final cohort = defaultCohorts[i];
        final color = cohort['color'] as Color;

        return AppCard(
          variant: AppCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: LayoutBuilder(
            builder: (context, cardConstraints) {
              final isNarrow = cardConstraints.maxWidth < 450;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNarrow) ...[
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.8)],
                            ),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                          ),
                          child: const Center(
                            child: Text(
                              '∑',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(
                            cohort['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      '${context.l10n.academicFocusLabel}${cohort['focus']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppBadge(
                          label: cohort['target'] as String,
                          variant: AppBadgeVariant.active,
                        ),
                        Text(
                          '${context.l10n.averageScoreLabel}${cohort['score']}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.8)],
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
                                cohort['title'] as String,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${context.l10n.academicFocusLabel}${cohort['focus']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AppBadge(
                              label: cohort['target'] as String,
                              variant: AppBadgeVariant.active,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${context.l10n.averageScoreLabel}${cohort['score']}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
              const SizedBox(height: AppSpacing.s12),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.folder_shared_rounded, size: 14, color: Color(0xFF38BDF8)),
                    label: Text(context.l10n.chipHandoutsPdfs, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFF334155)),
                    onPressed: () => context.push(AppRouter.groupsList),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.assignment_rounded, size: 14, color: Color(0xFFFBBF24)),
                    label: Text(context.l10n.chipDrillHomework, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFF334155)),
                    onPressed: () => context.push(AppRouter.groupsList),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.quiz_rounded, size: 14, color: Color(0xFFA78BFA)),
                    label: Text(context.l10n.chipExamsSimulations, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFF334155)),
                    onPressed: () => context.push(AppRouter.groupsList),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.fact_check_rounded, size: 14, color: Color(0xFF34D399)),
                    label: Text(context.l10n.chipRecordAttendance, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFF334155)),
                    onPressed: () => context.push(AppRouter.teacherAttendance),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  },
);
}
}
