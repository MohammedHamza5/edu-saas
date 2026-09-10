import 'package:equatable/equatable.dart';
import '../../domain/entities/notification_entity.dart';

sealed class NotificationsState extends Equatable {
  const NotificationsState();

  @override
  List<Object?> get props => [];
}

final class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

final class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

final class NotificationsLoaded extends NotificationsState {
  final List<NotificationEntity> notifications;
  final int unreadCount;
  final bool filterUnreadOnly;
  final bool isMarkingAll;
  final bool isSending;
  final bool sendSuccess;
  final String? message;

  const NotificationsLoaded({
    required this.notifications,
    required this.unreadCount,
    this.filterUnreadOnly = false,
    this.isMarkingAll = false,
    this.isSending = false,
    this.sendSuccess = false,
    this.message,
  });

  List<NotificationEntity> get filteredNotifications {
    if (filterUnreadOnly) {
      return notifications.where((n) => !n.isRead).toList();
    }
    return notifications;
  }

  NotificationsLoaded copyWith({
    List<NotificationEntity>? notifications,
    int? unreadCount,
    bool? filterUnreadOnly,
    bool? isMarkingAll,
    bool? isSending,
    bool? sendSuccess,
    String? message,
  }) {
    return NotificationsLoaded(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      filterUnreadOnly: filterUnreadOnly ?? this.filterUnreadOnly,
      isMarkingAll: isMarkingAll ?? this.isMarkingAll,
      isSending: isSending ?? this.isSending,
      sendSuccess: sendSuccess ?? this.sendSuccess,
      message: message,
    );
  }

  @override
  List<Object?> get props => [
    notifications,
    unreadCount,
    filterUnreadOnly,
    isMarkingAll,
    isSending,
    sendSuccess,
    message,
  ];
}

final class NotificationsError extends NotificationsState {
  final String message;

  const NotificationsError(this.message);

  @override
  List<Object?> get props => [message];
}
