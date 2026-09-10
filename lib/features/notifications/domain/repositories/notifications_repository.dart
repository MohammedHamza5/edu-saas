import '../../../../core/errors/result.dart';
import '../entities/notification_entity.dart';

abstract interface class NotificationsRepository {
  /// Fetches the user's notifications (in-app) sorted by creation date descending
  Future<Result<List<NotificationEntity>>> getMyNotifications({
    int limit = 50,
    int offset = 0,
  });

  /// Returns the current count of unread notifications for the active user
  Future<Result<int>> getUnreadCount();

  /// Marks a specific notification recipient record as read (updates read_at)
  Future<Result<void>> markAsRead(String recipientId);

  /// Marks all unread notifications for the active user as read
  Future<Result<void>> markAllAsRead();

  /// Teacher sends an announcement to all students in tenant or a specific group
  Future<Result<void>> sendAnnouncement({
    required String title,
    required String body,
    String? groupId,
  });
}
