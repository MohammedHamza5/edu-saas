import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_remote_datasource.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsRemoteDataSource _remoteDataSource;

  SettingsRepositoryImpl({required SettingsRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<Result<Map<String, dynamic>?>> getTenantSettings(String tenantId) async {
    try {
      final settings = await _remoteDataSource.getTenantSettings(tenantId);
      return Success(settings);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في جلب إعدادات المنصة: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Result<void>> updateTenantVideoProvider(String provider) async {
    try {
      await _remoteDataSource.updateTenantVideoProvider(provider);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        ServerFailure('فشل في تحديث موفر الفيديو: ${e.toString()}'),
      );
    }
  }
}
