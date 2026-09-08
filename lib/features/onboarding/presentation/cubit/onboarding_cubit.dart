import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/provision_tenant_params.dart';
import '../../domain/repositories/onboarding_repository.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final OnboardingRepository _repository;

  OnboardingCubit({required OnboardingRepository repository})
      : _repository = repository,
        super(const OnboardingInitial());

  Future<bool> provisionTenant(ProvisionTenantParams params) async {
    emit(const OnboardingLoading());

    final result = await _repository.provisionTenant(params);

    return result.when(
      onSuccess: (onboardingResult) {
        emit(OnboardingSuccess(onboardingResult));
        return true;
      },
      onFailure: (failure) {
        emit(OnboardingError(failure.message));
        return false;
      },
    );
  }

  Future<void> loadTenants() async {
    emit(const OnboardingLoading(message: 'جارٍ تحميل المستأجرين...'));

    final result = await _repository.listTenants();

    result.when(
      onSuccess: (tenants) {
        emit(TenantsListLoaded(tenants));
      },
      onFailure: (failure) {
        emit(OnboardingError(failure.message));
      },
    );
  }

  void reset() {
    emit(const OnboardingInitial());
  }
}
