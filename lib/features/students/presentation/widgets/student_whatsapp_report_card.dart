import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/whatsapp_interactive_dialog.dart';
import '../../../../core/utils/whatsapp_report_generator.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/student_entity.dart';
import '../../domain/entities/student_360_entity.dart';

/// WhatsApp Parent Progress Report generation and sharing card.
class StudentWhatsAppReportCard extends StatelessWidget {
  final StudentEntity student;
  final Student360Entity stats;

  const StudentWhatsAppReportCard({
    super.key,
    required this.student,
    required this.stats,
  });

  void _openWhatsAppReport(BuildContext context) {
    final isSatGroup = stats.groups.any((g) =>
        g.groupName.toUpperCase().contains('SAT') ||
        g.groupLevel.toUpperCase().contains('SAT'));
    final targetScore = isSatGroup ? 800 : 100;
    final examScore = stats.examAverage > 0
        ? (isSatGroup
            ? (stats.examAverage * 8).round()
            : stats.examAverage.round())
        : 0;
    final groupName = stats.groups.isNotEmpty
        ? stats.groups.first.groupName
        : null;
    final videoRate = (stats.videoCompletionPercentage / 100).clamp(0.0, 1.0);

    final report = WhatsAppReportGenerator.generateNaturalWeeklyReport(
      studentName: student.fullName,
      groupName: groupName,
      videoWatchRate: videoRate,
      completedAssignments: stats.assignmentsSubmitted,
      totalAssignments: stats.assignmentsSubmitted,
      mockExamScore: examScore,
      targetScore: targetScore,
      activeStudyMinutes: stats.todayActiveMinutes,
    );

    WhatsAppInteractiveDialog.show(
      context,
      studentName: student.fullName,
      reportText: report,
      phone: student.parentPhone,
      alternatePhone: student.phone,
      groupName: groupName,
      videoWatchRate: videoRate,
      completedAssignments: stats.assignmentsSubmitted,
      totalAssignments: stats.assignmentsSubmitted,
      mockExamScore: examScore,
      targetScore: targetScore,
      activeStudyMinutes: stats.todayActiveMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 460;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_chat_read_rounded,
                        color: Color(0xFF25D366),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        context.l10n.whatsappParentReportTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  context.l10n.whatsappParentReportSubtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.share_rounded,
                      size: 16,
                    ),
                    label: Text(
                      context.l10n.createAndShareReport,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                    ),
                    onPressed: () => _openWhatsAppReport(context),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_chat_read_rounded,
                  color: Color(0xFF25D366),
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.whatsappParentReportTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      context.l10n.whatsappParentReportSubtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 16),
                label: Text(context.l10n.createReport),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusSmall,
                    ),
                  ),
                ),
                onPressed: () => _openWhatsAppReport(context),
              ),
            ],
          );
        },
      ),
    );
  }
}
