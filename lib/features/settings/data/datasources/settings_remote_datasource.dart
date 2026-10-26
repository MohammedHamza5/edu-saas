import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';

abstract interface class SettingsRemoteDataSource {
  Future<Map<String, dynamic>?> getTenantSettings(String tenantId);
  Future<void> updateTenantVideoProvider(String provider);
}

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  final SupabaseClient? _client;

  SettingsRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<Map<String, dynamic>?> getTenantSettings(String tenantId) async {
    try {
      final row = await _safeClient
          .from('tenants')
          .select('video_provider, name, email, phone')
          .eq('id', tenantId)
          .maybeSingle();
      return row;
    } catch (e, stack) {
      AppLogger.e('SettingsRemoteDataSource', 'Failed to fetch tenant settings', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<void> updateTenantVideoProvider(String provider) async {
    try {
      await _safeClient.rpc<void>(
        'update_tenant_video_provider',
        params: {'p_provider': provider},
      );
    } catch (e, stack) {
      AppLogger.e('SettingsRemoteDataSource', 'Failed to update tenant video provider', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
