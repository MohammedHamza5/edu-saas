import 'package:equatable/equatable.dart';

class WhatsAppGatewayStatusEntity extends Equatable {
  final String status;
  final String? connectedPhone;
  final String? connectedName;
  final String? qrCode;
  final bool autoDispatchEnabled;
  final DateTime? lastHeartbeatAt;
  final int pendingCount;
  final int sentTodayCount;
  final int failedCount;

  const WhatsAppGatewayStatusEntity({
    required this.status,
    this.connectedPhone,
    this.connectedName,
    this.qrCode,
    this.autoDispatchEnabled = true,
    this.lastHeartbeatAt,
    this.pendingCount = 0,
    this.sentTodayCount = 0,
    this.failedCount = 0,
  });

  bool get isConnected => status == 'connected';
  bool get isQrReady => status == 'qr_ready' && qrCode != null;
  bool get isDisconnected => status == 'disconnected';

  factory WhatsAppGatewayStatusEntity.fromJson(Map<String, dynamic> json) {
    return WhatsAppGatewayStatusEntity(
      status: json['status']?.toString() ?? 'disconnected',
      connectedPhone: json['connected_phone']?.toString(),
      connectedName: json['connected_name']?.toString(),
      qrCode: json['qr_code']?.toString(),
      autoDispatchEnabled: json['auto_dispatch_enabled'] as bool? ?? true,
      lastHeartbeatAt: json['last_heartbeat_at'] != null
          ? DateTime.tryParse(json['last_heartbeat_at'].toString())
          : null,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      sentTodayCount: (json['sent_today_count'] as num?)?.toInt() ?? 0,
      failedCount: (json['failed_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        status,
        connectedPhone,
        connectedName,
        qrCode,
        autoDispatchEnabled,
        lastHeartbeatAt,
        pendingCount,
        sentTodayCount,
        failedCount,
      ];
}
