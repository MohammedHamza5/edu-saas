import 'package:equatable/equatable.dart';
import '../../domain/entities/provision_tenant_params.dart';
import '../../domain/entities/tenant_entity.dart';

sealed class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

final class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

final class OnboardingLoading extends OnboardingState {
  final String message;
  const OnboardingLoading({this.message = 'جارٍ تهيئة المستأجر وحساب المعلم...'});

  @override
  List<Object?> get props => [message];
}

final class OnboardingSuccess extends OnboardingState {
  final OnboardingResult result;
  const OnboardingSuccess(this.result);

  @override
  List<Object?> get props => [result];
}

final class OnboardingError extends OnboardingState {
  final String message;
  const OnboardingError(this.message);

  @override
  List<Object?> get props => [message];
}

final class TenantsListLoaded extends OnboardingState {
  final List<TenantEntity> tenants;
  const TenantsListLoaded(this.tenants);

  @override
  List<Object?> get props => [tenants];
}
