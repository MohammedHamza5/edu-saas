import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/dio_client.dart';
import '../network/supabase_service.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';

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

  // Factory methods for Cubits
  static AuthCubit createAuthCubit() => AuthCubit(repository: authRepository);

  /// Initializes all dependencies in topological dependency order
  static Future<void> init({SupabaseClient? customClient}) async {
    // 1. Core Services
    dioClient = DioClient();

    // 2. Auth Dependencies
    authRemoteDataSource = AuthRemoteDataSourceImpl(client: customClient);
    authRepository = AuthRepositoryImpl(remoteDataSource: authRemoteDataSource);
  }
}
