import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/features/groups/domain/entities/group_entity.dart';
import 'package:edu_saas/features/groups/domain/entities/group_member_entity.dart';
import 'package:edu_saas/features/groups/domain/repositories/groups_repository.dart';
import 'package:edu_saas/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:edu_saas/features/groups/presentation/cubit/groups_state.dart';
import 'package:edu_saas/features/groups/presentation/pages/groups_list_page.dart';
import 'package:edu_saas/features/groups/presentation/widgets/create_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGroupsRepository implements GroupsRepository {
  List<GroupEntity> groups = [];
  Map<String, List<GroupMemberEntity>> membersByGroup = {};
  bool shouldFail = false;

  @override
  Future<Result<List<GroupEntity>>> getGroups() async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to load groups'));
    }
    return Success(List.from(groups));
  }

  @override
  Future<Result<GroupEntity>> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to create group'));
    }
    final newGroup = GroupEntity(
      id: 'grp-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: '11111111-1111-1111-1111-111111111111',
      name: name,
      level: level,
      description: description,
      previousContentAccess: previousContentAccess,
      status: 'active',
      createdAt: DateTime.now(),
      membersCount: 0,
    );
    groups.insert(0, newGroup);
    return Success(newGroup);
  }

  @override
  Future<Result<GroupEntity>> updateGroup({
    required String id,
    String? name,
    String? level,
    String? description,
    String? previousContentAccess,
    String? status,
  }) async {
    final index = groups.indexWhere((g) => g.id == id);
    if (index == -1) {
      return const FailureResult(ServerFailure('Group not found'));
    }
    final updated = groups[index].copyWith(
      name: name,
      level: level,
      description: description,
      previousContentAccess: previousContentAccess,
      status: status,
    );
    groups[index] = updated;
    return Success(updated);
  }

  @override
  Future<Result<List<GroupMemberEntity>>> getGroupMembers(String groupId) async {
    return Success(membersByGroup[groupId] ?? []);
  }

  @override
  Future<Result<GroupMemberEntity>> addMemberToGroup({
    required String groupId,
    required String studentId,
  }) async {
    final newMember = GroupMemberEntity(
      id: 'mem-${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      studentId: studentId,
      studentName: 'Test Student',
      studentEmail: 'student@example.com',
      joinedAt: DateTime.now(),
      status: 'active',
    );
    membersByGroup.putIfAbsent(groupId, () => []).add(newMember);

    final idx = groups.indexWhere((g) => g.id == groupId);
    if (idx != -1) {
      groups[idx] = groups[idx].copyWith(membersCount: groups[idx].membersCount + 1);
    }

    return Success(newMember);
  }

  @override
  Future<Result<void>> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  }) async {
    membersByGroup[groupId]?.removeWhere((m) => m.studentId == studentId);
    final idx = groups.indexWhere((g) => g.id == groupId);
    if (idx != -1 && groups[idx].membersCount > 0) {
      groups[idx] = groups[idx].copyWith(membersCount: groups[idx].membersCount - 1);
    }
    return const Success(null);
  }
}

