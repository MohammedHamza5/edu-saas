import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/services/student_activity_tracker.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repository;

  static const _tag = 'AuthCubit';

  AuthCubit({required AuthRepository repository})
      : _repository = repository,
        super(const AuthInitial()) {
    AppLogger.i(_tag, 'AuthCubit instantiated');
  }

  UserEntity? get currentUser {
    final s = state;
    if (s is AuthAuthenticated) return s.user;
    if (s is AuthPendingApproval) return s.user;
    return null;
  }

  Future<void> checkAuthStatus() async {
    AppLogger.i(_tag, 'Checking auth status...');
    emit(const AuthLoading());
    final result = await _repository.getCurrentUser();

    result.when(
      onSuccess: (user) {
        if (user == null) {
          SupabaseService.currentRole = null;
          AppLogger.i(_tag, 'No active session — user unauthenticated');
          emit(const AuthUnauthenticated());
        } else {
          AppLogger.i(_tag, 'Active session found', data: {
            'userId': user.id,
            'email': user.email,
            'role': user.role.name,
            'status': user.status.name,
          });
          _routeUserByState(user);
        }
      },
      onFailure: (failure) {
        SupabaseService.currentRole = null;
        AppLogger.w(_tag, 'checkAuthStatus failed — treating as unauthenticated', data: {
          'code': failure.code,
          'message': failure.message,
        });
        emit(const AuthUnauthenticated());
      },
    );
  }

  Future<void> login({required String email, required String password}) async {
    AppLogger.i(_tag, 'Login attempt', data: {'email': email});
    emit(const AuthLoading());
    final result = await _repository.signInWithEmail(
      email: email,
      password: password,
    );

    result.when(
      onSuccess: (user) {
        AppLogger.s(_tag, 'Login successful', data: {
          'userId': user.id,
          'role': user.role.name,
          'status': user.status.name,
        });
        _routeUserByState(user);
      },
      onFailure: (failure) {
        AppLogger.e(_tag, 'Login FAILED', error: '${failure.code}: ${failure.message}');
        if (failure.code == 'TENANT_SUSPENDED') {
          AppLogger.w(_tag, 'Tenant is suspended — emitting AuthTenantSuspended');
          emit(const AuthTenantSuspended());
        } else {
          emit(AuthError(failure.message, failure: failure));
        }
      },
    );
  }

  Future<void> registerStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? parentPhone,
    required String tenantId,
  }) async {
    AppLogger.i(_tag, 'Student registration attempt', data: {
      'email': email,
      'fullName': fullName,
      'tenantId': tenantId,
      if (parentPhone != null) 'parentPhone': parentPhone,
    });
    emit(const AuthLoading());
    final result = await _repository.signUpStudent(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
      parentPhone: parentPhone,
      tenantId: tenantId,
    );

    result.when(
      onSuccess: (user) {
        AppLogger.s(_tag, 'Student registered — awaiting teacher approval', data: {
          'userId': user.id,
          'email': user.email,
        });
        emit(AuthPendingApproval(user));
      },
      onFailure: (failure) {
        AppLogger.e(_tag, 'Student registration FAILED', error: '${failure.code}: ${failure.message}');
        emit(AuthError(failure.message, failure: failure));
      },
    );
  }

  Future<void> logout() async {
    SupabaseService.currentRole = null;
    // Stop student engagement tracking
    StudentActivityTracker.instance.stop();
    // Clear all cached data to prevent stale data across sessions
    AppCache.clearAll();
    AppLogger.i(_tag, 'User logging out...');
    emit(const AuthLoading());
    await _repository.signOut();
    AppLogger.s(_tag, 'User logged out successfully');
    emit(const AuthUnauthenticated());
  }

  Future<void> resetPassword(String email) async {
    AppLogger.i(_tag, 'Password reset requested', data: {'email': email});
    emit(const AuthLoading());
    final result = await _repository.resetPasswordForEmail(email);

    result.when(
      onSuccess: (_) {
        AppLogger.s(_tag, 'Password reset email sent to $email');
        emit(const AuthPasswordResetSent());
      },
      onFailure: (failure) {
        AppLogger.e(_tag, 'Password reset FAILED', error: '${failure.code}: ${failure.message}');
        emit(AuthError(failure.message, failure: failure));
      },
    );
  }

  void _routeUserByState(UserEntity user) {
    SupabaseService.currentRole = user.role.name;
    AppLogger.d(_tag, 'Routing user by status: ${user.status.name}');
    switch (user.status) {
      case UserStatus.pending:
        AppLogger.i(_tag, 'User status: PENDING → waiting for teacher approval');
        emit(AuthPendingApproval(user));
      case UserStatus.active:
        AppLogger.s(_tag, 'User status: ACTIVE → authenticated successfully');
        if (user.role == UserRole.student) {
          StudentActivityTracker.instance.start();
        }
        emit(AuthAuthenticated(user));
      case UserStatus.suspended:
        AppLogger.w(_tag, 'User status: SUSPENDED → blocking access');
        _repository.signOut();
        emit(const AuthError('USER_SUSPENDED'));
      case UserStatus.rejected:
        AppLogger.w(_tag, 'User status: REJECTED → registration was denied');
        _repository.signOut();
        emit(const AuthError('USER_REJECTED'));
    }
  }
}
