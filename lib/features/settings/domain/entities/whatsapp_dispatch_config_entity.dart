import 'package:equatable/equatable.dart';

enum WhatsAppRecipientTarget {
  parentOnly,
  studentOnly,
  both;

  String toDbValue() {
    switch (this) {
      case WhatsAppRecipientTarget.parentOnly:
        return 'parent_only';
      case WhatsAppRecipientTarget.studentOnly:
        return 'student_only';
      case WhatsAppRecipientTarget.both:
        return 'both';
    }
  }

  static WhatsAppRecipientTarget fromDbValue(String? val) {
    switch (val) {
      case 'student_only':
        return WhatsAppRecipientTarget.studentOnly;
      case 'both':
        return WhatsAppRecipientTarget.both;
      case 'parent_only':
      default:
        return WhatsAppRecipientTarget.parentOnly;
    }
  }
}

enum WhatsAppDispatchTiming {
  instant,
  examEnd;

  String toDbValue() {
    switch (this) {
      case WhatsAppDispatchTiming.instant:
        return 'instant';
      case WhatsAppDispatchTiming.examEnd:
        return 'exam_end';
    }
  }

  static WhatsAppDispatchTiming fromDbValue(String? val) {
    switch (val) {
      case 'exam_end':
        return WhatsAppDispatchTiming.examEnd;
      case 'instant':
      default:
        return WhatsAppDispatchTiming.instant;
    }
  }
}

class WhatsAppDispatchConfigEntity extends Equatable {
  final WhatsAppRecipientTarget recipientTarget;
  final WhatsAppDispatchTiming dispatchTiming;
  final String headerTemplate;
  final String bodyTemplate;
  final String footerTemplate;
  final String tierExcellentText;
  final String tierGoodText;
  final String tierPassText;
  final String tierNeedsImprovementText;

  const WhatsAppDispatchConfigEntity({
    this.recipientTarget = WhatsAppRecipientTarget.parentOnly,
    this.dispatchTiming = WhatsAppDispatchTiming.instant,
    this.headerTemplate =
        'أهلاً بحضرتك يا فندم 🌸\nحبينا نطمن حضرتك على نتيجة اختبار نجلك الطالب/ {student_name} ({group_name}):',
    this.bodyTemplate =
        '📝 الاختبار: {exam_title}\n🎯 الدرجة: {score} من {max_score} ({percentage}%)\n\n{evaluation_text}',
    this.footerTemplate =
        'نسأل الله له دوام التوفيق والتميز، ومع حضرتك في أي وقت لأي استفسار 🌸\n{teacher_name}',
    this.tierExcellentText =
        '🌟 أداء ممتاز ومستوى استثنائي مشرف، نسأل الله له دوام التوفيق والتفوق!',
    this.tierGoodText =
        '👏 مستوى جيد جداً واجتهاد واضح، مستمرون في المتابعة للوصول للدرجة النهائية.',
    this.tierPassText =
        '👍 أداء لا بأس به، تم اجتياز الاختبار ونعمل سوياً على تعزيز النقاط التي تحتاج مراجعة.',
    this.tierNeedsImprovementText =
        '💡 الدرجة تحتاج مزيداً من الاهتمام والمراجعة الدقيقة لأسئلة الامتحان، وتم توجيه الطالب لمراجعة الأخطاء.',
  });

  static const defaultConfiguration = WhatsAppDispatchConfigEntity();

  WhatsAppDispatchConfigEntity copyWith({
    WhatsAppRecipientTarget? recipientTarget,
    WhatsAppDispatchTiming? dispatchTiming,
    String? headerTemplate,
    String? bodyTemplate,
    String? footerTemplate,
    String? tierExcellentText,
    String? tierGoodText,
    String? tierPassText,
    String? tierNeedsImprovementText,
  }) {
    return WhatsAppDispatchConfigEntity(
      recipientTarget: recipientTarget ?? this.recipientTarget,
      dispatchTiming: dispatchTiming ?? this.dispatchTiming,
      headerTemplate: headerTemplate ?? this.headerTemplate,
      bodyTemplate: bodyTemplate ?? this.bodyTemplate,
      footerTemplate: footerTemplate ?? this.footerTemplate,
      tierExcellentText: tierExcellentText ?? this.tierExcellentText,
      tierGoodText: tierGoodText ?? this.tierGoodText,
      tierPassText: tierPassText ?? this.tierPassText,
      tierNeedsImprovementText:
          tierNeedsImprovementText ?? this.tierNeedsImprovementText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipient_target': recipientTarget.toDbValue(),
      'dispatch_timing': dispatchTiming.toDbValue(),
      'header_template': headerTemplate,
      'body_template': bodyTemplate,
      'footer_template': footerTemplate,
      'tier_excellent_text': tierExcellentText,
      'tier_good_text': tierGoodText,
      'tier_pass_text': tierPassText,
      'tier_needs_improvement_text': tierNeedsImprovementText,
    };
  }

  factory WhatsAppDispatchConfigEntity.fromJson(Map<String, dynamic> json) {
    return WhatsAppDispatchConfigEntity(
      recipientTarget: WhatsAppRecipientTarget.fromDbValue(
          json['recipient_target']?.toString()),
      dispatchTiming: WhatsAppDispatchTiming.fromDbValue(
          json['dispatch_timing']?.toString()),
      headerTemplate: json['header_template']?.toString() ??
          defaultConfiguration.headerTemplate,
      bodyTemplate: json['body_template']?.toString() ??
          defaultConfiguration.bodyTemplate,
      footerTemplate: json['footer_template']?.toString() ??
          defaultConfiguration.footerTemplate,
      tierExcellentText: json['tier_excellent_text']?.toString() ??
          defaultConfiguration.tierExcellentText,
      tierGoodText: json['tier_good_text']?.toString() ??
          defaultConfiguration.tierGoodText,
      tierPassText: json['tier_pass_text']?.toString() ??
          defaultConfiguration.tierPassText,
      tierNeedsImprovementText:
          json['tier_needs_improvement_text']?.toString() ??
              defaultConfiguration.tierNeedsImprovementText,
    );
  }

  String renderLivePreview({
    String studentName = 'عمر أحمد',
    String examTitle = 'الاحتمالات والتوافيق (Advanced)',
    int score = 48,
    int maxScore = 50,
    double percentage = 96.0,
    String groupName = 'SAT Basics & Algebra Bootcamp',
    String teacherName = 'د. أنطونيوس أشرف',
  }) {
    String eval;
    if (percentage >= 90) {
      eval = tierExcellentText;
    } else if (percentage >= 75) {
      eval = tierGoodText;
    } else if (percentage >= 60) {
      eval = tierPassText;
    } else {
      eval = tierNeedsImprovementText;
    }

    final fullMessage =
        '$headerTemplate\n\n$bodyTemplate\n\n$footerTemplate';

    return fullMessage
        .replaceAll('{student_name}', studentName)
        .replaceAll('{exam_title}', examTitle)
        .replaceAll('{score}', '$score')
        .replaceAll('{max_score}', '$maxScore')
        .replaceAll('{percentage}', percentage.toStringAsFixed(1))
        .replaceAll('{group_name}', groupName)
        .replaceAll('{teacher_name}', teacherName)
        .replaceAll('{evaluation_text}', eval);
  }

  @override
  List<Object?> get props => [
        recipientTarget,
        dispatchTiming,
        headerTemplate,
        bodyTemplate,
        footerTemplate,
        tierExcellentText,
        tierGoodText,
        tierPassText,
        tierNeedsImprovementText,
      ];
}
