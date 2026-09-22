import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/secure_storage_helper.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl({AuthRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? AuthRemoteDataSourceImpl();

  @override
  Future<Result<UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      );

      // Securely store token
      final session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        await SecureStorageHelper.write(
          key: 'access_token',
          value: session.accessToken,
        );
        if (session.refreshToken != null) {
          await SecureStorageHelper.write(
            key: 'refresh_token',
            value: session.refreshToken!,
          );
        }
      }

      return Success(user);
    } on AuthException catch (e) {
      if (e.message == 'TENANT_SUSPENDED') {
        return const FailureResult(AuthFailure('TENANT_SUSPENDED', code: 'TENANT_SUSPENDED'));
      }
      return FailureResult(AuthFailure(e.message, code: e.code ?? e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<UserEntity>> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? parentPhone,
    required String tenantId,
  }) async {
    try {
      final user = await _remoteDataSource.signUpStudent(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        parentPhone: parentPhone,
        tenantId: tenantId,
      );
      return Success(user);
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.code ?? e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      await SecureStorageHelper.clearAll();
      return const Success(null);
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<UserEntity?>> getCurrentUser() async {
    try {
      final user = await _remoteDataSource.getCurrentUserProfile();
      return Success(user);
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> resetPasswordForEmail(String email) async {
    try {
      await _remoteDataSource.resetPassword(email);
      return const Success(null);
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.code ?? e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
