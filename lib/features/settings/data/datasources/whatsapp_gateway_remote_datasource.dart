import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/whatsapp_dispatch_config_entity.dart';
import '../../domain/entities/whatsapp_gateway_status_entity.dart';

abstract interface class WhatsAppGatewayRemoteDataSource {
  Future<WhatsAppGatewayStatusEntity> getGatewayStatus();
  Future<bool> setAutoDispatchEnabled(bool enabled);
  Future<void> refreshQrCode();
  Future<WhatsAppDispatchConfigEntity> getDispatchConfig();
  Future<bool> saveDispatchConfig(WhatsAppDispatchConfigEntity config);
}

class WhatsAppGatewayRemoteDataSourceImpl
    implements WhatsAppGatewayRemoteDataSource {
  static const _liveGatewayUrl =
      'https://whatsapp-gateway-h3i5.onrender.com/api/live-qr';
  static const _refreshGatewayUrl =
      'https://whatsapp-gateway-h3i5.onrender.com/api/refresh-qr';

  final SupabaseClient? _client;
  final Dio _dio;

  WhatsAppGatewayRemoteDataSourceImpl({
    SupabaseClient? client,
    Dio? dio,
  })  : _client = client,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            );

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<WhatsAppGatewayStatusEntity> getGatewayStatus() async {
    // 1. Fetch DB metrics from Supabase RPC
    WhatsAppGatewayStatusEntity? dbEntity;
    try {
      final res = await _safeClient.rpc<dynamic>('get_whatsapp_gateway_status');
      if (res is Map) {
        dbEntity = WhatsAppGatewayStatusEntity.fromJson(
          Map<String, dynamic>.from(res),
        );
      }
    } catch (e) {
      AppLogger.w('WhatsAppGatewayRemoteDataSource', 'DB status RPC failed: $e');
    }

    // 2. Direct Live Gateway check (instant QR & real-time connection state)
    try {
      final resp = await _dio.get<dynamic>(_liveGatewayUrl);
      if (resp.data is Map) {
        final map = Map<String, dynamic>.from(resp.data as Map);
        final isConnected = map['connected'] == true;
        final qr = map['qrCode']?.toString();
        final statusStr = isConnected
            ? 'connected'
            : (qr != null && qr.isNotEmpty
                ? 'qr_ready'
                : (dbEntity?.status ?? 'disconnected'));

        return WhatsAppGatewayStatusEntity(
          status: statusStr,
          connectedPhone:
              map['connectedPhone']?.toString() ?? dbEntity?.connectedPhone,
          connectedName:
              map['connectedName']?.toString() ?? dbEntity?.connectedName,
          qrCode: qr ?? dbEntity?.qrCode,
          autoDispatchEnabled: map['autoDispatchEnabled'] as bool? ??
              (dbEntity?.autoDispatchEnabled ?? true),
          lastHeartbeatAt: dbEntity?.lastHeartbeatAt,
          pendingCount: dbEntity?.pendingCount ?? 0,
          sentTodayCount: dbEntity?.sentTodayCount ?? 0,
          failedCount: dbEntity?.failedCount ?? 0,
        );
      }
    } catch (gatewayErr) {
      AppLogger.w(
        'WhatsAppGatewayRemoteDataSource',
        'Live gateway check bypassed, falling back to Supabase: $gatewayErr',
      );
    }

    // 3. Fallback: check sessions table directly if RPC didn't return session details
    if (dbEntity == null || (dbEntity.qrCode == null && !dbEntity.isConnected)) {
      try {
        final sessionRow = await _safeClient
            .from('whatsapp_auth_sessions')
            .select(
                'status, qr_code, connected_phone, connected_name, auto_dispatch_enabled, last_heartbeat_at')
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (sessionRow != null) {
          return WhatsAppGatewayStatusEntity(
            status: sessionRow['status']?.toString() ??
                (dbEntity?.status ?? 'disconnected'),
            connectedPhone: sessionRow['connected_phone']?.toString() ??
                dbEntity?.connectedPhone,
            connectedName: sessionRow['connected_name']?.toString() ??
                dbEntity?.connectedName,
            qrCode: sessionRow['qr_code']?.toString(),
            autoDispatchEnabled: sessionRow['auto_dispatch_enabled'] as bool? ??
                (dbEntity?.autoDispatchEnabled ?? true),
            lastHeartbeatAt: dbEntity?.lastHeartbeatAt,
            pendingCount: dbEntity?.pendingCount ?? 0,
            sentTodayCount: dbEntity?.sentTodayCount ?? 0,
            failedCount: dbEntity?.failedCount ?? 0,
          );
        }
      } catch (_) {}
    }

    return dbEntity ?? const WhatsAppGatewayStatusEntity(status: 'disconnected');
  }

  @override
  Future<bool> setAutoDispatchEnabled(bool enabled) async {
    try {
      final res = await _safeClient.rpc<dynamic>(
        'set_whatsapp_auto_dispatch',
        params: {'p_enabled': enabled},
      );
      return res as bool? ?? enabled;
    } catch (e, stack) {
      AppLogger.e('WhatsAppGatewayRemoteDataSource',
          'Failed to toggle auto dispatch',
          error: e, stackTrace: stack);
      return enabled;
    }
  }

  @override
  Future<void> refreshQrCode() async {
    try {
      await _dio.get<dynamic>(_refreshGatewayUrl);
    } catch (e) {
      AppLogger.w('WhatsAppGatewayRemoteDataSource', 'Failed to request fresh QR: $e');
    }
  }

  @override
  Future<WhatsAppDispatchConfigEntity> getDispatchConfig() async {
    try {
      final row = await _safeClient
          .from('whatsapp_auth_sessions')
          .select('dispatch_config')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row != null && row['dispatch_config'] is Map) {
        return WhatsAppDispatchConfigEntity.fromJson(
          Map<String, dynamic>.from(row['dispatch_config'] as Map),
        );
      }
    } catch (e) {
      AppLogger.w('WhatsAppGatewayRemoteDataSource',
          'Failed to fetch dispatch config, using default: $e');
    }
    return WhatsAppDispatchConfigEntity.defaultConfiguration;
  }

  @override
  Future<bool> saveDispatchConfig(WhatsAppDispatchConfigEntity config) async {
    try {
      await _safeClient.rpc<dynamic>(
        'save_whatsapp_dispatch_config',
        params: {'p_config': config.toJson()},
      );
      return true;
    } catch (e, stack) {
      AppLogger.e('WhatsAppGatewayRemoteDataSource',
          'Failed to save dispatch config',
          error: e, stackTrace: stack);
      return false;
    }
  }
}
