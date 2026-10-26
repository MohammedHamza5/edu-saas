import 'dart:convert';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/secure_storage_helper.dart';
import '../../domain/repositories/exam_draft_storage.dart';

/// Local data source to safely persist teacher's in-progress exam creation drafts.
/// Protects against power outages, accidental browser closures, or reloads.
/// Operates with zero database impact and zero risk to existing production workflows.
class ExamDraftLocalDataSource implements ExamDraftStorage {
  static const String _keyPrefix = 'edu_exam_draft_';

  const ExamDraftLocalDataSource();

  /// Persists the draft JSON structure into secure local storage.
  @override
  Future<void> saveDraft({
    required String draftKey,
    required Map<String, dynamic> data,
  }) async {
    try {
      final jsonStr = jsonEncode(data);
      await SecureStorageHelper.write(
        key: '$_keyPrefix$draftKey',
        value: jsonStr,
      );
    } catch (e, st) {
      AppLogger.e(
        'ExamDraftLocalDataSource',
        'Failed to save draft for key $draftKey: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Retrieves the saved draft for the given key, or null if none exists.
  @override
  Future<Map<String, dynamic>?> getDraft(String draftKey) async {
    try {
      final jsonStr = await SecureStorageHelper.read(key: '$_keyPrefix$draftKey');
      if (jsonStr == null || jsonStr.trim().isEmpty) return null;
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (e, st) {
      AppLogger.e(
        'ExamDraftLocalDataSource',
        'Failed to read draft for key $draftKey: $e',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Removes the draft when the exam is successfully created or discarded.
  @override
  Future<void> clearDraft(String draftKey) async {
    try {
      await SecureStorageHelper.delete(key: '$_keyPrefix$draftKey');
    } catch (e, st) {
      AppLogger.e(
        'ExamDraftLocalDataSource',
        'Failed to clear draft for key $draftKey: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Persists student's in-progress answers map into local storage immediately.
  Future<void> saveStudentAnswers({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    try {
      final jsonStr = jsonEncode(answers);
      await SecureStorageHelper.write(
        key: 'edu_student_answers_$attemptId',
        value: jsonStr,
      );
    } catch (e, st) {
      AppLogger.e(
        'ExamDraftLocalDataSource',
        'Failed to save student answers for attempt $attemptId: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Retrieves student's locally saved answers map for the given attempt.
  Future<Map<String, String>> getStudentAnswers(String attemptId) async {
    try {
      final jsonStr = await SecureStorageHelper.read(
        key: 'edu_student_answers_$attemptId',
      );
      if (jsonStr == null || jsonStr.trim().isEmpty) return {};
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
      return {};
    } catch (e, st) {
      AppLogger.e(
        'ExamDraftLocalDataSource',
        'Failed to read student answers for attempt $attemptId: $e',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }

  /// Clears student's saved answers after successful final submission.
  Future<void> clearStudentAnswers(String attemptId) async {
    try {
      await SecureStorageHelper.delete(key: 'edu_student_answers_$attemptId');
    } catch (e, st) {
      AppLogger.e(
        'ExamDraftLocalDataSource',
        'Failed to clear student answers for attempt $attemptId: $e',
        error: e,
        stackTrace: st,
      );
    }
  }
}
