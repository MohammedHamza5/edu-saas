import 'dart:typed_data';
import '../../domain/repositories/exams_repository.dart';

/// Fallback no-op repository used when dependency injection container is uninitialized or in testing.
class NoOpExamsRepository implements ExamsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, dynamic>?> getExamDraft(String draftKey) async => null;

  @override
  Future<void> saveExamDraft({
    required String draftKey,
    required Map<String, dynamic> data,
  }) async {}

  @override
  Future<void> clearExamDraft(String draftKey) async {}

  @override
  Future<String> uploadExamImage({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'image/png',
  }) async => '';
}
