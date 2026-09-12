import '../../../../core/errors/result.dart';
import '../entities/user_entity.dart';

abstract interface class AuthRepository {
  Future<Result<UserEntity>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<UserEntity>> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? parentPhone,
    required String tenantId,
  });

  Future<Result<void>> signOut();

  Future<Result<UserEntity?>> getCurrentUser();

  Future<Result<void>> resetPasswordForEmail(String email);
}
