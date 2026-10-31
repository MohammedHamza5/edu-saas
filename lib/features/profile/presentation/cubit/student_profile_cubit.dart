import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/repositories/profile_repository.dart';
import 'student_profile_state.dart';

class StudentProfileCubit extends Cubit<StudentProfileState> {
  final ProfileRepository _repository;

  StudentProfileCubit({required ProfileRepository repository})
      : _repository = repository,
        super(const StudentProfileInitial());

  Future<void> loadProfile() async {
    emit(const StudentProfileLoading());
    final result = await _repository.getStudentProfile();

    result.when(
      onSuccess: (profile) {
        emit(StudentProfileLoaded(profile: profile));
      },
      onFailure: (failure) {
        AppLogger.e('StudentProfileCubit', 'loadProfile failed: ${failure.message}');
        emit(StudentProfileError(failure.message));
      },
    );
  }

  Future<bool> updateProfileInfo({
    required String fullName,
    String? phone,
    String? parentPhone,
  }) async {
    final currentState = state;
    if (currentState is! StudentProfileLoaded) return false;

    emit(currentState.copyWith(isSaving: true, clearMessages: true));

    final result = await _repository.updateStudentProfile(
      fullName: fullName,
      phone: phone,
      parentPhone: parentPhone,
    );

    return result.when(
      onSuccess: (updatedProfile) {
        emit(currentState.copyWith(
          profile: updatedProfile,
          isSaving: false,
          successMessage: 'PROFILE_UPDATED_SUCCESS',
        ));
        return true;
      },
      onFailure: (failure) {
        AppLogger.e('StudentProfileCubit', 'updateProfileInfo failed: ${failure.message}');
        emit(currentState.copyWith(
          isSaving: false,
          errorMessage: failure.message,
        ));
        return false;
      },
    );
  }

  Future<bool> changePassword({
    required String newPassword,
  }) async {
    final currentState = state;
    if (currentState is! StudentProfileLoaded) return false;

    emit(currentState.copyWith(isChangingPassword: true, clearMessages: true));

    final result = await _repository.changePassword(newPassword: newPassword);

    return result.when(
      onSuccess: (_) {
        emit(currentState.copyWith(
          isChangingPassword: false,
          successMessage: 'PASSWORD_CHANGED_SUCCESS',
        ));
        return true;
      },
      onFailure: (failure) {
        AppLogger.e('StudentProfileCubit', 'changePassword failed: ${failure.message}');
        emit(currentState.copyWith(
          isChangingPassword: false,
          errorMessage: failure.message,
        ));
        return false;
      },
    );
  }

  Future<bool> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final currentState = state;
    if (currentState is! StudentProfileLoaded) return false;

    emit(currentState.copyWith(isUploadingAvatar: true, clearMessages: true));

    final result = await _repository.uploadAvatar(bytes: bytes, fileName: fileName);

    return result.when(
      onSuccess: (avatarUrl) {
        final updatedProfile = currentState.profile.copyWith(avatarUrl: avatarUrl);
        emit(currentState.copyWith(
          profile: updatedProfile,
          isUploadingAvatar: false,
          successMessage: 'AVATAR_UPDATED_SUCCESS',
        ));
        return true;
      },
      onFailure: (failure) {
        AppLogger.e('StudentProfileCubit', 'uploadAvatar failed: ${failure.message}');
        emit(currentState.copyWith(
          isUploadingAvatar: false,
          errorMessage: failure.message,
        ));
        return false;
      },
    );
  }

  void clearMessages() {
    if (state is StudentProfileLoaded) {
      emit((state as StudentProfileLoaded).copyWith(clearMessages: true));
    }
  }
}
