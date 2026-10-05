import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../extensions/localized_context_extension.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// WhatsApp Academic Progress Report Generator
/// Provides single-click natural, conversational reporting for teachers to communicate
/// directly with parents on WhatsApp for online learning without requiring parents to log in.
class WhatsAppReportGenerator {
  WhatsAppReportGenerator._();

  /// Clean & format phone numbers to standard E.164 without '+' or dashes
  /// Handles Arabic-Indic numerals, Egyptian local prefixes (01x -> 201x), etc.
  static String cleanPhoneNumber(String rawPhone) {
    if (rawPhone.trim().isEmpty) return '';

    // Convert Arabic-Indic numerals (٠-٩) to Western (0-9)
    const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    String phone = rawPhone.trim();
    for (int i = 0; i < arabicIndic.length; i++) {
      phone = phone.replaceAll(arabicIndic[i], '$i');
    }

    // Strip non-digits
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    // Egyptian 11-digit mobile: 01xxxxxxxxx -> 201xxxxxxxxx
    if (digits.startsWith('01') && digits.length == 11) {
      return '20${digits.substring(1)}';
    }
    // Egyptian 10-digit without leading 0: 1xxxxxxxxx -> 201xxxxxxxxx
    if (digits.startsWith('1') && digits.length == 10) {
      return '20$digits';
    }
    // Saudi 10-digit mobile: 05xxxxxxxx -> 9665xxxxxxxx
    if (digits.startsWith('05') && digits.length == 10) {
      return '966${digits.substring(1)}';
    }

    return digits;
  }

