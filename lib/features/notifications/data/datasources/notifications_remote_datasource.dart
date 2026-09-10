import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
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

    // 1. Fetch teacher tenant_id
    final userProfile = await _safeClient
        .from('users')
        .select('tenant_id')
        .eq('id', currentUser.id)
        .maybeSingle();

    if (userProfile == null) {
      throw const PostgrestException(message: 'Teacher user profile not found');
    }

    final tenantId = userProfile['tenant_id'] as String;

    // 2. Insert notification record
    final notifResponse = await _safeClient
        .from('notifications')
        .insert({
          'tenant_id': tenantId,
          'title': title.trim(),
          'body': body.trim(),
          'type': NotificationType.importantAnnouncement.dbValue,
          'data': groupId != null
              ? <String, dynamic>{'group_id': groupId}
              : <String, dynamic>{},
        })
        .select('id')
        .single();

    final notifId = notifResponse['id'] as String;

    // 3. Resolve target user IDs
    final List<String> targetUserIds = [];

    if (groupId != null && groupId.isNotEmpty) {
      final membersResponse = await _safeClient
          .from('group_members')
          .select('student_id')
          .eq('group_id', groupId)
          .eq('status', 'active');

      final membersList = membersResponse as List<dynamic>;
      for (final m in membersList) {
        targetUserIds.add(m['student_id'] as String);
      }
    } else {
      // Send to all active students in the tenant
      final studentsResponse = await _safeClient
          .from('users')
          .select('id')
          .eq('tenant_id', tenantId)
          .eq('role', 'student')
          .eq('status', 'active');

      final studentsList = studentsResponse as List<dynamic>;
      for (final s in studentsList) {
        targetUserIds.add(s['id'] as String);
      }
    }

    // 4. Batch insert into notification_recipients
    if (targetUserIds.isNotEmpty) {
      final recipientsData = targetUserIds
          .map((uid) => {'notification_id': notifId, 'user_id': uid})
          .toList();

      await _safeClient.from('notification_recipients').insert(recipientsData);
    }
  }
}
