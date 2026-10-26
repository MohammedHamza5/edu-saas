import 'dart:typed_data';
import '../../../../core/errors/result.dart';
import '../entities/student_profile_entity.dart';

abstract interface class ProfileRepository {
  /// Fetches the current logged in student's profile along with enrolled groups
  Future<Result<StudentProfileEntity>> getStudentProfile();

  /// Updates student's full name, phone number, and parent phone number
  Future<Result<StudentProfileEntity>> updateStudentProfile({
    required String fullName,
    String? phone,
    String? parentPhone,
  });

  /// Changes the student's account password via Supabase Auth
  Future<Result<void>> changePassword({
    required String newPassword,
  });

  /// Uploads new avatar image and returns the public/signed URL
  Future<Result<String>> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  });
}
