import '../../domain/entities/notification_entity.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.recipientId,
    required super.tenantId,
    required super.title,
    required super.body,
    required super.type,
    super.data = const {},
    super.readAt,
    required super.createdAt,
  });

  /// Maps joined row from notification_recipients & notifications:
  /// {
  ///   'id': 'recipient_uuid',
  ///   'read_at': '...',
  ///   'created_at': '...',
  ///   'notifications': {
  ///     'id': 'notification_uuid',
  ///     'tenant_id': '...',
  ///     'title': '...',
  ///     'body': '...',
  ///     'type': '...',
  ///     'data': {...},
  ///     'created_at': '...'
  ///   }
  /// }
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final notifData = (json['notifications'] as Map<String, dynamic>?) ?? json;

    return NotificationModel(
      id:
          notifData['id'] as String? ??
          json['notification_id'] as String? ??
          '',
      recipientId: json['id'] as String? ?? '',
      tenantId: notifData['tenant_id'] as String? ?? '',
      title: notifData['title'] as String? ?? '',
      body: notifData['body'] as String? ?? '',
      type: NotificationType.fromString(notifData['type'] as String?),
      data: (notifData['data'] as Map<String, dynamic>?) ?? const {},
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: notifData['created_at'] != null
          ? DateTime.parse(notifData['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient_id': recipientId,
      'tenant_id': tenantId,
      'title': title,
      'body': body,
      'type': type.dbValue,
      'data': data,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