  /// Launch WhatsApp with phone and message pre-filled
  static Future<bool> launchWhatsApp({
    required String phone,
    required String message,
  }) async {
    final cleanPhone = cleanPhoneNumber(phone);
    if (cleanPhone.isEmpty) return false;

    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(url)) {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Generates natural, warm weekly progress report for online learning
  /// Dynamically omits any metric that was not assigned or has no data
  static String generateNaturalWeeklyReport({
    required String studentName,
    String? groupName,
    double videoWatchRate = 0.0,
    int completedAssignments = 0,
    int totalAssignments = 0,
    int mockExamScore = 0,
    int targetScore = 100,
    int? activeStudyMinutes,
    String? teacherNotes,
    String? teacherName = 'د. أنطونيوس أشرف',
  }) {
    final videoPercent = (videoWatchRate * 100).round();
    final group = (groupName != null && groupName.isNotEmpty) ? ' في $groupName' : '';
    final sender = (teacherName != null && teacherName.isNotEmpty) ? '\n$teacherName' : '';

    final lines = <String>[];

    // 1. Video lectures progress (ONLY if > 0)
    if (videoPercent > 0) {
      if (videoPercent >= 95) {
        lines.add('🎬 شاف كل فيديوهات ومحاضرات الأسبوع ده بالكامل.');
      } else {
        lines.add('🎬 شاف $videoPercent% من شروحات ومحاضرات الأسبوع ده.');
      }
    }

    // 2. Active study minutes (ONLY if > 0)
    if (activeStudyMinutes != null && activeStudyMinutes > 0) {
      if (activeStudyMinutes >= 60) {
        final hours = (activeStudyMinutes / 60).toStringAsFixed(1).replaceAll('.0', '');
        lines.add('⏱️ وقت مذاكرته وتفاعله على المنصة: حوالي $hours ساعة.');
      } else {
        lines.add('⏱️ وقت مذاكرته وتفاعله على المنصة: حوالي $activeStudyMinutes دقيقة.');
      }
    }

    // 3. Homework assignments (ONLY if assigned > 0 or completed > 0)
    if (totalAssignments > 0 || completedAssignments > 0) {
      if (totalAssignments > 0 && completedAssignments >= totalAssignments) {
        lines.add('📝 سلّم كل واجبات وتدريبات الأسبوع ده في موعدها.');
      } else if (totalAssignments > 0) {
        lines.add('📝 سلّم $completedAssignments من أصل $totalAssignments من تدريبات الأسبوع.');
      } else {
        lines.add('📝 أنجز $completedAssignments من التكليفات والتدريبات.');
      }
    }

    // 4. Exam / Quiz score (ONLY if > 0)
    if (mockExamScore > 0) {
      lines.add('🎯 سكور الكويز/الامتحان الأخير: $mockExamScore من $targetScore.');
    }

    final bulletsText = lines.isNotEmpty ? '\n${lines.join('\n')}\n' : '';

    final noteSection = (teacherNotes != null && teacherNotes.trim().isNotEmpty)
        ? '\n💡 ملاحظة:\n${teacherNotes.trim()}\n'
        : '';

    return '''
أهلاً بحضرتك يا فندم 🌸
حبيت أشارك مع حضرتك متابعة سريعة لمذاكرة $studentName خلال الأسبوع ده$group:
$bulletsText$noteSection
ربنا يوفقه دايماً يا رب، ومع حضرتك في أي وقت لو حابب تسأل عن أي تفاصيل 🌸$sender
'''
        .trim();
  }

  /// Generates natural, comprehensive monthly progress report for online learning
  /// Dynamically omits any metric that was not assigned or has no data
  static String generateNaturalMonthlyReport({
    required String studentName,
    String? groupName,
    double videoWatchRate = 0.0,
    int completedAssignments = 0,
    int totalAssignments = 0,
    int mockExamScore = 0,
    int targetScore = 100,
    int? activeStudyMinutes,
    String? teacherNotes,
    String? teacherName = 'د. أنطونيوس أشرف',
  }) {
    final videoPercent = (videoWatchRate * 100).round();
    final group = (groupName != null && groupName.isNotEmpty) ? ' في $groupName' : '';
    final sender = (teacherName != null && teacherName.isNotEmpty) ? '\n$teacherName' : '';

    final lines = <String>[];

    // 1. Video / Lecture monthly progress (ONLY if > 0)
    if (videoPercent > 0) {
      if (videoPercent >= 95) {
        lines.add('📚 أتم بنجاح كل محاضرات وكورسات الشهر ده بالكامل.');
      } else {
        lines.add('📚 نسبة إنجازه للمحاضرات والشروحات الشهر ده: $videoPercent%.');
      }
    }

    // 2. Active study hours (ONLY if > 0)
    if (activeStudyMinutes != null && activeStudyMinutes > 0) {
      final hours = (activeStudyMinutes / 60).toStringAsFixed(1).replaceAll('.0', '');
      lines.add('⏱️ إجمالي ساعات مذاكرته وتفاعله على المنصة: حوالي $hours ساعة.');
    }

    // 3. Homework assignments (ONLY if assigned > 0 or completed > 0)
    if (totalAssignments > 0 || completedAssignments > 0) {
      if (totalAssignments > 0 && completedAssignments >= totalAssignments) {
        lines.add('📝 سلّم كل واجبات الشهر بانتظام والتزام ممتاز ($completedAssignments واجب).');
      } else if (totalAssignments > 0) {
        lines.add('📝 إجمالي الواجبات المُسلّمة: $completedAssignments من أصل $totalAssignments واجب.');
      } else {
        lines.add('📝 أنجز $completedAssignments من الواجبات والتطبيقات.');
      }
    }

    // 4. Exam average score (ONLY if > 0)
    if (mockExamScore > 0) {
      lines.add('🎯 متوسط درجاته في امتحانات وتدريبات الشهر: $mockExamScore من $targetScore.');
    }

    final bulletsText = lines.isNotEmpty ? '\n${lines.join('\n')}\n' : '';

    final noteSection = (teacherNotes != null && teacherNotes.trim().isNotEmpty)
        ? '\n💡 تقييم وتوصية المدرس للشهر القادم:\n${teacherNotes.trim()}\n'
        : '';

    return '''
أهلاً بحضرتك يا فندم 🌸
حبيت أطمن حضرتك على مستوى $studentName وملخص مجهوده معانا خلال الشهر ده$group:
$bulletsText$noteSection
فخورين بالتزامه وماشيين معاه خطوة بخطوة عشان يوصل لأعلى سكور إن شاء الله 🌟$sender
'''
        .trim();
  }

  /// Backwards-compatible weekly academic report generator
  static String generateStudentWeeklyReport({
    required String studentName,
    String? groupName,
    double attendanceRate = 1.0,
    double videoWatchRate = 0.0,
    int completedAssignments = 0,
    int totalAssignments = 0,
    int mockExamScore = 0,
    int targetScore = 100,
    int? activeStudyMinutes,
    String? engagementQualityText,
    String? teacherNotes,
    String? teacherName = 'د. أنطونيوس أشرف',
    String? platformName,
  }) {
    final attendancePercent = (attendanceRate * 100).round();
    final videoPercent = (videoWatchRate * 100).round();
    final actualGroup = groupName ?? 'المجموعة الأكاديمية';
    final notes = teacherNotes?.trim() ??
        'الطالب يظهر التزاماً طيباً وتفاعلاً إيجابياً، ونعمل سوياً على تعزيز سرعة الإنجاز والحل.';

    final engagementLine = activeStudyMinutes != null && activeStudyMinutes > 0
        ? '⏱️ وقت التفاعل والمذاكرة النشط: $activeStudyMinutes دقيقة ${engagementQualityText != null ? '($engagementQualityText)' : ''}\n'
        : '';

    final assignmentsLine = totalAssignments > 0
        ? '📝 تسليمات الواجبات المحلولة: $completedAssignments من أصل $totalAssignments\n'
        : (completedAssignments > 0
            ? '📝 الواجبات المُنجزة: $completedAssignments واجب\n'
            : '');

    final examLine = mockExamScore > 0
        ? '🎯 أداء وتقييم الامتحانات: $mockExamScore / $targetScore\n'
        : '';

    final teacherGreeting = teacherName != null && teacherName.isNotEmpty
        ? 'تحية طيبة من $teacherName'
        : 'تحية طيبة';
    final platformTag = platformName != null && platformName.isNotEmpty
        ? ' ($platformName)'
        : '';

    return '''
السلام عليكم ورحمة الله وبركاته،
ولي أمر الطالب العزيز: $studentName 🌟

$teacherGreeting$platformTag 📐

يسعدنا مشاركتكم التقرير الدوري لمتابعة الأداء الأكاديمي والتفاعل الفعلي في $actualGroup:
━━━━━━━━━━━━━━━━━━━━
📊 نسبة الحضور والالتزام: $attendancePercent%
$engagementLine🎥 نسبة إنجاز المحاضرات: $videoPercent%
$assignmentsLine$examLine━━━━━━━━━━━━━━━━━━━━
💡 ملاحظة وتوصية المدرس:
$notes

مع خالص تمنياتنا بدوام التفوق والتميز.
'''
        .trim();
  }

  /// Generates instant absence notification for parents
  static String generateAbsenceNotice({
    required String studentName,
    String? groupName,
    required String sessionDate,
    String? teacherName,
  }) {
    final group = groupName ?? 'المجموعة';
    final sender = teacherName != null ? ' - $teacherName' : '';

    return '''
السلام عليكم ورحمة الله وبركاته،
ولي أمر الطالب العزيز: $studentName 🌟

نحيط سيادتكم علماً بأن الطالب قد تغيب عن حضور حصة اليوم ($group) بتاريخ: $sessionDate.

⚠️ يرجى متابعة الطالب لمشاهدة تسجيل المحاضرة وحل التكليفات الملحقة لضمان عدم تأخره عن زملائه في المنهج.

شاكرين تعاونكم الدائم وحرصكم المستمر$sender.
'''
        .trim();
  }

  /// Generates instant lecture watch & attendance report for parents
  static String generateLectureWatchNotice({
    required String studentName,
    required String lectureTitle,
    required double watchProgressPercent,
    String? groupName,
    int? watchMinutes,
    int? totalMinutes,
    String? teacherName = 'د. أنطونيوس أشرف',
    String? customNote,
  }) {
    final sender = teacherName != null ? ' - $teacherName' : '';
    final pct = watchProgressPercent.toStringAsFixed(watchProgressPercent < 10 && watchProgressPercent > 0 ? 1 : 0);
    final statusEmoji = watchProgressPercent >= 80
        ? '✅ أتم مشاهدة المحاضرة بالكامل'
        : (watchProgressPercent > 0
            ? '⚠️ مشاهدة جزئية ($pct%)'
            : '❌ لم يبدأ المشاهدة بعد');

    final timeLine = (watchMinutes != null && totalMinutes != null && totalMinutes > 0)
        ? '\n⏱️ مدة المشاهدة: $watchMinutes دقيقة من أصل $totalMinutes دقيقة'
        : '';

    final noteLine = customNote != null && customNote.trim().isNotEmpty
        ? '\n💡 ملاحظة وتوجيه المدرس: $customNote'
        : (watchProgressPercent < 80
            ? '\n⚠️ يرجى متابعة الطالب لاستكمال مشاهدة المحاضرة وحل التكليفات الملحقة بها.'
            : '');

    return '''
السلام عليكم ورحمة الله وبركاته،
ولي أمر الطالب العزيز: $studentName 🌟

نحيط سيادتكم علماً بتقرير متابعة التفاعل والمشاهدة للمحاضرة المسجلة:
🎥 $lectureTitle

• حالة المشاهدة: $statusEmoji$timeLine$noteLine

شاكرين تعاونكم وحرصكم الدائم على تفوق وتميز الطالب$sender.
'''
        .trim();
  }

  /// Generates instant exam result report for parents
  static String generateExamResultReport({
    required String studentName,
    required String examTitle,
    required double score,
    required double maxScore,
    required double percentage,
    String? teacherNotes,
    String? teacherName,
  }) {
    final status = percentage >= 85
        ? 'ممتاز جداً 🌟'
        : (percentage >= 65 ? 'جيد جداً 👍' : 'يحتاج مزيداً من التركيز والمراجعة ⚠️');
    final notes = teacherNotes?.isNotEmpty == true
        ? '\n💡 ملاحظة المدرس: $teacherNotes'
        : '';
    final sender = teacherName != null ? ' - $teacherName' : '';

    return '''
السلام عليكم ورحمة الله وبركاته،
ولي أمر الطالب العزيز: $studentName 🌟

يسرنا إخطاركم بنتيجة الطالب في امتحان:
🎯 $examTitle

• الدرجة المحققة: ${score.toStringAsFixed(1)} من ${maxScore.toStringAsFixed(1)}
• النسبة المئوية: ${percentage.toStringAsFixed(1)}%
• التقييم العام: $status$notes

تمنياتنا للطالب بدوام التفوق والتقدم$sender.
'''
        .trim();
  }

  /// Displays interactive dialog with editable message, preset chips, and direct WhatsApp launch
  static void showReportPreviewDialog(
    BuildContext context, {
    required String studentName,
    required String reportText,
    String? phone,
    String? alternatePhone,
    String? groupName,
    double videoWatchRate = 0.0,
    int completedAssignments = 0,
    int totalAssignments = 0,
    int mockExamScore = 0,
    int targetScore = 100,
    int? activeStudyMinutes,
    String? teacherName = 'د. أنطونيوس أشرف',
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _WhatsAppInteractiveDialog(
        studentName: studentName,
        initialReportText: reportText,
        phone: phone,
        alternatePhone: alternatePhone,
        groupName: groupName,
        videoWatchRate: videoWatchRate,
        completedAssignments: completedAssignments,
        totalAssignments: totalAssignments,
        mockExamScore: mockExamScore,
        targetScore: targetScore,
        activeStudyMinutes: activeStudyMinutes,
        teacherName: teacherName,
      ),
    );
  }
}

class _WhatsAppInteractiveDialog extends StatefulWidget {
  final String studentName;
  final String initialReportText;
  final String? phone;
  final String? alternatePhone;
  final String? groupName;
  final double videoWatchRate;
  final int completedAssignments;
  final int totalAssignments;
  final int mockExamScore;
  final int targetScore;
  final int? activeStudyMinutes;
  final String? teacherName;

