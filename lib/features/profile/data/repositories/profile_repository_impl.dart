import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/network/supabase_service.dart';
import '../../domain/entities/student_profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;

  ProfileRepositoryImpl({ProfileRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? ProfileRemoteDataSourceImpl();

  @override
  Future<Result<StudentProfileEntity>> getStudentProfile() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      return const FailureResult(AuthFailure('No authenticated user session found'));
    }

    try {
      final profile = await _remoteDataSource.getStudentProfile(uid);
      return Success(profile);
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<StudentProfileEntity>> updateStudentProfile({
    required String fullName,
    String? phone,
    String? parentPhone,
  }) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      return const FailureResult(AuthFailure('No authenticated user session found'));
    }

    try {
      final updated = await _remoteDataSource.updateStudentProfile(
        userId: uid,
        fullName: fullName,
        phone: phone,
        parentPhone: parentPhone,
      );
      return Success(updated);
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } on PostgrestException catch (e) {
      return FailureResult(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> changePassword({
    required String newPassword,
  }) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      return const FailureResult(AuthFailure('No authenticated user session found'));
    }

    try {
      await _remoteDataSource.changePassword(newPassword: newPassword);
      return const Success(null);
    } on AuthException catch (e) {
      return FailureResult(AuthFailure(e.message, code: e.statusCode));
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> uploadAvatar({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      return const FailureResult(AuthFailure('No authenticated user session found'));
    }

    try {
      final url = await _remoteDataSource.uploadAvatar(
        userId: uid,
        bytes: bytes,
        fileName: fileName,
      );
      return Success(url);
    } catch (e) {
      return FailureResult(ServerFailure(e.toString()));
    }
  }
}
