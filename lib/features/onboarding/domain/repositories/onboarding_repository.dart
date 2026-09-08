import '../../../../core/errors/result.dart';
import '../entities/provision_tenant_params.dart';
import '../entities/tenant_entity.dart';

abstract interface class OnboardingRepository {
  Future<Result<OnboardingResult>> provisionTenant(ProvisionTenantParams params);

  Future<Result<TenantEntity?>> getTenantById(String tenantId);

  Future<Result<List<TenantEntity>>> listTenants();
}