void main() {
  late FakeGroupsRepository fakeRepo;
  late GroupsCubit groupsCubit;

  final sampleGroups = [
    const GroupEntity(
      id: 'grp-1',
      tenantId: '11111111-1111-1111-1111-111111111111',
      name: 'SAT Math Advanced',
      level: 'SAT',
      description: 'Intensive SAT prep',
      previousContentAccess: 'allow',
      membersCount: 15,
    ),
    const GroupEntity(
      id: 'grp-2',
      tenantId: '11111111-1111-1111-1111-111111111111',
      name: 'EST Level 1 Foundation',
      level: 'EST',
      description: 'EST basics',
      previousContentAccess: 'deny',
      membersCount: 8,
    ),
    const GroupEntity(
      id: 'grp-3',
      tenantId: '11111111-1111-1111-1111-111111111111',
      name: 'AP Calculus Intensive',
      level: 'AP Calculus',
      description: 'Custom academic track',
      previousContentAccess: 'allow',
      membersCount: 5,
    ),
  ];

  setUp(() {
    AppCache.clearAll();
    fakeRepo = FakeGroupsRepository();
    fakeRepo.groups = List.from(sampleGroups);
    groupsCubit = GroupsCubit(repository: fakeRepo);
  });

  tearDown(() {
    groupsCubit.close();
  });

  group('GroupsCubit Unit Tests', () {
    test('initial state is GroupsInitial', () {
      expect(groupsCubit.state, const GroupsInitial());
    });

    test('loadGroups emits GroupsLoading then GroupsLoaded with all groups', () async {
      final states = <GroupsState>[];
      final subscription = groupsCubit.stream.listen(states.add);

      await groupsCubit.loadGroups();
      await Future<void>.delayed(Duration.zero);

      expect(states.length, 2);
      expect(states[0], const GroupsLoading());
      expect(states[1], isA<GroupsLoaded>());
      final loaded = states[1] as GroupsLoaded;
      expect(loaded.groups.length, 3);
      expect(loaded.groups[0].name, 'SAT Math Advanced');

      await subscription.cancel();
    });

    test('filterByLevel filters groups correctly', () async {
      await groupsCubit.loadGroups();

      // Filter by SAT
      groupsCubit.setFilterLevel('SAT');
      final filteredSat = groupsCubit.state as GroupsLoaded;
      expect(filteredSat.filterLevel, 'SAT');
      expect(filteredSat.filteredGroups.length, 1);
      expect(filteredSat.filteredGroups.first.level, 'SAT');

      // Filter by EST
      groupsCubit.setFilterLevel('EST');
      final filteredEst = groupsCubit.state as GroupsLoaded;
      expect(filteredEst.filteredGroups.length, 1);
      expect(filteredEst.filteredGroups.first.level, 'EST');

      // Clear filter (All)
      groupsCubit.setFilterLevel(null);
      final all = groupsCubit.state as GroupsLoaded;
      expect(all.filteredGroups.length, 3);
    });

    test('createGroup adds new group and sets previousContentAccess correctly', () async {
      await groupsCubit.loadGroups();

      final success = await groupsCubit.createGroup(
        name: 'ACT Crash Course',
        level: 'ACT',
        description: 'Speed-run prep',
        previousContentAccess: 'deny',
      );

      expect(success, isTrue);
      final state = groupsCubit.state as GroupsLoaded;
      expect(state.groups.length, 4);
      expect(state.groups.first.name, 'ACT Crash Course');
      expect(state.groups.first.previousContentAccess, 'deny');
      expect(state.groups.first.isPreviousContentAllowed, isFalse);
    });

    test('loadGroupDetail loads members for a given group', () async {
      fakeRepo.membersByGroup['grp-1'] = [
        GroupMemberEntity(
          id: 'mem-1',
          groupId: 'grp-1',
          studentId: 'student-101',
          studentName: 'Youssef Ahmed',
          joinedAt: DateTime.now(),
        ),
      ];

      await groupsCubit.loadGroups();
      await groupsCubit.loadGroupDetail('grp-1');

      final state = groupsCubit.state as GroupsLoaded;
      expect(state.selectedGroup?.id, 'grp-1');
      expect(state.groupMembers.length, 1);
      expect(state.groupMembers.first.studentName, 'Youssef Ahmed');
    });

    test('removeMember removes student from group', () async {
      fakeRepo.membersByGroup['grp-1'] = [
        GroupMemberEntity(
          id: 'mem-1',
          groupId: 'grp-1',
          studentId: 'student-101',
          studentName: 'Youssef Ahmed',
          joinedAt: DateTime.now(),
        ),
      ];

      await groupsCubit.loadGroups();
      await groupsCubit.loadGroupDetail('grp-1');

      final removed = await groupsCubit.removeMember(
        groupId: 'grp-1',
        studentId: 'student-101',
      );

      expect(removed, isTrue);
      final state = groupsCubit.state as GroupsLoaded;
      expect(state.groupMembers.isEmpty, isTrue);
    });

    test('emits GroupsError when repository returns failure', () async {
      fakeRepo.shouldFail = true;
      await groupsCubit.loadGroups();

      expect(groupsCubit.state, isA<GroupsError>());
      final error = groupsCubit.state as GroupsError;
      expect(error.message, 'Failed to load groups');
    });
  });

  group('GroupsListPage Widget Tests', () {
    Widget createWidgetUnderTest(GroupsCubit cubit) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: BlocProvider<GroupsCubit>.value(
          value: cubit,
          child: const GroupsListPage(),
        ),
      );
    }

    testWidgets('renders groups list page title and floating action button',
        (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(groupsCubit));
      await tester.pumpAndSettle();

      expect(find.text('المجموعات الدراسية'), findsOneWidget);
      expect(find.text('مجموعة جديدة'), findsOneWidget);
    });

    testWidgets('renders all group cards and level filter chips', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(groupsCubit));
      await tester.pumpAndSettle();

      expect(find.text('SAT Math Advanced'), findsOneWidget);
      expect(find.text('EST Level 1 Foundation'), findsOneWidget);
      expect(find.text('AP Calculus Intensive'), findsOneWidget);

      // Verify filter chips exist
      expect(find.text('الكل'), findsOneWidget);
      expect(find.text('SAT'), findsWidgets);
      expect(find.text('EST'), findsWidgets);
      expect(find.text('ACT'), findsWidgets);
    });

    testWidgets('renders empty view when groups list is empty', (tester) async {
      AppCache.clearAll();
      fakeRepo.groups = [];
      final emptyCubit = GroupsCubit(repository: fakeRepo);
      await emptyCubit.loadGroups();

      await tester.pumpWidget(createWidgetUnderTest(emptyCubit));
      await tester.pumpAndSettle();

      expect(find.text('لا توجد مجموعات دراسية حتى الآن'), findsOneWidget);
      expect(find.text('إنشاء أول مجموعة'), findsOneWidget);
      await emptyCubit.close();
    });
  });

  group('CreateGroupDialog Widget Tests', () {
    Widget createDialogUnderTest(GroupsCubit cubit) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: Scaffold(
          body: BlocProvider<GroupsCubit>.value(
            value: cubit,
            child: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => CreateGroupDialog.show(ctx),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('opens dialog and allows toggling previous content access',
        (tester) async {
      await tester.pumpWidget(createDialogUnderTest(groupsCubit));
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('إضافة مجموعة دراسية جديدة'), findsOneWidget);
      expect(find.text('اسم المجموعة'), findsOneWidget);
      expect(find.text('مسار أو مستوى المجموعة:'), findsOneWidget);

      // Verify Previous Content Access toggle exists
      expect(find.text('إتاحة المحتوى السابق للطلاب الجدد'), findsOneWidget);

      // Tap on Custom ("مخصص") level to verify dynamic text field appears
      await tester.tap(find.text('مخصص'));
      await tester.pumpAndSettle();

      expect(find.text('المسار أو التصنيف المخصص'), findsOneWidget);
    });
  });
}
