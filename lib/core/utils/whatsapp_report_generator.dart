import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// مولّد تقارير المتابعة الأكاديمية عبر الواتساب بنقرة واحدة
/// مخصص لمنصة د. أنطونيوس أشرف لتمكينه من إرسال تقارير مهنية فورية لأولياء الأمور
class WhatsAppReportGenerator {
  WhatsAppReportGenerator._();

  /// توليد نص رسالة الواتساب الأسبوعية
  static String generateStudentWeeklyReport({
    required String studentName,
    String? groupName,
    double attendanceRate = 1.0,
    double videoWatchRate = 0.95,
    int completedAssignments = 4,
    int totalAssignments = 4,
    int mockExamScore = 740,
    int targetScore = 800,
    int? activeStudyMinutes,
    String? engagementQualityText,
    String? teacherNotes,
    String teacherName = 'د. أنطونيوس أشرف',
    String platformName = 'منصة د. أنطونيوس أشرف للرياضيات الأمريكية',
  }) {
    final attendancePercent = (attendanceRate * 100).round();
    final videoPercent = (videoWatchRate * 100).round();
    final actualGroup = groupName ?? 'مجموعة تدريب الـ Digital SAT (Target 800)';
    final notes = teacherNotes ??
        'الطالب يظهر التزاماً ممتازاً وسرعة استيعاب عالية في مهارات الجبر وحل المعادلات، ونعمل حالياً على رفع سرعة الحل في مسائل الـ Coordinate Geometry.';

    final engagementLine = activeStudyMinutes != null && activeStudyMinutes > 0
        ? '⏱️ وقت التفاعل والمذاكرة النشط: $activeStudyMinutes دقيقة ${engagementQualityText != null ? '($engagementQualityText)' : ''}\n'
        : '';

    return '''
السلام عليكم ورحمة الله وبركاته،
ولي أمر الطالب العزيز: $studentName 🌟

تحية طيبة من $teacherName ($platformName) 📐

يسعدنا مشاركتكم التقرير الدوري لمتابعة الأداء الأكاديمي والتفاعل الفعلي للطالب في $actualGroup:
━━━━━━━━━━━━━━━━━━━━
📊 نسبة الحضور والالتزام: $attendancePercent%
$engagementLine🎥 نسبة مشاهدة المحاضرات المسجلة: $videoPercent%
📝 واجبات الـ Drills المحلولة: $completedAssignments من أصل $totalAssignments
🎯 سكور المحاكاة الأخير (SAT Math): $mockExamScore / $targetScore
━━━━━━━━━━━━━━━━━━━━
💡 ملاحظة وتوصية $teacherName:
$notes

مع تمنياتنا بدوام التميز والتفوق لطلابنا الأعزاء،
$teacherName
'''.trim();
  }

  /// عرض شاشة معاينة التقرير مع إمكانية النسخ أو الفتح المباشر
  static void showReportPreviewDialog(
    BuildContext context, {
    required String studentName,
    required String reportText,
    String? phone,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.mark_chat_read_rounded,
                color: Color(0xFF25D366), // WhatsApp Green
                size: 24,
              ),
              SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'تقرير الواتساب لولي الأمر',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تم إنشاء تقرير المتابعة تلقائياً بصيغة مخصصة لرسائل الواتساب:',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SelectableText(
                      reportText,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.textPrimary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إغلاق'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('نسخ التقرير للحافظة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: reportText));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم نسخ تقرير الطالب $studentName بنجاح! جاهز للإرسال على الواتساب 📋',
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
