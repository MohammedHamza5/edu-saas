import '../../../../core/errors/result.dart';
import '../entities/group_entity.dart';
import '../entities/group_member_entity.dart';

abstract interface class GroupsRepository {
  Future<Result<List<GroupEntity>>> getGroups();

  Future<Result<GroupEntity>> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  });

  Future<Result<GroupEntity>> updateGroup({
    required String id,
    String? name,
    String? level,
    String? description,
    String? previousContentAccess,
    String? status,
  });

  Future<Result<List<GroupMemberEntity>>> getGroupMembers(String groupId);

  Future<Result<GroupMemberEntity>> addMemberToGroup({
    required String groupId,
    required String studentId,
  });

  Future<Result<void>> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  });
}
