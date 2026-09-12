import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  });

  Future<UserModel> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? parentPhone,
    required String tenantId,
  });

  Future<void> signOut();

  Future<UserModel?> getCurrentUserProfile();

  Future<void> resetPassword(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient? _client;

  AuthRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _safeClient.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final userId = response.user?.id;
    if (userId == null) {
      throw const AuthException('User ID not returned after authentication.');
    }

    return await _fetchUserProfile(userId);
  }

  @override
  Future<UserModel> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? parentPhone,
    required String tenantId,
  }) async {
    final response = await _safeClient.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        if (parentPhone != null && parentPhone.trim().isNotEmpty)
          'parent_phone': parentPhone.trim(),
        'tenant_id': tenantId,
        'role': 'student',
      },
    );

    final userId = response.user?.id;
    if (userId == null) {
      throw const AuthException('Registration succeeded but user ID is missing.');
    }

    try {
      return await _fetchUserProfile(userId);
    } catch (_) {
      // If email confirmation is required or session is not established immediately,
      // the newly created user in public.users has status = 'pending' and is shielded
      // by RLS from unauthenticated requests. We construct the pending UserModel directly.
      return UserModel(
        id: userId,
        tenantId: tenantId,
        role: UserRole.student,
        status: UserStatus.pending,
        fullName: fullName.trim(),
        email: email.trim(),
        phone: phone.trim(),
        parentPhone: parentPhone?.trim(),
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _safeClient.auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUserProfile() async {
    final user = _safeClient.auth.currentUser;
    if (user == null) return null;
    return await _fetchUserProfile(user.id);
  }

  @override
  Future<void> resetPassword(String email) async {
    await _safeClient.auth.resetPasswordForEmail(email.trim());
  }

  Future<UserModel> _fetchUserProfile(String userId) async {
    // ⚡ Performance: استعلام JOIN واحد بدلاً من استعلامين متتاليين
    // يجلب بيانات المستخدم + حالة الـ Tenant في رحلة HTTP واحدة
    final data = await _safeClient
        .from('users')
        .select('id, tenant_id, role, status, full_name, email, phone, parent_phone, tenants!inner(status)')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      throw const AuthException('User profile record not found in database.');
    }

    // Check if tenant is suspended (Rule 2.6: tenant.status = suspended -> complete block)
    final tenantInfo = data['tenants'] as Map<String, dynamic>?;
    if (tenantInfo != null && tenantInfo['status'] == 'suspended') {
      throw const AuthException('TENANT_SUSPENDED');
    }

    return UserModel.fromJson(data);
  }
}
