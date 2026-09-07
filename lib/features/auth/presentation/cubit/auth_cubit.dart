import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  AuthCubit({required AuthRepository repository})
      : _repository = repository,
        super(const AuthInitial());

  Future<void> checkAuthStatus() async {
    emit(const AuthLoading());
    final result = await _repository.getCurrentUser();

    result.when(
      onSuccess: (user) {
        if (user == null) {
          emit(const AuthUnauthenticated());
        } else {
          _routeUserByState(user);
        }
      },
      onFailure: (failure) {
        emit(const AuthUnauthenticated());
      },
    );
  }

  Future<void> login({required String email, required String password}) async {
    emit(const AuthLoading());
    final result = await _repository.signInWithEmail(
      email: email,
      password: password,
    );

    result.when(
      onSuccess: (user) {
        _routeUserByState(user);
      },
      onFailure: (failure) {
        if (failure.code == 'TENANT_SUSPENDED') {
          emit(const AuthTenantSuspended());
        } else {
          emit(AuthError(failure.message));
        }
      },
    );
  }

  Future<void> registerStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String tenantId,
  }) async {
    emit(const AuthLoading());
    final result = await _repository.signUpStudent(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      tenantId: tenantId,
    );

    result.when(
      onSuccess: (user) {
        emit(AuthPendingApproval(user));
      },
      onFailure: (failure) {
        emit(AuthError(failure.message));
      },
    );
  }

  Future<void> logout() async {
    emit(const AuthLoading());
    await _repository.signOut();
    emit(const AuthUnauthenticated());
  }

  Future<void> resetPassword(String email) async {
    emit(const AuthLoading());
    final result = await _repository.resetPasswordForEmail(email);

    result.when(
      onSuccess: (_) {
        emit(const AuthPasswordResetSent());
      },
      onFailure: (failure) {
        emit(AuthError(failure.message));
      },
    );
  }

  void _routeUserByState(UserEntity user) {
    switch (user.status) {
      case UserStatus.pending:
        emit(AuthPendingApproval(user));
      case UserStatus.active:
        emit(AuthAuthenticated(user));
      case UserStatus.suspended:
        emit(const AuthError('تم تعليق هذا الحساب. يرجى مراجعة المعلم.'));
      case UserStatus.rejected:
        emit(const AuthError('تم رفض طلب التسجيل لهذا الحساب.'));
    }
  }
}
