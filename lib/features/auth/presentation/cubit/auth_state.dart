import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

final class AuthPendingApproval extends AuthState {
  final UserEntity user;
  const AuthPendingApproval(this.user);

  @override
  List<Object?> get props => [user];
}

final class AuthTenantSuspended extends AuthState {
  final String message;
  const AuthTenantSuspended({this.message = 'This institutional account is suspended'});

  @override
  List<Object?> get props => [message];
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

final class AuthError extends AuthState {
  final String message;
  final Failure? failure;
  const AuthError(this.message, {this.failure});

  @override
  List<Object?> get props => [message, failure];
}

final class AuthPasswordResetSent extends AuthState {
  const AuthPasswordResetSent();
}
