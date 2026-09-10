import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repository;

  // ── Cache keys ──────────────────────────────────────────────────────────
  static const _cacheKeyNotifs = 'notifications_all';

  NotificationsCubit({required NotificationsRepository repository})
    : _repository = repository,
      super(const NotificationsInitial());

  /// Loads notifications and unread count — with parallel fetch + cache.
  Future<void> loadNotifications() async {
    // ── Stale-While-Revalidate ────────────────────────────────────────────
    final cached = AppCache.notifications.getStale(_cacheKeyNotifs);
    if (cached is _NotifsCachePayload) {
      emit(NotificationsLoaded(
        notifications: cached.notifications,
        unreadCount: cached.unreadCount,
      ));
      if (AppCache.notifications.has(_cacheKeyNotifs)) return;
      // Continue to refresh silently
    } else {
      emit(const NotificationsLoading());
    }

    // ── Parallel fetch ───────────────────────────────────────────────────
    final notifsFuture = _repository.getMyNotifications();
    final countFuture = _repository.getUnreadCount();

    final notifsResult = await notifsFuture;
    final countResult = await countFuture;

    if (isClosed) return;

    if (notifsResult.isSuccess) {
      final notifs = notifsResult.dataOrNull ?? <NotificationEntity>[];
      final count = countResult.dataOrNull ?? notifs.where((n) => !n.isRead).length;

      // Cache result
      AppCache.notifications.put(_cacheKeyNotifs, _NotifsCachePayload(
        notifications: notifs,
        unreadCount: count,
      ));

      if (!isClosed) {
        emit(NotificationsLoaded(notifications: notifs, unreadCount: count));
      }
    } else {
      if (!isClosed) {
        emit(
          NotificationsError(
            notifsResult.failureOrNull?.message ?? 'فشل تحميل الإشعارات',
          ),
        );
      }
    }
  }

  /// Silently refreshes notifications in the background.
  Future<void> silentRefresh() async {
    if (AppCache.notifications.has(_cacheKeyNotifs)) return;

    final notifsFuture = _repository.getMyNotifications();
    final countFuture = _repository.getUnreadCount();

    final notifsResult = await notifsFuture;
    final countResult = await countFuture;

    if (isClosed) return;

    if (notifsResult.isSuccess) {
      final notifs = notifsResult.dataOrNull ?? <NotificationEntity>[];
      final count = countResult.dataOrNull ?? notifs.where((n) => !n.isRead).length;

      AppCache.notifications.put(_cacheKeyNotifs, _NotifsCachePayload(
        notifications: notifs,
        unreadCount: count,
      ));

      if (!isClosed) {
        emit(NotificationsLoaded(notifications: notifs, unreadCount: count));
      }
    }
  }

  /// Toggles between All and Unread filter
  void toggleUnreadFilter(bool unreadOnly) {
    final currentState = state;
    if (currentState is! NotificationsLoaded) return;
    emit(currentState.copyWith(filterUnreadOnly: unreadOnly));
  }

  /// Marks a specific notification as read (Optimistic UI supported)
  Future<void> markAsRead(String recipientId) async {
    final currentState = state;
    if (currentState is! NotificationsLoaded) return;

    // Optimistic update
    final updatedNotifs = currentState.notifications.map((n) {
      if (n.recipientId == recipientId && !n.isRead) {
        return n.copyWith(readAt: DateTime.now());
      }
      return n;
    }).toList();

    final newCount = (currentState.unreadCount - 1).clamp(0, 9999);

    // Update cache optimistically
    AppCache.notifications.put(_cacheKeyNotifs, _NotifsCachePayload(
      notifications: updatedNotifs,
      unreadCount: newCount,
    ));

    emit(
      currentState.copyWith(
        notifications: updatedNotifs,
        unreadCount: newCount,
      ),
    );

    // Fire & forget or background sync
    await _repository.markAsRead(recipientId);
  }

  /// Marks all unread notifications as read (Optimistic UI)
  Future<void> markAllAsRead() async {
    final currentState = state;
    if (currentState is! NotificationsLoaded) return;

    emit(currentState.copyWith(isMarkingAll: true));

    final updatedNotifs = currentState.notifications.map((n) {
      if (!n.isRead) {
        return n.copyWith(readAt: DateTime.now());
      }
      return n;
    }).toList();

    // Update cache optimistically
    AppCache.notifications.put(_cacheKeyNotifs, _NotifsCachePayload(
      notifications: updatedNotifs,
      unreadCount: 0,
    ));

    emit(
      currentState.copyWith(
        notifications: updatedNotifs,
        unreadCount: 0,
        isMarkingAll: false,
      ),
    );

    await _repository.markAllAsRead();
  }

  /// Teacher sends an announcement to all students or a specific group
  Future<void> sendAnnouncement({
    required String title,
    required String body,
    String? groupId,
  }) async {
    final currentState = state;
    final isLoaded = currentState is NotificationsLoaded;

    if (isLoaded) {
      emit(currentState.copyWith(isSending: true, sendSuccess: false));
    } else {
      emit(const NotificationsLoading());
    }

    final result = await _repository.sendAnnouncement(
      title: title,
      body: body,
      groupId: groupId,
    );

    if (isClosed) return;

    result.when(
      onSuccess: (_) {
        if (!isClosed) {
          // Invalidate cache after sending
          AppCache.notifications.invalidate(_cacheKeyNotifs);

          if (isLoaded) {
            emit(
              currentState.copyWith(
                isSending: false,
                sendSuccess: true,
                message: 'تم إرسال الإعلان بنجاح إلى الطلاب',
              ),
            );
          } else {
            loadNotifications();
          }
        }
      },
      onFailure: (failure) {
        if (!isClosed) {
          if (isLoaded) {
            emit(
              currentState.copyWith(
                isSending: false,
                sendSuccess: false,
                message: failure.message,
              ),
            );
          } else {
            emit(NotificationsError(failure.message));
          }
        }
      },
    );
  }
}

/// Internal cache payload for notifications.
class _NotifsCachePayload {
  final List<NotificationEntity> notifications;
  final int unreadCount;

  const _NotifsCachePayload({
    required this.notifications,
    required this.unreadCount,
  });
}
