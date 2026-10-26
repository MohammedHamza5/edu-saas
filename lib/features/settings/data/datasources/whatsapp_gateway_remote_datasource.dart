import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/whatsapp_gateway_status_entity.dart';

abstract interface class WhatsAppGatewayRemoteDataSource {
  Future<WhatsAppGatewayStatusEntity> getGatewayStatus();
  Future<bool> setAutoDispatchEnabled(bool enabled);
}

class WhatsAppGatewayRemoteDataSourceImpl
    implements WhatsAppGatewayRemoteDataSource {
  final SupabaseClient? _client;

  WhatsAppGatewayRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<WhatsAppGatewayStatusEntity> getGatewayStatus() async {
    try {
      final res = await _safeClient.rpc<dynamic>('get_whatsapp_gateway_status');
      if (res is Map) {
        return WhatsAppGatewayStatusEntity.fromJson(
          Map<String, dynamic>.from(res),
        );
      }
      return const WhatsAppGatewayStatusEntity(status: 'disconnected');
    } catch (e, stack) {
      AppLogger.e('WhatsAppGatewayRemoteDataSource',
          'Failed to fetch gateway status',
          error: e, stackTrace: stack);
      return const WhatsAppGatewayStatusEntity(status: 'disconnected');
    }
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
}
