import '../../../../core/di/injection_container.dart';
import '../../../../core/utils/app_logger.dart';
import '../entities/notification_entity.dart';

/// Central domain service to dispatch automatic event-driven notifications
/// to students and parents across the application without coupling UI logic.
class NotificationDispatcher {
  const NotificationDispatcher._();

  /// 1. Notify students when a new lecture / video / lesson is published
  static Future<void> notifyNewLecture({
    required String title,
    required String groupId,
    required String contentId,
    String? contentType,
  }) async {
    try {
      final notifRepo = InjectionContainer.notificationsRepository;
      await notifRepo.dispatchNotification(
        title: 'محاضرة جديدة: $title',
        body: 'تمت إضافة محاضرة جديدة "$title" إلى مادتك الدراسية. يمكنك الآن مشاهدة الشرح وحل التدريبات.',
        type: NotificationType.newContent,
        groupId: groupId,
        data: {
          'content_id': contentId,
          'group_id': groupId,
          'content_type': contentType ?? 'lesson',
        },
      );
    } catch (e, st) {
      AppLogger.e('NotificationDispatcher', 'Failed to dispatch new lecture notification', error: e, stackTrace: st);
    }
  }

  /// 2. Notify students when a new exam is published
  static Future<void> notifyNewExam({
    required String title,
    required String groupId,
    required String examId,
    int? maxScore,
    int? durationMinutes,
  }) async {
    try {
      final notifRepo = InjectionContainer.notificationsRepository;
      await notifRepo.dispatchNotification(
        title: 'اختبار جديد: $title',
        body: 'تم نشر اختبار جديد "$title". تفضل بالدخول للاختبار وأداء الأسئلة في الوقت المحدد.',
        type: NotificationType.examPublished,
        groupId: groupId,
        data: {
          'exam_id': examId,
          'group_id': groupId,
          if (maxScore != null) 'max_score': maxScore,
          if (durationMinutes != null) 'duration_minutes': durationMinutes,
        },
      );
    } catch (e, st) {
      AppLogger.e('NotificationDispatcher', 'Failed to dispatch new exam notification', error: e, stackTrace: st);
    }
  }

  /// 3. Notify students when a new assignment is posted
  static Future<void> notifyNewAssignment({
    required String title,
    required String groupId,
    required String assignmentId,
    DateTime? dueAt,
    int? maxScore,
  }) async {
    try {
      final notifRepo = InjectionContainer.notificationsRepository;
      final dueStr = dueAt != null ? ' قبل ${dueAt.day}/${dueAt.month}' : '';
      await notifRepo.dispatchNotification(
        title: 'واجب جديد: $title',
        body: 'تم نشر تكليف جديد "$title"$dueStr. يُرجى رفعه وتسليمه للمراجعة.',
        type: NotificationType.assignmentCreated,
        groupId: groupId,
        data: {
          'assignment_id': assignmentId,
          'group_id': groupId,
          if (dueAt != null) 'due_at': dueAt.toIso8601String(),
          if (maxScore != null) 'max_score': maxScore,
        },
      );
    } catch (e, st) {
      AppLogger.e('NotificationDispatcher', 'Failed to dispatch new assignment notification', error: e, stackTrace: st);
    }
  }

  /// 4. Notify student and parent when an assignment is graded / reviewed
  static Future<void> notifyAssignmentGraded({
    required String assignmentTitle,
    required String studentId,
    required int score,
    required int maxScore,
    String? feedback,
    required String submissionId,
    required String assignmentId,
  }) async {
    try {
      final notifRepo = InjectionContainer.notificationsRepository;
      final feedbackStr = feedback != null && feedback.trim().isNotEmpty
          ? '\nملاحظات المعلم: ${feedback.trim()}'
          : '';
      await notifRepo.dispatchNotification(
        title: 'تم تقييم الواجب: $assignmentTitle',
        body: 'حصلت على درجة $score من $maxScore في واجب "$assignmentTitle".$feedbackStr',
        type: NotificationType.assignmentReviewed,
        userId: studentId,
        data: {
          'submission_id': submissionId,
          'assignment_id': assignmentId,
          'score': score,
          'max_score': maxScore,
        },
      );
    } catch (e, st) {
      AppLogger.e('NotificationDispatcher', 'Failed to dispatch assignment graded notification', error: e, stackTrace: st);
    }
  }

  /// 5. Notify student and parent when attendance is recorded
  static Future<void> notifyAttendanceMarked({
    required String studentId,
    required String sessionDate,
    required String statusLabel,
    required String groupId,
  }) async {
    try {
      final notifRepo = InjectionContainer.notificationsRepository;
      await notifRepo.dispatchNotification(
        title: 'رصد الحضور — $sessionDate',
        body: 'تم تسجيل حالة حضورك لمحاضرة ($sessionDate) كـ "$statusLabel".',
        type: NotificationType.attendanceMarked,
        userId: studentId,
        data: {
          'session_date': sessionDate,
          'status': statusLabel,
          'group_id': groupId,
        },
      );
    } catch (e, st) {
      AppLogger.e('NotificationDispatcher', 'Failed to dispatch attendance notification', error: e, stackTrace: st);
    }
  }

  /// 6. Notify student and parent when exam result is calculated
  static Future<void> notifyExamResult({
    required String examTitle,
    required String studentId,
    required int score,
    required int maxScore,
    required int percentage,
    required String attemptId,
    required String examId,
  }) async {
    try {
      final notifRepo = InjectionContainer.notificationsRepository;
      await notifRepo.dispatchNotification(
        title: 'نتيجة الاختبار: $examTitle',
        body: 'تم رصد نتيجتك في اختبار "$examTitle": $score من $maxScore ($percentage%). تفقد نموذج الإجابة للمراجعة.',
        type: NotificationType.examResult,
        userId: studentId,
        data: {
          'attempt_id': attemptId,
          'exam_id': examId,
          'score': score,
          'max_score': maxScore,
          'percentage': percentage,
        },
      );
    } catch (e, st) {
      AppLogger.e('NotificationDispatcher', 'Failed to dispatch exam result notification', error: e, stackTrace: st);
    }
  }
}
