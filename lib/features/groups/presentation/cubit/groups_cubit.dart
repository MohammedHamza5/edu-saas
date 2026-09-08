import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/groups_repository.dart';
import 'groups_state.dart';

class GroupsCubit extends Cubit<GroupsState> {
  final GroupsRepository _repository;

  GroupsCubit({required GroupsRepository repository})
      : _repository = repository,
        super(const GroupsInitial());

  Future<void> loadGroups() async {
    emit(const GroupsLoading());
    final result = await _repository.getGroups();

    result.when(
      onSuccess: (groups) {
        emit(GroupsLoaded(groups: groups));
      },
      onFailure: (failure) {
        emit(GroupsError(failure.message));
      },
    );
  }

  void setFilterLevel(String? level) {
    if (state is GroupsLoaded) {
      final current = state as GroupsLoaded;
      emit(current.copyWith(
        filterLevel: level,
        clearFilter: level == null,
      ));
    }
  }

  Future<bool> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  }) async {
    final result = await _repository.createGroup(
      name: name,
      level: level,
      description: description,
      previousContentAccess: previousContentAccess,
    );

    return result.when(
      onSuccess: (newGroup) {
        if (state is GroupsLoaded) {
          final current = state as GroupsLoaded;
          emit(current.copyWith(
            groups: [newGroup, ...current.groups],
          ));
        } else {
          loadGroups();
        }
        return true;
      },
      onFailure: (failure) {
        emit(GroupsError(failure.message));
        return false;
      },
    );
  }

  Future<void> loadGroupDetail(String groupId) async {
    if (state is GroupsLoaded) {
      final current = state as GroupsLoaded;
      final group = current.groups.firstWhere(
        (g) => g.id == groupId,
        orElse: () => current.groups.first,
      );

      final membersResult = await _repository.getGroupMembers(groupId);
      membersResult.when(
        onSuccess: (members) {
          emit(current.copyWith(
            selectedGroup: group,
            groupMembers: members,
          ));
        },
        onFailure: (failure) {
          emit(current.copyWith(selectedGroup: group));
        },
      );
    }
  }

  Future<bool> addMember({
    required String groupId,
    required String studentId,
  }) async {
    final result = await _repository.addMemberToGroup(
      groupId: groupId,
      studentId: studentId,
    );

    return result.when(
      onSuccess: (newMember) {
        if (state is GroupsLoaded) {
          final current = state as GroupsLoaded;
          final updatedMembers = [newMember, ...current.groupMembers];
          // Increment member count on selected group
          final updatedGroups = current.groups.map((g) {
            if (g.id == groupId) {
              return g.copyWith(membersCount: g.membersCount + 1);
            }
            return g;
          }).toList();

          emit(current.copyWith(
            groups: updatedGroups,
            groupMembers: updatedMembers,
          ));
        }
        return true;
      },
      onFailure: (failure) {
        emit(GroupsError(failure.message));
        return false;
      },
    );
  }

  Future<bool> removeMember({
    required String groupId,
    required String studentId,
  }) async {
    final result = await _repository.removeMemberFromGroup(
      groupId: groupId,
      studentId: studentId,
    );

    return result.when(
      onSuccess: (_) {
        if (state is GroupsLoaded) {
          final current = state as GroupsLoaded;
          final updatedMembers = current.groupMembers
              .where((m) => m.studentId != studentId)
              .toList();

          final updatedGroups = current.groups.map((g) {
            if (g.id == groupId) {
              return g.copyWith(
                membersCount: g.membersCount > 0 ? g.membersCount - 1 : 0,
              );
            }
            return g;
          }).toList();

          emit(current.copyWith(
            groups: updatedGroups,
            groupMembers: updatedMembers,
          ));
        }
        return true;
      },
      onFailure: (failure) {
        emit(GroupsError(failure.message));
        return false;
      },
    );
  }
}
