import 'tenant_registry.dart';
import '../theme/tenant_branding.dart';

/// Central Resolver for Multi-Tenant Domain & Subdomain Routing.
/// Automatically identifies the active tenant based on:
/// 1. Query parameters (?tenant=... or ?tenant_id=...)
/// 2. Browser Host / Subdomain (e.g. antounios.edsentre.com, antounios.web.app)
/// 3. Fallback to Premier Tenant (Dr. Antounios Ashraf)
class TenantResolver {
  TenantResolver._();

  /// Default Premier Tenant ID (Dr. Antounios Ashraf Platform)
  static const String defaultTenantId = 'ea5caf8b-112f-4044-b9ad-798d5ab025c3';

  /// Resolves the canonical Tenant ID for student registration or public requests.
  static String resolveTenantId({Uri? currentUri}) {
    final uri = currentUri ?? Uri.base;

    // 1. Check query parameters explicitly
    final queryTenant = uri.queryParameters['tenant'] ?? uri.queryParameters['tenant_id'];
    if (queryTenant != null && queryTenant.trim().isNotEmpty) {
      final clean = queryTenant.trim();
      if (clean == 'antounios' || clean == 'dr-antounios' || clean == 'drantounios') {
        return defaultTenantId;
      }
      return clean;
    }

    // 2. Check host and subdomain
    final host = uri.host.toLowerCase();

    // Isolated Testing / Sandbox Environment
    if (host.contains('antounios-test') || host.contains('staging')) {
      return '11111111-1111-1111-1111-111111111111';
    }

    // Official Production Environment (Dr. Antounios Ashraf)
    if (host.contains('antounios') || host.contains('edsentre')) {
      return defaultTenantId;
    }

    // 3. Fallback
    return defaultTenantId;
  }

  /// Resolves the branding corresponding to the current browser domain or tenant ID.
  static TenantBranding resolveBranding({String? tenantId, Uri? currentUri}) {
    if (tenantId != null && tenantId.isNotEmpty) {
      return TenantRegistry.resolve(tenantId);
    }
    final resolvedId = resolveTenantId(currentUri: currentUri);
    return TenantRegistry.resolve(resolvedId);
  }
}
