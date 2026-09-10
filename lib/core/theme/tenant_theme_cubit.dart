import 'package:flutter_bloc/flutter_bloc.dart';
import '../config/tenant_registry.dart';
import '../utils/app_logger.dart';
import 'tenant_branding.dart';

/// Cubit managing the active [TenantBranding] state across the entire app.
///
/// Triggers reactive theme updates whenever a new teacher is onboarded,
/// a tenant is switched, or an authenticated user's tenant is detected.
class TenantThemeCubit extends Cubit<TenantBranding> {
  TenantThemeCubit({TenantBranding? initialBranding})
      : super(initialBranding ?? TenantRegistry.defaultBranding) {
    AppLogger.i('TenantThemeCubit', 'Initialized with tenant: ${state.brandName} (${state.tenantId})');
  }

  /// Sets the active tenant branding directly
  void setBranding(TenantBranding branding) {
    AppLogger.i('TenantThemeCubit', 'Switching branding to: ${branding.brandName} (${branding.tenantId})');
    emit(branding);
  }

  /// Resolves and applies branding based on tenantId from Auth or Route
  void loadForTenant(String? tenantId) {
    final branding = TenantRegistry.resolve(tenantId);
    if (branding != state) {
      AppLogger.i('TenantThemeCubit', 'Loaded tenant branding: ${branding.brandName} for id: $tenantId');
      emit(branding);
    }
  }

  /// Resets to default platform branding
  void resetToDefault() {
    emit(TenantRegistry.defaultBranding);
  }
}
