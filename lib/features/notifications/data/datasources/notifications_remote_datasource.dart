import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/group_slug_resolver.dart';
import '../../domain/entities/notification_entity.dart';
import '../models/notification_model.dart';

abstract interface class NotificationsRemoteDataSource {
  Future<List<NotificationModel>> getMyNotifications({
    int limit = 50,
    int offset = 0,
  });

  Future<int> getUnreadCount();

  Future<void> markAsRead(String recipientId);

  Future<void> markAllAsRead();

  Future<void> sendAnnouncement({
    required String title,
    required String body,
    String? groupId,
  });

  Future<void> dispatchNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? groupId,
    String? userId,
    Map<String, dynamic>? data,
  });
}

class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  final SupabaseClient? _client;

  NotificationsRemoteDataSourceImpl({SupabaseClient? client})
    : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<List<NotificationModel>> getMyNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final currentUser = _safeClient.auth.currentUser;
    if (currentUser == null) return [];

    final response = await _safeClient
        .from('notification_recipients')
        .select(
          'id, read_at, created_at, notifications(id, tenant_id, title, body, type, data, created_at)',
        )
        .eq('user_id', currentUser.id)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final list = response as List<dynamic>;
    return list
        .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> getUnreadCount() async {
    final currentUser = _safeClient.auth.currentUser;
    if (currentUser == null) return 0;

    final response = await _safeClient
        .from('notification_recipients')
        .select('id')
        .eq('user_id', currentUser.id)
        .isFilter('read_at', null);

    return (response as List<dynamic>).length;
  }

  @override
  Future<void> markAsRead(String recipientId) async {
    await _safeClient
        .from('notification_recipients')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', recipientId);
  }

  @override
  Future<void> markAllAsRead() async {
    final currentUser = _safeClient.auth.currentUser;
    if (currentUser == null) return;

    await _safeClient
        .from('notification_recipients')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', currentUser.id)
        .isFilter('read_at', null);
  }

  @override
  Future<void> sendAnnouncement({
    required String title,
    required String body,
    String? groupId,
  }) async {
    final currentUser = _safeClient.auth.currentUser;
    if (currentUser == null) {
      throw const AuthException('AUTH_REQUIRED: User not authenticated');
    }

    final resolvedGroupId = groupId != null && groupId.isNotEmpty
        ? GroupSlugResolver.toId(groupId)
        : null;

    final targetGroup = (resolvedGroupId != null && GroupSlugResolver.isUuid(resolvedGroupId))
        ? resolvedGroupId
        : null;

    await _safeClient.rpc<dynamic>('dispatch_tenant_announcement', params: {
      'p_title': title.trim(),
      'p_body': body.trim(),
      if (targetGroup != null) 'p_group_id': targetGroup,
    });
  }

  @override
  Future<void> dispatchNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? groupId,
    String? userId,
    Map<String, dynamic>? data,
  }) async {
    final currentUser = _safeClient.auth.currentUser;
    if (currentUser == null) return;

    if (userId != null && userId.isNotEmpty) {
      await _safeClient.rpc<dynamic>('dispatch_user_notification', params: {
        'p_user_id': userId,
        'p_title': title.trim(),
        'p_body': body.trim(),
        'p_type': type.dbValue,
        'p_data': data ?? {},
      });
    } else if (groupId != null && groupId.isNotEmpty) {
      final resolvedGroupId = GroupSlugResolver.toId(groupId);
      if (GroupSlugResolver.isUuid(resolvedGroupId)) {
        await _safeClient.rpc<dynamic>('dispatch_group_notification', params: {
          'p_group_id': resolvedGroupId,
          'p_title': title.trim(),
          'p_body': body.trim(),
          'p_type': type.dbValue,
          'p_data': data ?? {},
        });
      }
    } else {
      await _safeClient.rpc<dynamic>('dispatch_tenant_announcement', params: {
        'p_title': title.trim(),
        'p_body': body.trim(),
      });
    }
  }
}
