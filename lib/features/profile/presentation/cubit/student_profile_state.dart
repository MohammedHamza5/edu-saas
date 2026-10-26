import 'package:equatable/equatable.dart';
import '../../domain/entities/student_profile_entity.dart';

sealed class StudentProfileState extends Equatable {
  const StudentProfileState();

  @override
  List<Object?> get props => [];
}

class StudentProfileInitial extends StudentProfileState {
  const StudentProfileInitial();
}

class StudentProfileLoading extends StudentProfileState {
  const StudentProfileLoading();
}

class StudentProfileLoaded extends StudentProfileState {
  final StudentProfileEntity profile;
  final bool isSaving;
  final bool isChangingPassword;
  final bool isUploadingAvatar;
  final String? successMessage;
  final String? errorMessage;

  const StudentProfileLoaded({
    required this.profile,
    this.isSaving = false,
    this.isChangingPassword = false,
    this.isUploadingAvatar = false,
    this.successMessage,
    this.errorMessage,
  });

  StudentProfileLoaded copyWith({
    StudentProfileEntity? profile,
    bool? isSaving,
    bool? isChangingPassword,
    bool? isUploadingAvatar,
    String? successMessage,
    String? errorMessage,
    bool clearMessages = false,
  }) {
    return StudentProfileLoaded(
      profile: profile ?? this.profile,
      isSaving: isSaving ?? this.isSaving,
      isChangingPassword: isChangingPassword ?? this.isChangingPassword,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        profile,
        isSaving,
        isChangingPassword,
        isUploadingAvatar,
        successMessage,
        errorMessage,
      ];
}

class StudentProfileError extends StudentProfileState {
  final String message;

  const StudentProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
