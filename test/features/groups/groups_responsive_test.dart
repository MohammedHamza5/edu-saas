import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/groups/domain/entities/group_entity.dart';
import 'package:edu_saas/features/groups/domain/entities/group_member_entity.dart';
import 'package:edu_saas/features/groups/domain/repositories/groups_repository.dart';
import 'package:edu_saas/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:edu_saas/features/groups/presentation/pages/group_detail_page.dart';
import 'package:edu_saas/features/groups/presentation/pages/groups_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGroupsRepository implements GroupsRepository {
  List<GroupEntity> groups = [
    GroupEntity(
      id: 'grp-sat-1',
      tenantId: '11111111-1111-1111-1111-111111111111',
      name: 'SAT Math Advanced Section A',
      level: 'SAT',
      description: 'Advanced algebra, complex equations, and test strategies',
      previousContentAccess: 'allow',
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      membersCount: 12,
    ),
    GroupEntity(
      id: 'grp-est-1',
      tenantId: '11111111-1111-1111-1111-111111111111',
      name: 'EST I Intensive Group',
      level: 'EST',
      description: 'Comprehensive EST I curriculum with focus on problem solving',
      previousContentAccess: 'deny',
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      membersCount: 8,
    ),
    GroupEntity(
      id: 'grp-act-1',
      tenantId: '11111111-1111-1111-1111-111111111111',
      name: 'ACT Basics Track',
      level: 'ACT',
      description: 'Geometry and trigonometry foundational concepts',
      previousContentAccess: 'allow',
      status: 'active',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      membersCount: 5,
    ),
  ];

  Map<String, List<GroupMemberEntity>> membersByGroup = {
    'grp-sat-1': [
      GroupMemberEntity(
        id: 'mem-1',
        groupId: 'grp-sat-1',
        studentId: 'std-1',
        studentName: 'أحمد محمود الشرقاوي',
        studentEmail: 'ahmed.sharqawy@example.com',
        joinedAt: DateTime.now().subtract(const Duration(days: 10)),
        status: 'active',
      ),
      GroupMemberEntity(
        id: 'mem-2',
        groupId: 'grp-sat-1',
        studentId: 'std-2',
        studentName: 'سارة خالد الدسوقي',
        studentEmail: 'sara.khalid@example.com',
        joinedAt: DateTime.now().subtract(const Duration(days: 8)),
        status: 'active',
      ),
    ],
  };

  @override
  Future<Result<List<GroupEntity>>> getGroups() async => Success(List.from(groups));

  @override
  Future<Result<GroupEntity>> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  }) async {
    final g = GroupEntity(
      id: 'grp-new',
      tenantId: '11111111-1111-1111-1111-111111111111',
      name: name,
      level: level,
      description: description,
      previousContentAccess: previousContentAccess,
      status: 'active',
      createdAt: DateTime.now(),
      membersCount: 0,
    );
    groups.add(g);
    return Success(g);
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
    final idx = groups.indexWhere((g) => g.id == id);
    if (idx == -1) return Success(groups.first);
    return Success(groups[idx]);
  }

  @override
  Future<Result<List<GroupMemberEntity>>> getGroupMembers(String groupId) async =>
      Success(membersByGroup[groupId] ?? []);

  @override
  Future<Result<GroupMemberEntity>> addMemberToGroup({
    required String groupId,
    required String studentId,
  }) async {
    final m = GroupMemberEntity(
      id: 'mem-new',
      groupId: groupId,
      studentId: studentId,
      studentName: 'طالب جديد',
      studentEmail: 'new@example.com',
      joinedAt: DateTime.now(),
      status: 'active',
    );
    return Success(m);
  }

  @override
  Future<Result<void>> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  }) async => const Success(null);
}

void main() {
  final testViewports = <String, Size>{
    '320x640': const Size(320, 640),
    '390x844': const Size(390, 844),
    '768x1024': const Size(768, 1024),
    '1440x900': const Size(1440, 900),
    '1920x1080': const Size(1920, 1080),
  };

  Widget buildTestWidget({
    required Widget child,
    required GroupsCubit cubit,
    required Size size,
  }) {
    return MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
        child: BlocProvider<GroupsCubit>.value(
          value: cubit,
          child: child,
        ),
      ),
    );
  }

  group('GroupsListPage Multi-Device Responsive Tests', () {
    for (final entry in testViewports.entries) {
      testWidgets('Renders GroupsListPage cleanly on ${entry.key} with zero overflow',
          (tester) async {
        final repo = _FakeGroupsRepository();
        final cubit = GroupsCubit(repository: repo);

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          cubit.close();
        });

        await tester.pumpWidget(
          buildTestWidget(
            child: const GroupsListPage(),
            cubit: cubit,
            size: entry.value,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GroupsListPage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('GroupDetailPage Multi-Device Responsive Tests', () {
    for (final entry in testViewports.entries) {
      testWidgets('Renders GroupDetailPage cleanly on ${entry.key} with zero overflow',
          (tester) async {
        final repo = _FakeGroupsRepository();
        final cubit = GroupsCubit(repository: repo);

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          cubit.close();
        });

        await tester.pumpWidget(
          buildTestWidget(
            child: GroupDetailPage(
              groupId: 'grp-sat-1',
              initialGroup: repo.groups.first,
            ),
            cubit: cubit,
            size: entry.value,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
