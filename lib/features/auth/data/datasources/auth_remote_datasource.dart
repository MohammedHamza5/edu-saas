import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
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
    required String tenantId,
  });

  Future<void> signOut();

  Future<UserModel?> getCurrentUserProfile();

  Future<void> resetPassword(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient _client;

  AuthRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  @override
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
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
    required String tenantId,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'tenant_id': tenantId,
        'role': 'student',
      },
    );

    final userId = response.user?.id;
    if (userId == null) {
      throw const AuthException('Registration succeeded but user ID is missing.');
    }

    return await _fetchUserProfile(userId);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return await _fetchUserProfile(user.id);
  }

  @override
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<UserModel> _fetchUserProfile(String userId) async {
    final data = await _client
        .from('users')
        .select('id, tenant_id, role, status, full_name, email, phone')
        .eq('id', userId)
        .maybeSingle();

    if (data == null) {
      throw const AuthException('User profile record not found in database.');
    }

    // Check if tenant is suspended (Rule 2.6: tenant.status = suspended -> complete block)
    final tenantId = data['tenant_id'] as String;
    final tenantData = await _client
        .from('tenants')
        .select('status')
        .eq('id', tenantId)
        .maybeSingle();

    if (tenantData != null && tenantData['status'] == 'suspended') {
      throw const AuthException('TENANT_SUSPENDED');
    }

    return UserModel.fromJson(data);
  }
}
