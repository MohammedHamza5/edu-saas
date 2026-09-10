import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/dio_client.dart';
import '../network/supabase_service.dart';
import '../localization/locale_cubit.dart';
import '../theme/tenant_theme_cubit.dart';
import '../utils/app_logger.dart';
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
import '../../features/content/data/datasources/content_remote_datasource.dart';
import '../../features/content/data/repositories/content_repository_impl.dart';
import '../../features/content/domain/repositories/content_repository.dart';
import '../../features/content/presentation/cubit/content_cubit.dart';
import '../../features/videos/data/datasources/videos_remote_datasource.dart';
import '../../features/videos/data/repositories/videos_repository_impl.dart';
import '../../features/videos/domain/repositories/videos_repository.dart';
import '../../features/videos/presentation/cubit/videos_cubit.dart';
import '../../features/assignments/data/datasources/assignments_remote_datasource.dart';
import '../../features/assignments/data/repositories/assignments_repository_impl.dart';
import '../../features/assignments/domain/repositories/assignments_repository.dart';
import '../../features/assignments/presentation/cubit/assignments_cubit.dart';
import '../../features/exams/data/datasources/exams_remote_datasource.dart';
import '../../features/exams/data/repositories/exams_repository_impl.dart';
import '../../features/exams/domain/repositories/exams_repository.dart';
import '../../features/exams/presentation/cubit/exams_cubit.dart';

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

  // Feature: Videos Singletons & Repositories (Bunny Stream)
  static late final VideosRemoteDataSource videosRemoteDataSource;
  static late final VideosRepository videosRepository;

  // Feature: Content Singletons & Repositories
  static late final ContentRemoteDataSource contentRemoteDataSource;
  static late final ContentRepository contentRepository;

  // Feature: Assignments Singletons & Repositories
  static late final AssignmentsRemoteDataSource assignmentsRemoteDataSource;
  static late final AssignmentsRepository assignmentsRepository;

  // Feature: Exams Singletons & Repositories
  static late final ExamsRemoteDataSource examsRemoteDataSource;
  static late final ExamsRepository examsRepository;

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
  static VideosCubit createVideosCubit() =>
      VideosCubit(repository: videosRepository);
  static ContentCubit createContentCubit() =>
      ContentCubit(repository: contentRepository);
  static AssignmentsCubit createAssignmentsCubit() =>
      AssignmentsCubit(repository: assignmentsRepository);
  static ExamsCubit createExamsCubit() =>
      ExamsCubit(repository: examsRepository);
  static TenantThemeCubit createTenantThemeCubit() => TenantThemeCubit();
  static LocaleCubit createLocaleCubit() => LocaleCubit();

  /// Initializes all dependencies in topological dependency order
  static Future<void> init({SupabaseClient? customClient}) async {
    AppLogger.separator('🔧 DI Container Initialization');

    // 1. Core Services
    dioClient = DioClient();
    AppLogger.i('DI', '✅ DioClient ready');

    // 2. Auth Dependencies
    authRemoteDataSource = AuthRemoteDataSourceImpl(client: customClient);
    authRepository = AuthRepositoryImpl(remoteDataSource: authRemoteDataSource);
    AppLogger.i('DI', '✅ Auth layer ready');

    // 3. Groups Dependencies
    groupsRemoteDataSource = GroupsRemoteDataSourceImpl(client: customClient);
    groupsRepository = GroupsRepositoryImpl(remoteDataSource: groupsRemoteDataSource);
    AppLogger.i('DI', '✅ Groups layer ready');

    // 4. Attendance Dependencies
    attendanceRemoteDataSource = AttendanceRemoteDataSourceImpl(client: customClient);
    attendanceRepository = AttendanceRepositoryImpl(remoteDataSource: attendanceRemoteDataSource);
    AppLogger.i('DI', '✅ Attendance layer ready');

    // 5. Students Dependencies
    studentsRemoteDataSource = StudentsRemoteDataSourceImpl(client: customClient);
    studentsRepository = StudentsRepositoryImpl(remoteDataSource: studentsRemoteDataSource);
    AppLogger.i('DI', '✅ Students layer ready');

    // 6. Notifications Dependencies
    notificationsRemoteDataSource = NotificationsRemoteDataSourceImpl(client: customClient);
    notificationsRepository = NotificationsRepositoryImpl(remoteDataSource: notificationsRemoteDataSource);
    AppLogger.i('DI', '✅ Notifications layer ready');

    // 7. Onboarding Dependencies
    onboardingRemoteDataSource = OnboardingRemoteDataSourceImpl(client: customClient);
    onboardingRepository = OnboardingRepositoryImpl(remoteDataSource: onboardingRemoteDataSource);
    AppLogger.i('DI', '✅ Onboarding layer ready');

    // 8. Parent Dependencies
    parentRemoteDataSource = ParentRemoteDataSourceImpl(client: customClient);
    parentRepository = ParentRepositoryImpl(remoteDataSource: parentRemoteDataSource);
    AppLogger.i('DI', '✅ Parent layer ready');

    // 9. Videos Dependencies (Bunny Stream)
    videosRemoteDataSource = VideosRemoteDataSourceImpl(client: customClient);
    videosRepository = VideosRepositoryImpl(remoteDataSource: videosRemoteDataSource);
    AppLogger.i('DI', '✅ Videos layer ready');

    // 10. Content Dependencies
    contentRemoteDataSource = ContentRemoteDataSourceImpl(client: customClient);
    contentRepository = ContentRepositoryImpl(remoteDataSource: contentRemoteDataSource);
    AppLogger.i('DI', '✅ Content layer ready');

    // 11. Assignments Dependencies
    assignmentsRemoteDataSource = AssignmentsRemoteDataSourceImpl(client: customClient);
    assignmentsRepository = AssignmentsRepositoryImpl(remoteDataSource: assignmentsRemoteDataSource);
    AppLogger.i('DI', '✅ Assignments layer ready');

    // 12. Exams Dependencies
    examsRemoteDataSource = ExamsRemoteDataSourceImpl(client: customClient);
    examsRepository = ExamsRepositoryImpl(remoteDataSource: examsRemoteDataSource);
    AppLogger.i('DI', '✅ Exams layer ready');

    AppLogger.s('DI', '🎉 All 12 dependency layers initialized successfully');
  }
}
