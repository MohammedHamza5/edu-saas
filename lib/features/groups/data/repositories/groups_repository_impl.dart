import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/entities/group_member_entity.dart';
import '../../domain/repositories/groups_repository.dart';
import '../datasources/groups_remote_datasource.dart';

class GroupsRepositoryImpl implements GroupsRepository {
  final GroupsRemoteDataSource _remoteDataSource;

  GroupsRepositoryImpl({GroupsRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? GroupsRemoteDataSourceImpl();

  @override
  Future<Result<List<GroupEntity>>> getGroups() async {
    try {
      final groups = await _remoteDataSource.getGroups();
      return Success(List<GroupEntity>.from(groups));
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<GroupEntity>> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  }) async {
    try {
      final group = await _remoteDataSource.createGroup(
        name: name,
        level: level,
        description: description,
        previousContentAccess: previousContentAccess,
      );
      return Success(group);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<GroupEntity>> updateGroup({
    required String id,
    String? name,
    String? level,
    String? description,
    String? previousContentAccess,
    String? status,
    bool? enforceSequentialLearning,
    int? defaultPassingScore,
  }) async {
    try {
      final group = await _remoteDataSource.updateGroup(
        id: id,
        name: name,
        level: level,
        description: description,
        previousContentAccess: previousContentAccess,
        status: status,
        enforceSequentialLearning: enforceSequentialLearning,
        defaultPassingScore: defaultPassingScore,
      );
      return Success(group);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<GroupMemberEntity>>> getGroupMembers(
    String groupId,
  ) async {
    try {
      final members = await _remoteDataSource.getGroupMembers(groupId);
      return Success(members);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<GroupMemberEntity>> addMemberToGroup({
    required String groupId,
    required String studentId,
  }) async {
    try {
      final member = await _remoteDataSource.addMemberToGroup(
        groupId: groupId,
        studentId: studentId,
      );
      return Success(member);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  }) async {
    try {
      await _remoteDataSource.removeMemberFromGroup(
        groupId: groupId,
        studentId: studentId,
      );
      return const Success(null);
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