  const _WhatsAppInteractiveDialog({
    required this.studentName,
    required this.initialReportText,
    this.phone,
    this.alternatePhone,
    this.groupName,
    this.videoWatchRate = 0.0,
    this.completedAssignments = 0,
    this.totalAssignments = 0,
    this.mockExamScore = 0,
    this.targetScore = 100,
    this.activeStudyMinutes,
    this.teacherName,
  });

  @override
  State<_WhatsAppInteractiveDialog> createState() =>
      _WhatsAppInteractiveDialogState();
}

class _WhatsAppInteractiveDialogState
    extends State<_WhatsAppInteractiveDialog> {
  late final TextEditingController _textController;
  late String _selectedPhone;
  bool _isMonthly = false;
  String _currentCustomNote = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.initialReportText.trim().isNotEmpty
          ? widget.initialReportText
          : _generateActiveReport(),
    );
    _selectedPhone = (widget.phone != null && widget.phone!.trim().isNotEmpty)
        ? widget.phone!.trim()
        : (widget.alternatePhone?.trim() ?? '');
  }

  String _generateActiveReport() {
    if (_isMonthly) {
      return WhatsAppReportGenerator.generateNaturalMonthlyReport(
        studentName: widget.studentName,
        groupName: widget.groupName,
        videoWatchRate: widget.videoWatchRate,
        completedAssignments: widget.completedAssignments,
        totalAssignments: widget.totalAssignments,
        mockExamScore: widget.mockExamScore,
        targetScore: widget.targetScore,
        activeStudyMinutes: widget.activeStudyMinutes,
        teacherNotes: _currentCustomNote,
        teacherName: widget.teacherName,
      );
    }
    return WhatsAppReportGenerator.generateNaturalWeeklyReport(
      studentName: widget.studentName,
      groupName: widget.groupName,
      videoWatchRate: widget.videoWatchRate,
      completedAssignments: widget.completedAssignments,
      totalAssignments: widget.totalAssignments,
      mockExamScore: widget.mockExamScore,
      targetScore: widget.targetScore,
      activeStudyMinutes: widget.activeStudyMinutes,
      teacherNotes: _currentCustomNote,
      teacherName: widget.teacherName,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _switchPeriod(bool isMonthly) {
    if (_isMonthly == isMonthly) return;
    setState(() {
      _isMonthly = isMonthly;
      _textController.text = _generateActiveReport();
    });
  }

  void _applyPresetNote(String preset) {
    setState(() {
      _currentCustomNote = preset;
      _textController.text = _generateActiveReport();
    });
  }

  Future<void> _handleSendWhatsApp() async {
    final l10n = context.l10n;
    if (_selectedPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.whatsappParentPhoneMissing),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    final text = _textController.text.trim();
    final launched = await WhatsAppReportGenerator.launchWhatsApp(
      phone: _selectedPhone,
      message: text,
    );
    if (!mounted) return;
    setState(() => _isSending = false);

    if (launched) {
      Navigator.of(context).pop();
    } else {
      // Fallback copy to clipboard if launch fails
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.whatsappOpenError),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleCopy() {
    final text = _textController.text.trim();
    Clipboard.setData(ClipboardData(text: text));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.whatsappCopiedSuccess(widget.studentName)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasParentPhone =
        widget.phone != null && widget.phone!.trim().isNotEmpty;
    final hasAltPhone = widget.alternatePhone != null &&
        widget.alternatePhone!.trim().isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s20,
        AppSpacing.s20,
        AppSpacing.s8,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s8,
      ),
      title: Row(
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
                  l10n.whatsappReportDialogTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  widget.studentName,
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
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period Toggle: Weekly vs Monthly
              Row(
                children: [
                  ChoiceChip(
                    avatar: Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: !_isMonthly ? Colors.white : AppColors.primary,
                    ),
                    label: Text(l10n.whatsappPeriodWeekly),
                    selected: !_isMonthly,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: !_isMonthly ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) _switchPeriod(false);
                    },
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  ChoiceChip(
                    avatar: Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: _isMonthly ? Colors.white : AppColors.primary,
                    ),
                    label: Text(l10n.whatsappPeriodMonthly),
                    selected: _isMonthly,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _isMonthly ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) _switchPeriod(true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // Target Phone Selector if both exist
              if (hasParentPhone && hasAltPhone) ...[
                Text(
                  l10n.whatsappTargetPhoneLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(
                        '${l10n.whatsappTargetParent} (${widget.phone})',
                      ),
                      selected: _selectedPhone == widget.phone!.trim(),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPhone = widget.phone!.trim());
                        }
                      },
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    ChoiceChip(
                      label: Text(
                        '${l10n.whatsappTargetStudent} (${widget.alternatePhone})',
                      ),
                      selected: _selectedPhone == widget.alternatePhone!.trim(),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPhone =
                              widget.alternatePhone!.trim());
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
              ] else if (_selectedPhone.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.phone_iphone_rounded,
                      size: 14,
                      color: Color(0xFF25D366),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${l10n.whatsappTargetPhoneLabel}: $_selectedPhone',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          l10n.whatsappParentPhoneMissing,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
              ],

              // Quick Friendly Presets
              Text(
                l10n.whatsappTeacherNotesLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              Wrap(
                spacing: AppSpacing.s6,
                runSpacing: AppSpacing.s6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.star_rounded,
                        size: 14, color: Color(0xFFF59E0B)),
                    label: Text(l10n.whatsappPresetFriendlyKeepUp,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () =>
                        _applyPresetNote(l10n.whatsappPresetFriendlyKeepUp),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.fitness_center_rounded,
                        size: 14, color: AppColors.primary),
                    label: Text(l10n.whatsappPresetFriendlyNeedsFocus,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () =>
                        _applyPresetNote(l10n.whatsappPresetFriendlyNeedsFocus),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.play_circle_outline_rounded,
                        size: 14, color: AppColors.info),
                    label: Text(l10n.whatsappPresetFriendlyCatchUp,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () =>
                        _applyPresetNote(l10n.whatsappPresetFriendlyCatchUp),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // Editable Message Area
              TextField(
                controller: _textController,
                maxLines: 10,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.all(AppSpacing.s12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s8,
        AppSpacing.s20,
        AppSpacing.s16,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(l10n.whatsappCopyButton),
          onPressed: _handleCopy,
        ),
        ElevatedButton.icon(
          icon: _isSending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(l10n.whatsappSendButton),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSending ? null : _handleSendWhatsApp,
        ),
      ],
    );
  }
}
