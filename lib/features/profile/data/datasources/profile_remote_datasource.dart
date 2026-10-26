import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/student_profile_model.dart';

abstract interface class ProfileRemoteDataSource {
  Future<StudentProfileModel> getStudentProfile(String userId);

  Future<StudentProfileModel> updateStudentProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? parentPhone,
  });

  Future<void> changePassword({
    required String newPassword,
  });

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final SupabaseClient? _client;

  ProfileRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<StudentProfileModel> getStudentProfile(String userId) async {
    try {
      // 1. Fetch user base row
      final userRow = await _safeClient
          .from('users')
          .select('id, tenant_id, full_name, email, phone, parent_phone, avatar_url, status, created_at')
          .eq('id', userId)
          .single();

      // 2. Fetch enrolled groups
      List<Map<String, dynamic>> groupsList = [];
      try {
        final rawMemberships = await _safeClient
            .from('group_members')
            .select('groups(id, name, level)')
            .eq('student_id', userId)
            .eq('status', 'active');

        for (final item in (rawMemberships as List<dynamic>)) {
          if (item is Map && item['groups'] != null) {
            final groupData = Map<String, dynamic>.from(item['groups'] as Map);
            groupsList.add(groupData);
          }
        }
      } catch (grpErr) {
        AppLogger.w('ProfileRemoteDataSource', 'Could not load group memberships: $grpErr');
      }

      return StudentProfileModel.fromJson(userRow, groupsList: groupsList);
    } catch (e, stack) {
      AppLogger.e('ProfileRemoteDataSource', 'getStudentProfile failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<StudentProfileModel> updateStudentProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? parentPhone,
  }) async {
    try {
      final cleanName = fullName.trim();
      final cleanPhone = (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null;
      final cleanParentPhone =
          (parentPhone != null && parentPhone.trim().isNotEmpty) ? parentPhone.trim() : null;

      // 1. Update public.users
      final updatedUser = await _safeClient
          .from('users')
          .update({
            'full_name': cleanName,
            'phone': cleanPhone,
            'parent_phone': cleanParentPhone,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .select('id, tenant_id, full_name, email, phone, parent_phone, avatar_url, status, created_at')
          .single();

      // 2. Keep auth metadata synchronized
      try {
        await _safeClient.auth.updateUser(
          UserAttributes(
            data: {
              'full_name': cleanName,
              if (cleanPhone != null) 'phone': cleanPhone,
              if (cleanParentPhone != null) 'parent_phone': cleanParentPhone,
            },
          ),
        );
      } catch (authErr) {
        AppLogger.w('ProfileRemoteDataSource', 'Auth metadata sync non-fatal warning: $authErr');
      }

      // 3. Return fresh profile
      return getStudentProfile(userId);
    } catch (e, stack) {
      AppLogger.e('ProfileRemoteDataSource', 'updateStudentProfile failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<void> changePassword({
    required String newPassword,
  }) async {
    try {
      await _safeClient.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e, stack) {
      AppLogger.e('ProfileRemoteDataSource', 'changePassword failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final path = 'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _safeClient.storage.from('group-content').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl = _safeClient.storage.from('group-content').getPublicUrl(path);

      await _safeClient
          .from('users')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      return publicUrl;
    } catch (e, stack) {
      AppLogger.e('ProfileRemoteDataSource', 'uploadAvatar failed', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
