import '../../../../core/errors/result.dart';

abstract interface class SettingsRepository {
  /// Fetches tenant settings (video provider, contact info)
  Future<Result<Map<String, dynamic>?>> getTenantSettings(String tenantId);

  /// Updates tenant video provider via atomic backend RPC
  Future<Result<void>> updateTenantVideoProvider(String provider);
}
