import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/provision_tenant_params.dart';
import '../models/tenant_model.dart';

abstract interface class OnboardingRemoteDataSource {
  Future<OnboardingResult> provisionTenant(ProvisionTenantParams params);

  Future<TenantModel?> getTenantById(String tenantId);

  Future<List<TenantModel>> listTenants();
}

class OnboardingRemoteDataSourceImpl implements OnboardingRemoteDataSource {
  final SupabaseClient? _client;

  OnboardingRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<OnboardingResult> provisionTenant(ProvisionTenantParams params) async {
    try {
      // 1. Create the new Tenant record
      final tenantData = await _safeClient.from('tenants').insert({
        'name': params.tenantName,
        'email': params.tenantEmail,
        'phone': params.tenantPhone,
        'logo_url': params.logoUrl,
        'status': 'active',
      }).select().single();

      final tenant = TenantModel.fromJson(tenantData);

      // 2. Provision the Teacher Account in Supabase Auth
      final authResponse = await _safeClient.auth.signUp(
        email: params.teacherEmail,
        password: params.teacherPassword,
        data: {
          'full_name': params.teacherFullName,
          'phone': params.teacherPhone,
          'tenant_id': tenant.id,
          'role': 'teacher',
        },
      );

      final authUser = authResponse.user;
      if (authUser == null) {
        throw const ServerException('فشل إنشاء حساب المعلم في نظام المصادقة');
      }

      // 3. Ensure Teacher Profile in public.users has active status and teacher role
      final updatedUserData = await _safeClient.from('users').upsert({
        'id': authUser.id,
        'tenant_id': tenant.id,
        'role': 'teacher',
        'full_name': params.teacherFullName,
        'email': params.teacherEmail,
        'phone': params.teacherPhone,
        'status': 'active',
      }).select().single();

      final teacher = UserEntity(
        id: updatedUserData['id'] as String,
        tenantId: updatedUserData['tenant_id'] as String,
        role: UserRole.teacher,
        status: UserStatus.active,
        fullName: updatedUserData['full_name'] as String,
        email: (updatedUserData['email'] as String?) ?? params.teacherEmail,
        phone: updatedUserData['phone'] as String?,
      );

      return OnboardingResult(tenant: tenant, teacher: teacher);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } on AuthException catch (e) {
      throw ServerException(e.message, code: e.statusCode);
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(e.toString());
    }
  }

  @override
  Future<TenantModel?> getTenantById(String tenantId) async {
    try {
      final data = await _client
          .from('tenants')
          .select()
          .eq('id', tenantId)
          .maybeSingle();

      if (data == null) return null;
      return TenantModel.fromJson(data);
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<TenantModel>> listTenants() async {
    try {
      final List<dynamic> data = await _client
          .from('tenants')
          .select()
          .order('created_at', ascending: false);

      return data
          .map((item) => TenantModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
