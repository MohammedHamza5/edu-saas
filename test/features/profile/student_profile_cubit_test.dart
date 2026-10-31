import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/features/profile/domain/entities/student_profile_entity.dart';
import 'package:edu_saas/features/profile/domain/repositories/profile_repository.dart';
import 'package:edu_saas/features/profile/presentation/cubit/student_profile_cubit.dart';
import 'package:edu_saas/features/profile/presentation/cubit/student_profile_state.dart';

class FakeProfileRepository implements ProfileRepository {
  StudentProfileEntity? profileToReturn;
  bool shouldFail = false;
  String? updatedFullName;
  String? updatedPhone;
  String? updatedParentPhone;
  String? changedPassword;

  @override
  Future<Result<StudentProfileEntity>> getStudentProfile() async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to fetch profile'));
    }
    return Success(profileToReturn!);
  }

  @override
  Future<Result<StudentProfileEntity>> updateStudentProfile({
    required String fullName,
    String? phone,
    String? parentPhone,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to update'));
    }
    updatedFullName = fullName;
    updatedPhone = phone;
    updatedParentPhone = parentPhone;
    final updated = profileToReturn!.copyWith(
      fullName: fullName,
      phone: phone,
      parentPhone: parentPhone,
    );
    profileToReturn = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> changePassword({required String newPassword}) async {
    if (shouldFail) {
      return const FailureResult(AuthFailure('Failed to change password'));
    }
    changedPassword = newPassword;
    return const Success(null);
  }

  @override
  Future<Result<String>> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    return const Success('https://example.com/avatar.png');
  }
}

void main() {
  late FakeProfileRepository fakeRepo;
  late StudentProfileCubit cubit;

  final initialProfile = StudentProfileEntity(
    id: 'student_123',
    tenantId: 'tenant_abc',
    fullName: 'Omar Khaled',
    email: 'omar@student.com',
    phone: '01012345678',
    parentPhone: '01198765432',
    status: 'active',
    enrolledGroups: const [
      EnrolledGroupSummary(id: 'g1', name: 'SAT Math Basics', level: 'Grade 11'),
    ],
  );

  setUp(() {
    fakeRepo = FakeProfileRepository()..profileToReturn = initialProfile;
    cubit = StudentProfileCubit(repository: fakeRepo);
  });

  tearDown(() {
    cubit.close();
  });

  test('initial state should be StudentProfileInitial', () {
    expect(cubit.state, const StudentProfileInitial());
  });

  test('loadProfile emits Loading then Loaded on success', () async {
    final expected = [
      const StudentProfileLoading(),
      StudentProfileLoaded(profile: initialProfile),
    ];

    expectLater(cubit.stream, emitsInOrder(expected));
    await cubit.loadProfile();
  });

  test('loadProfile emits Loading then Error on failure', () async {
    fakeRepo.shouldFail = true;
    final expected = [
      const StudentProfileLoading(),
      const StudentProfileError('Failed to fetch profile'),
    ];

    expectLater(cubit.stream, emitsInOrder(expected));
    await cubit.loadProfile();
  });

  test('updateProfileInfo updates student full name and parent phone successfully', () async {
    await cubit.loadProfile();

    final success = await cubit.updateProfileInfo(
      fullName: 'Omar K. Mohamed',
      phone: '01099998888',
      parentPhone: '01233334444',
    );

    expect(success, isTrue);
    expect(fakeRepo.updatedFullName, 'Omar K. Mohamed');
    expect(fakeRepo.updatedPhone, '01099998888');
    expect(fakeRepo.updatedParentPhone, '01233334444');

    final state = cubit.state as StudentProfileLoaded;
    expect(state.profile.fullName, 'Omar K. Mohamed');
    expect(state.profile.parentPhone, '01233334444');
    expect(state.successMessage, 'PROFILE_UPDATED_SUCCESS');
  });

  test('changePassword executes repository call and emits successMessage', () async {
    await cubit.loadProfile();

    final success = await cubit.changePassword(newPassword: 'NewSecretPassword123');

    expect(success, isTrue);
    expect(fakeRepo.changedPassword, 'NewSecretPassword123');

    final state = cubit.state as StudentProfileLoaded;
    expect(state.successMessage, 'PASSWORD_CHANGED_SUCCESS');
  });
}
