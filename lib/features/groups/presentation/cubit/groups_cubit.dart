import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/repositories/groups_repository.dart';
import 'groups_state.dart';

class GroupsCubit extends Cubit<GroupsState> {
  final GroupsRepository _repository;

  // ── Cache keys ──────────────────────────────────────────────────────────
  static const _cacheKeyGroups = 'groups_all';

  GroupsCubit({required GroupsRepository repository})
    : _repository = repository,
      super(const GroupsInitial());

  Future<void> loadGroups({bool forceRefresh = false}) async {
    if (forceRefresh) {
      AppCache.groups.invalidate(_cacheKeyGroups);
    }
    // ── Stale-While-Revalidate: show cached data instantly ──────────────
    final cached = AppCache.groups.getStale(_cacheKeyGroups);
    if (cached is List<GroupEntity>) {
      emit(GroupsLoaded(groups: cached));
      // If still fresh and not forceRefresh, skip network
      if (!forceRefresh && AppCache.groups.has(_cacheKeyGroups)) return;
      // Otherwise continue to refresh silently (no loading state)
    } else {
      emit(const GroupsLoading());
    }

    final result = await _repository.getGroups();
    if (isClosed) return;

    result.when(
      onSuccess: (groups) {
        if (!isClosed) {
          AppCache.groups.put(_cacheKeyGroups, groups);
          emit(GroupsLoaded(groups: groups));
        }
      },
      onFailure: (failure) {
        if (!isClosed) emit(GroupsError(failure.message));
      },
    );
  }

  /// Silently refreshes groups in the background without showing loading.
  Future<void> silentRefresh() async {
    if (AppCache.groups.has(_cacheKeyGroups)) return; // Still fresh

    final result = await _repository.getGroups();
    if (isClosed) return;

    result.when(
      onSuccess: (groups) {
        if (!isClosed) {
          AppCache.groups.put(_cacheKeyGroups, groups);
          emit(GroupsLoaded(groups: groups));
        }
      },
      onFailure: (_) {}, // Silent
    );
  }

  void setFilterLevel(String? level) {
    if (state is GroupsLoaded) {
      final current = state as GroupsLoaded;
      emit(current.copyWith(filterLevel: level, clearFilter: level == null));
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

    if (isClosed) return false;

    return result.when(
      onSuccess: (newGroup) {
        // Invalidate cache after write
        AppCache.groups.invalidate(_cacheKeyGroups);

        if (state is GroupsLoaded) {
          final current = state as GroupsLoaded;
          if (!isClosed) {
            final updatedGroups = [newGroup, ...current.groups];
            // Update cache with fresh data
            AppCache.groups.put(_cacheKeyGroups, updatedGroups);
            emit(current.copyWith(groups: updatedGroups));
          }
        } else {
          loadGroups();
        }
        return true;
      },
      onFailure: (failure) {
        if (!isClosed) emit(GroupsError(failure.message));
        return false;
      },
    );
  }

  Future<void> loadGroupDetail(String groupId, {bool forceRefresh = false}) async {
    if (state is! GroupsLoaded) {
      await loadGroups();
    }
    if (isClosed) return;
    await loadGroupMembers(groupId, forceRefresh: forceRefresh);
  }

  Future<void> loadGroupMembers(String groupId, {bool forceRefresh = false}) async {
    if (state is GroupsLoaded) {
      final current = state as GroupsLoaded;
      GroupEntity? group;
      for (final g in current.groups) {
        if (g.id == groupId) {
          group = g;
          break;
        }
      }
      group ??= current.groups.isNotEmpty ? current.groups.first : null;
      if (group == null) return;

      // Check members cache
      final membersCacheKey = 'members_$groupId';
      if (forceRefresh) {
        AppCache.groups.invalidate(membersCacheKey);
      }
      final cachedMembers = AppCache.groups.getStale(membersCacheKey);
      if (cachedMembers != null) {
        emit(current.copyWith(selectedGroup: group, groupMembers: (cachedMembers as List).cast()));
        if (!forceRefresh && AppCache.groups.has(membersCacheKey)) return;
      }

      final membersResult = await _repository.getGroupMembers(groupId);
      if (isClosed) return;

      membersResult.when(
        onSuccess: (members) {
          if (!isClosed) {
            AppCache.groups.put(membersCacheKey, members);
            emit(current.copyWith(selectedGroup: group, groupMembers: members));
          }
        },
        onFailure: (failure) {
          if (!isClosed) {
            emit(current.copyWith(selectedGroup: group));
          }
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

    if (isClosed) return false;

    return result.when(
      onSuccess: (newMember) {
        // Invalidate members cache
        AppCache.groups.invalidate('members_$groupId');

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

          // Update groups cache
          AppCache.groups.put(_cacheKeyGroups, updatedGroups);

          if (!isClosed) {
            emit(
              current.copyWith(
                groups: updatedGroups,
                groupMembers: updatedMembers,
              ),
            );
          }
        }
        return true;
      },
      onFailure: (failure) {
        if (!isClosed) emit(GroupsError(failure.message));
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

    if (isClosed) return false;

    return result.when(
      onSuccess: (_) {
        // Invalidate members cache
        AppCache.groups.invalidate('members_$groupId');

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

          // Update groups cache
          AppCache.groups.put(_cacheKeyGroups, updatedGroups);

          if (!isClosed) {
            emit(
              current.copyWith(
                groups: updatedGroups,
                groupMembers: updatedMembers,
              ),
            );
          }
        }
        return true;
      },
      onFailure: (failure) {
        if (!isClosed) emit(GroupsError(failure.message));
        return false;
      },
    );
  }

  Future<bool> updateGroupSettings({
    required String groupId,
    required bool enforceSequentialLearning,
    required int defaultPassingScore,
  }) async {
    final result = await _repository.updateGroup(
      id: groupId,
      enforceSequentialLearning: enforceSequentialLearning,
      defaultPassingScore: defaultPassingScore,
    );

    if (isClosed) return false;

    return result.when(
      onSuccess: (updated) {
        AppCache.groups.invalidate(_cacheKeyGroups);
        if (state is GroupsLoaded) {
          final current = state as GroupsLoaded;
          if (!isClosed) {
            final idx = current.groups.indexWhere((g) => g.id == updated.id);
            if (idx != -1) {
              final newGroups = List<GroupEntity>.from(current.groups);
              newGroups[idx] = updated;
              AppCache.groups.put(_cacheKeyGroups, newGroups);
              emit(current.copyWith(
                groups: newGroups,
                selectedGroup:
                    current.selectedGroup?.id == updated.id ? updated : null,
              ));
            }
          }
        }
        return true;
      },
      onFailure: (failure) {
        if (!isClosed) emit(GroupsError(failure.message));
        return false;
      },
    );
  }
}
