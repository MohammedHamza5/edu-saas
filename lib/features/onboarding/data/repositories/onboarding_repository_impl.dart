import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/provision_tenant_params.dart';
import '../../domain/entities/tenant_entity.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_remote_datasource.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingRemoteDataSource _remoteDataSource;

  OnboardingRepositoryImpl({
    required OnboardingRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Result<OnboardingResult>> provisionTenant(
      ProvisionTenantParams params) async {
    try {
      final result = await _remoteDataSource.provisionTenant(params);
      return Success(result);
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<TenantEntity?>> getTenantById(String tenantId) async {
    try {
      final tenant = await _remoteDataSource.getTenantById(tenantId);
      return Success(tenant);
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<TenantEntity>>> listTenants() async {
    try {
      final tenants = await _remoteDataSource.listTenants();
      return Success(tenants);
    } on ServerException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
