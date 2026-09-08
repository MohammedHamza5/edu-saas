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

  // Factory methods for Cubits
  static AuthCubit createAuthCubit() => AuthCubit(repository: authRepository);
  static GroupsCubit createGroupsCubit() => GroupsCubit(repository: groupsRepository);
  static AttendanceCubit createAttendanceCubit() =>
      AttendanceCubit(repository: attendanceRepository);

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
  }
}
