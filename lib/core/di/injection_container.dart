import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/dio_client.dart';
import '../network/supabase_service.dart';
import '../../features/attendance/data/datasources/attendance_remote_datasource.dart';
import '../../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/attendance/presentation/cubit/attendance_cubit.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/groups/data/datasources/groups_remote_datasource.dart';
import '../../features/groups/data/repositories/groups_repository_impl.dart';
import '../../features/groups/domain/repositories/groups_repository.dart';
import '../../features/groups/presentation/cubit/groups_cubit.dart';
import '../../features/notifications/data/datasources/notifications_remote_datasource.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/onboarding/data/datasources/onboarding_remote_datasource.dart';
import '../../features/onboarding/data/repositories/onboarding_repository_impl.dart';
import '../../features/onboarding/domain/repositories/onboarding_repository.dart';
import '../../features/onboarding/presentation/cubit/onboarding_cubit.dart';
import '../../features/parent/data/datasources/parent_remote_datasource.dart';
import '../../features/parent/data/repositories/parent_repository_impl.dart';
import '../../features/parent/domain/repositories/parent_repository.dart';
import '../../features/parent/presentation/cubit/parent_cubit.dart';
import '../../features/students/data/datasources/students_remote_datasource.dart';
import '../../features/students/data/repositories/students_repository_impl.dart';
import '../../features/students/domain/repositories/students_repository.dart';
import '../../features/students/presentation/cubit/students_cubit.dart';

/// Pure Dart Dependency Injection Container (Composition Root)
/// Enforces Constructor Injection, Inversion of Control, and Zero-Package DI.
class InjectionContainer {
  InjectionContainer._();

  // Core Network Singletons
  static late final DioClient dioClient;
  static SupabaseClient get supabaseClient => SupabaseService.client;

  // Feature: Auth Singletons & Repositories
  static late final AuthRemoteDataSource authRemoteDataSource;
  static late final AuthRepository authRepository;

  // Feature: Groups Singletons & Repositories
  static late final GroupsRemoteDataSource groupsRemoteDataSource;
  static late final GroupsRepository groupsRepository;

  // Feature: Attendance Singletons & Repositories
  static late final AttendanceRemoteDataSource attendanceRemoteDataSource;
  static late final AttendanceRepository attendanceRepository;

  // Feature: Students Singletons & Repositories
  static late final StudentsRemoteDataSource studentsRemoteDataSource;
  static late final StudentsRepository studentsRepository;

  // Feature: Notifications Singletons & Repositories
  static late final NotificationsRemoteDataSource notificationsRemoteDataSource;
  static late final NotificationsRepository notificationsRepository;

  // Feature: Onboarding Singletons & Repositories
  static late final OnboardingRemoteDataSource onboardingRemoteDataSource;
  static late final OnboardingRepository onboardingRepository;

  // Feature: Parent Singletons & Repositories
  static late final ParentRemoteDataSource parentRemoteDataSource;
  static late final ParentRepository parentRepository;

  // Factory methods for Cubits
  static AuthCubit createAuthCubit() => AuthCubit(repository: authRepository);
  static GroupsCubit createGroupsCubit() => GroupsCubit(repository: groupsRepository);
  static AttendanceCubit createAttendanceCubit() =>
      AttendanceCubit(repository: attendanceRepository);
  static StudentsCubit createStudentsCubit() =>
      StudentsCubit(repository: studentsRepository);
  static NotificationsCubit createNotificationsCubit() =>
      NotificationsCubit(repository: notificationsRepository);
  static OnboardingCubit createOnboardingCubit() =>
      OnboardingCubit(repository: onboardingRepository);
  static ParentCubit createParentCubit() =>
      ParentCubit(repository: parentRepository);

  /// Initializes all dependencies in topological dependency order
  static Future<void> init({SupabaseClient? customClient}) async {
    // 1. Core Services
    dioClient = DioClient();

    // 2. Auth Dependencies
    authRemoteDataSource = AuthRemoteDataSourceImpl(client: customClient);
    authRepository = AuthRepositoryImpl(remoteDataSource: authRemoteDataSource);

    // 3. Groups Dependencies
    groupsRemoteDataSource = GroupsRemoteDataSourceImpl(client: customClient);
    groupsRepository = GroupsRepositoryImpl(remoteDataSource: groupsRemoteDataSource);

    // 4. Attendance Dependencies
    attendanceRemoteDataSource = AttendanceRemoteDataSourceImpl(client: customClient);
    attendanceRepository = AttendanceRepositoryImpl(remoteDataSource: attendanceRemoteDataSource);

    // 5. Students Dependencies
    studentsRemoteDataSource = StudentsRemoteDataSourceImpl(client: customClient);
    studentsRepository = StudentsRepositoryImpl(remoteDataSource: studentsRemoteDataSource);

    // 6. Notifications Dependencies
    notificationsRemoteDataSource = NotificationsRemoteDataSourceImpl(client: customClient);
    notificationsRepository = NotificationsRepositoryImpl(remoteDataSource: notificationsRemoteDataSource);

    // 7. Onboarding Dependencies
    onboardingRemoteDataSource = OnboardingRemoteDataSourceImpl(client: customClient);
    onboardingRepository = OnboardingRepositoryImpl(remoteDataSource: onboardingRemoteDataSource);

    // 8. Parent Dependencies
    parentRemoteDataSource = ParentRemoteDataSourceImpl(client: customClient);
    parentRepository = ParentRepositoryImpl(remoteDataSource: parentRemoteDataSource);
  }
}
