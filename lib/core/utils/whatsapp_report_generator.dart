import 'package:url_launcher/url_launcher.dart';
import '../../features/students/domain/entities/student_academic_report_entity.dart';

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
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    // Strip leading international 00
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

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
    // Kuwait 8-digit mobile (starts with 5, 6, 9): xxxxxxxx -> 965xxxxxxxx
    if (digits.length == 8 && (digits.startsWith('5') || digits.startsWith('6') || digits.startsWith('9'))) {
      return '965$digits';
    }
    // Kuwait 9-digit with leading 0: 0[569]xxxxxxx -> 965[569]xxxxxxx
    if (digits.length == 9 && digits.startsWith('0') && (digits[1] == '5' || digits[1] == '6' || digits[1] == '9')) {
      return '965${digits.substring(1)}';
    }
    // Kuwait already with country code (965 + 8 digits = 11 digits)
    if (digits.startsWith('965') && digits.length == 11) {
      return digits;
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

  /// Generates instant overall student engagement and progress notice for parents
  static String generateOverallEngagementNotice({
    required String studentName,
    required String groupName,
    required int completedLectures,
    required int totalLectures,
    required double completionPercentage,
    String? teacherName = 'د. أنطونيوس أشرف',
    String? customNote,
  }) {
    final sender = teacherName != null ? ' - $teacherName' : '';
    final pct = completionPercentage.toStringAsFixed(0);
    final statusText = completionPercentage >= 80
        ? '🌟 مستوى التزام ممتاز ومثالي'
        : (completionPercentage >= 50
            ? '⚡ مستوى التزام متوسط ومستمر'
            : '⚠️ يحتاج إلى تكثيف المتابعة وسرعة استدراك المحاضرات');

    final noteLine = customNote != null && customNote.trim().isNotEmpty
        ? '\n💡 ملاحظة وتوجيه المدرس: $customNote'
        : '';

    return '''
السلام عليكم ورحمة الله وبركاته،
ولي أمر الطالب العزيز: $studentName 🌟

نشارككم التقرير الشامل لمدى التزام وإنجاز الطالب في مجموعة ($groupName):

📊 التقييم العام: $statusText
🎬 إنجاز المحاضرات: تم إتمام $completedLectures من أصل $totalLectures محاضرات بنسبة إنجاز ($pct%).$noteLine

شاكرين تعاونكم وحرصكم المستمر على تفوق الطالب$sender.
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
    String? groupName,
    String? teacherNotes,
    String? teacherName,
    bool isNotTaken = false,
  }) {
    final sender = (teacherName != null && teacherName.trim().isNotEmpty)
        ? '\n- $teacherName 📐'
        : '';
    final groupSuffix = (groupName != null && groupName.trim().isNotEmpty)
        ? ' ($groupName)'
        : '';

    if (isNotTaken) {
      final note = (teacherNotes != null && teacherNotes.trim().isNotEmpty)
          ? '\n💡 توجيه المدرس: $teacherNotes'
          : '';
      return '''
السلام عليكم ورحمة الله وبركاته،
ولي أمر الطالب العزيز: $studentName 🌟

إحاطة هامة بشأن اختبار:
🎯 $examTitle$groupSuffix
━━━━━━━━━━━━━━━━━━━━
⚠️ نود إحاطتكم بأن الطالب لم يؤدِ الاختبار حتى الآن.
⏳ يرجى التنبيه على الطالب بضرورة الدخول إلى المنصة وأداء الاختبار في أقرب وقت لتثبيت المستوى.$note
━━━━━━━━━━━━━━━━━━━━
شاكرين ومقدرين حسن تعاونكم وحرصكم الدائم.$sender
'''
          .trim();
    }

    final status = percentage >= 85
        ? 'ممتاز جداً 🌟'
        : (percentage >= 65 ? 'جيد جداً 👍' : 'يحتاج مزيداً من التركيز والمراجعة ⚠️');
    final notes = (teacherNotes != null && teacherNotes.trim().isNotEmpty)
        ? '\n💡 ملاحظة المدرس: $teacherNotes'
        : '';

    // Format scores cleanly (no .0 if whole integer)
    final formattedScore = score % 1 == 0 ? score.toInt().toString() : score.toStringAsFixed(1);
    final formattedMax = maxScore % 1 == 0 ? maxScore.toInt().toString() : maxScore.toStringAsFixed(1);
    final formattedPct = percentage % 1 == 0 ? percentage.toInt().toString() : percentage.toStringAsFixed(1);

    return '''
السلام عليكم ورحمة الله وبركاته،
ولي أمر الطالب العزيز: $studentName 🌟

يسرنا إخطاركم بنتيجة الطالب في اختبار:
🎯 $examTitle$groupSuffix
━━━━━━━━━━━━━━━━━━━━
• الدرجة المحققة: $formattedScore من $formattedMax
• النسبة المئوية: $formattedPct%
• التقييم العام: $status$notes
━━━━━━━━━━━━━━━━━━━━
تمنياتنا للطالب بدوام التفوق والتقدم والريادة.$sender
'''
        .trim();
  }

  /// Generates report for a specific attempt of an exam
  static String generateSingleAttemptReport({
    required String studentName,
    required String examTitle,
    required int attemptNumber,
    int? totalAttempts,
    required double score,
    required double maxScore,
    required double percentage,
    String? groupName,
    String? teacherNotes,
    String? teacherName,
    DateTime? submittedAt,
  }) {
    final sender = (teacherName != null && teacherName.trim().isNotEmpty)
        ? '\n- $teacherName 📐'
        : '';
    final groupSuffix = (groupName != null && groupName.trim().isNotEmpty)
        ? ' ($groupName)'
        : '';
    final attemptLabel = (totalAttempts != null && totalAttempts > 1)
        ? ' (المحاولة $attemptNumber من أصل $totalAttempts)'
        : (attemptNumber > 1 ? ' (المحاولة $attemptNumber)' : '');

    final status = percentage >= 85
        ? 'ممتاز جداً 🌟'
        : (percentage >= 65 ? 'جيد جداً 👍' : 'يحتاج مزيداً من التركيز والمراجعة ⚠️');
    final notes = (teacherNotes != null && teacherNotes.trim().isNotEmpty)
        ? '\n💡 ملاحظة المدرس:\n$teacherNotes'
        : '';

    final formattedScore = score % 1 == 0 ? score.toInt().toString() : score.toStringAsFixed(1);
    final formattedMax = maxScore % 1 == 0 ? maxScore.toInt().toString() : maxScore.toStringAsFixed(1);
    final formattedPct = percentage % 1 == 0 ? percentage.toInt().toString() : percentage.toStringAsFixed(1);

    return '''
السلام عليكم ورحمة الله وبركاته،
ولي أمر الطالب العزيز: $studentName 🌟

يسرنا مشاركتكم نتيجة الطالب في اختبار:
🎯 $examTitle$groupSuffix$attemptLabel
━━━━━━━━━━━━━━━━━━━━
• الدرجة المحققة: $formattedScore من $formattedMax
• النسبة المئوية: $formattedPct%
• التقييم العام: $status$notes
━━━━━━━━━━━━━━━━━━━━
تمنياتنا للطالب بدوام التفوق والتميز والريادة.$sender
'''
        .trim();
  }

  /// Generates a comprehensive progression report covering all attempts for an exam
  static String generateAllAttemptsProgressionReport({
    required String studentName,
    required String examTitle,
    String? groupName,
    required List<Map<String, dynamic>> attemptsSummary,
    required double bestScore,
    required double maxScore,
    required double bestPercentage,
    double? scoreImprovement,
    String? teacherNotes,
    String? teacherName,
  }) {
    final sender = (teacherName != null && teacherName.trim().isNotEmpty)
        ? '\n- $teacherName 📐'
        : '';
    final groupSuffix = (groupName != null && groupName.trim().isNotEmpty)
        ? ' ($groupName)'
        : '';

    final attemptsLines = StringBuffer();
    for (int i = 0; i < attemptsSummary.length; i++) {
      final att = attemptsSummary[i];
      final num = att['attempt_number'] ?? (i + 1);
      final sc = att['score'];
      final mx = att['max_score'] ?? maxScore;
      final pct = att['percentage'];
      final isBest = att['is_best'] == true;
      final badge = isBest ? ' ⭐ (الأفضل)' : '';
      attemptsLines.writeln('• المحاولة $num: $sc من $mx ($pct%)$badge');
    }

    final improvementLine = (scoreImprovement != null && scoreImprovement > 0)
        ? '\n📈 نسبة التطور والتحسن: +${scoreImprovement % 1 == 0 ? scoreImprovement.toInt() : scoreImprovement.toStringAsFixed(1)}%'
        : '';

    final notes = (teacherNotes != null && teacherNotes.trim().isNotEmpty)
        ? '\n💡 ملاحظة وتوجيه المدرس:\n$teacherNotes'
        : '';

    final formattedBest = bestScore % 1 == 0 ? bestScore.toInt().toString() : bestScore.toStringAsFixed(1);
    final formattedMax = maxScore % 1 == 0 ? maxScore.toInt().toString() : maxScore.toStringAsFixed(1);
    final formattedBestPct = bestPercentage % 1 == 0 ? bestPercentage.toInt().toString() : bestPercentage.toStringAsFixed(1);

    return '''
السلام عليكم ورحمة الله وبركاته،
ولي أمر الطالب العزيز: $studentName 🌟

نشارككم تقرير مسار التعلم ومحاولات الطالب في اختبار:
🎯 $examTitle$groupSuffix
━━━━━━━━━━━━━━━━━━━━
📊 سجل كافة المحاولات:
${attemptsLines.toString().trim()}$improvementLine

🌟 النتيجة المعتمدة: $formattedBest من $formattedMax ($formattedBestPct%)$notes
━━━━━━━━━━━━━━━━━━━━
فخورين بسعي واجتهاد الطالب ونتمنى له دوام التفوق.$sender
'''
        .trim();
  }



  /// Generates concise, factual, data-dense academic report for parents without fluff or generalizations.
  static String generateFactualAcademicReport({
    required StudentAcademicReportEntity report,
    required String periodLabel,
    required String academicDecision,
    String? teacherName = 'د. أنطونيوس أشرف',
    String? platformName,
  }) {
    final buffer = StringBuffer();
    final group = (report.groupNames != null && report.groupNames!.trim().isNotEmpty)
        ? ' | المجموعة: ${report.groupNames!.trim()}'
        : '';

    buffer.writeln('📋 تقرير متابعة الأداء الأكاديمي');
    buffer.writeln('الطالب: ${report.studentName}$group');
    buffer.writeln('⏱️ الفترة: $periodLabel');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');

    bool hasAnyData = false;

    // 1. Lectures / Videos
    if (report.totalAssignedVideos > 0 || report.videosWatched > 0) {
      hasAnyData = true;
      if (report.totalAssignedVideos > 0) {
        if (report.videosWatched >= report.totalAssignedVideos &&
            report.videosCompleted >= report.totalAssignedVideos) {
          buffer.writeln(
            '• المحاضرات: إتمام كامل لكافة محاضرات الفترة (${report.videosWatched} من ${report.totalAssignedVideos}) ✅',
          );
        } else {
          buffer.writeln(
            '• المحاضرات: أنجز ${report.videosWatched} من أصل ${report.totalAssignedVideos} محاضرات (${report.avgVideoPercentage.round()}%)',
          );
        }
      } else {
        buffer.writeln(
          '• المحاضرات: أتم مشاهدة ${report.videosWatched} محاضرات (${report.avgVideoPercentage.round()}%)',
        );
      }
    }

    // 2. Assignments
    if (report.totalAssignedAssignments > 0 || report.assignmentsSubmitted > 0) {
      hasAnyData = true;
      final missing = report.totalAssignedAssignments > report.assignmentsSubmitted
          ? report.totalAssignedAssignments - report.assignmentsSubmitted
          : 0;
      if (report.totalAssignedAssignments > 0) {
        if (missing == 0) {
          buffer.writeln(
            '• التدريبات: تسليم كافة الواجبات المقررة (${report.assignmentsSubmitted} من ${report.totalAssignedAssignments}) بانتظام ✅',
          );
        } else {
          buffer.writeln(
            '• التدريبات: سلّم ${report.assignmentsSubmitted} من أصل ${report.totalAssignedAssignments} واجبات (يوجد $missing واجب متأخر ⚠️)',
          );
        }
      } else {
        buffer.writeln(
          '• التدريبات: سلّم ${report.assignmentsSubmitted} واجبات وتطبيقات عملية',
        );
      }
    }

    // 3. Exams & Quizzes
    if (report.examsSubmitted > 0) {
      hasAnyData = true;
      final latest = (report.latestExamTitle != null &&
              report.latestExamScore != null &&
              report.latestExamMaxScore != null)
          ? ' | آخر اختبار: ${report.latestExamTitle} (${report.latestExamScore}/${report.latestExamMaxScore})'
          : '';
      buffer.writeln(
        '• الاختبارات: أدى ${report.examsSubmitted} تقييمات بمعدل ${report.avgExamPercentage.round()}%$latest',
      );
    }

    // 4. Active Study Time
    if (report.activeStudyMinutes > 0) {
      hasAnyData = true;
      if (report.activeStudyMinutes >= 60) {
        final hours = (report.activeStudyMinutes / 60)
            .toStringAsFixed(1)
            .replaceAll('.0', '');
        buffer.writeln('• وقت المذاكرة والتطبيق: حوالي $hours ساعة على المنصة');
      } else {
        buffer.writeln(
          '• وقت المذاكرة والتطبيق: حوالي ${report.activeStudyMinutes} دقيقة على المنصة',
        );
      }
    }

    // 5. Attendance
    if (report.totalSessions > 0) {
      hasAnyData = true;
      if (report.absentSessions > 0) {
        buffer.writeln(
          '• الحضور: حضر ${report.attendedSessions} من ${report.totalSessions} حصص (غياب ${report.absentSessions} حصة ⚠️)',
        );
      } else {
        buffer.writeln(
          '• الحضور: التزام كامل بالحضور (${report.attendedSessions} من ${report.totalSessions} حصص) ✅',
        );
      }
    }

    if (!hasAnyData) {
      buffer.writeln('• لا توجد أنشطة أو تسليمات مسجلة للطالب خلال هذه الفترة.');
    }

    // 6. Academic Directive / Decision
    if (academicDecision.trim().isNotEmpty) {
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('📌 التقييم والتوجيه الأكاديمي:');
      buffer.writeln(academicDecision.trim());
    }

    // Footer
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    if (teacherName != null && teacherName.isNotEmpty) {
      buffer.write(teacherName);
    }
    if (platformName != null && platformName.isNotEmpty) {
      buffer.write(' - $platformName');
    }

    return buffer.toString().trim();
  }

  /// Displays interactive dialog with period filters, live fetched telemetry, and custom decisions
  /// Displays interactive dialog with editable message, preset chips, and direct WhatsApp launch
}

