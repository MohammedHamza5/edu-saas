import 'package:equatable/equatable.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/entities/group_member_entity.dart';

sealed class GroupsState extends Equatable {
  const GroupsState();

  @override
  List<Object?> get props => [];
}

final class GroupsInitial extends GroupsState {
  const GroupsInitial();
}

final class GroupsLoading extends GroupsState {
  const GroupsLoading();
}

final class GroupsLoaded extends GroupsState {
  final List<GroupEntity> groups;
  final String? filterLevel;
  final GroupEntity? selectedGroup;
  final List<GroupMemberEntity> groupMembers;

  const GroupsLoaded({
    required this.groups,
    this.filterLevel,
    this.selectedGroup,
    this.groupMembers = const [],
  });

  List<GroupEntity> get filteredGroups {
    if (filterLevel == null || filterLevel == 'ALL') {
      return groups;
    }
    return groups.where((g) => g.level == filterLevel).toList();
  }

  GroupsLoaded copyWith({
    List<GroupEntity>? groups,
    String? filterLevel,
    bool clearFilter = false,
    GroupEntity? selectedGroup,
    List<GroupMemberEntity>? groupMembers,
  }) {
    return GroupsLoaded(
      groups: groups ?? this.groups,
      filterLevel: clearFilter ? null : (filterLevel ?? this.filterLevel),
      selectedGroup: selectedGroup ?? this.selectedGroup,
      groupMembers: groupMembers ?? this.groupMembers,
    );
  }

  @override
  List<Object?> get props => [groups, filterLevel, selectedGroup, groupMembers];
}

final class GroupsError extends GroupsState {
  final String message;

  const GroupsError(this.message);

  @override
  List<Object?> get props => [message];
}
