import '../../../../core/errors/result.dart';
import '../entities/child_entity.dart';

abstract interface class ParentRepository {
  /// Fetches all children linked to the currently authenticated parent
  Future<Result<List<ChildEntity>>> getLinkedChildren();

  /// Fetches consolidated academic summary (attendance, exams, groups) for a specific child
  Future<Result<ChildAcademicSummary>> getChildAcademicSummary(
    String studentId,
  );
}
