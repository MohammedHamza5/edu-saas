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
    // Fetch authoritative tenant-scoped DB metrics from Supabase RPC
    try {
      final res = await _safeClient.rpc<dynamic>('get_whatsapp_gateway_status');
      if (res is Map) {
        return WhatsAppGatewayStatusEntity.fromJson(
          Map<String, dynamic>.from(res),
        );
      }
    } catch (e) {
      AppLogger.w('WhatsAppGatewayRemoteDataSource', 'DB status RPC failed: $e');
    }

    return const WhatsAppGatewayStatusEntity(status: 'disconnected');
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
