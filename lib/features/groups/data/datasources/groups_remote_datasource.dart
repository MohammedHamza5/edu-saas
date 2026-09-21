import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';

abstract interface class GroupsRemoteDataSource {
  Future<List<GroupModel>> getGroups();

  Future<GroupModel> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  });

  Future<GroupModel> updateGroup({
    required String id,
    String? name,
    String? level,
    String? description,
    String? previousContentAccess,
    String? status,
    bool? enforceSequentialLearning,
    int? defaultPassingScore,
  });

  Future<List<GroupMemberModel>> getGroupMembers(String groupId);

  Future<GroupMemberModel> addMemberToGroup({
    required String groupId,
    required String studentId,
  });

  Future<void> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  });
}

class GroupsRemoteDataSourceImpl implements GroupsRemoteDataSource {
  final SupabaseClient? _client;

  GroupsRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<List<GroupModel>> getGroups() async {
    final response = await _safeClient
        .from('groups')
        .select('*, group_members(count)')
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((json) => GroupModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<GroupModel> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('AUTH_REQUIRED: User not authenticated');
    }

    final userProfile = await _safeClient
        .from('users')
        .select('tenant_id')
        .eq('id', currentUserId)
        .maybeSingle();

    if (userProfile == null || userProfile['tenant_id'] == null) {
      throw const AuthException('TEACHER_PROFILE_NOT_FOUND');
    }

    final tenantId = userProfile['tenant_id'] as String;

    final response = await _safeClient
        .from('groups')
        .insert({
          'tenant_id': tenantId,
          'name': name.trim(),
          'level': level.trim(),
          'description': description?.trim(),
          'previous_content_access': previousContentAccess,
          'status': 'active',
        })
        .select('*, group_members(count)')
        .single();

    return GroupModel.fromJson(response);
  }

  @override
  Future<GroupModel> updateGroup({
    required String id,
    String? name,
    String? level,
    String? description,
    String? previousContentAccess,
    String? status,
    bool? enforceSequentialLearning,
    int? defaultPassingScore,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name.trim();
    if (level != null) updates['level'] = level.trim();
    if (description != null) updates['description'] = description.trim();
    if (previousContentAccess != null) {
      updates['previous_content_access'] = previousContentAccess;
    }
    if (status != null) updates['status'] = status;
    if (enforceSequentialLearning != null) {
      updates['enforce_sequential_learning'] = enforceSequentialLearning;
    }
    if (defaultPassingScore != null) {
      updates['default_passing_score'] = defaultPassingScore;
    }

    final response = await _safeClient
        .from('groups')
        .update(updates)
        .eq('id', id)
        .select('*, group_members(count)')
        .single();

    return GroupModel.fromJson(response);
  }

  @override
  Future<List<GroupMemberModel>> getGroupMembers(String groupId) async {
    final response = await _safeClient
        .from('group_members')
        .select('*, users:student_id(full_name, email, phone)')
        .eq('group_id', groupId)
        .order('joined_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((json) => GroupMemberModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<GroupMemberModel> addMemberToGroup({
    required String groupId,
    required String studentId,
  }) async {
    final response = await _safeClient
        .from('group_members')
        .insert({
          'group_id': groupId,
          'student_id': studentId,
          'status': 'active',
        })
        .select('*, users:student_id(full_name, email, phone)')
        .single();

    return GroupMemberModel.fromJson(response);
  }

  @override
  Future<void> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  }) async {
    await _safeClient
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('student_id', studentId);
  }
}
