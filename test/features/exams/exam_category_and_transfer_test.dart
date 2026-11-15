import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/features/exams/data/models/exam_model.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExamsRepo implements ExamsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldFailMove = false;
  ExamCategory? lastTargetCategory;
  String? lastExamId;

  @override
  Future<Result<ExamEntity>> moveExamCategory({
    required String examId,
    required ExamCategory targetCategory,
  }) async {
    lastExamId = examId;
    lastTargetCategory = targetCategory;

    if (shouldFailMove) {
      return const FailureResult(ServerFailure('Database transfer failed'));
    }

    return Success(
      ExamEntity(
        id: examId,
        contentId: 'content-1',
        tenantId: 'tenant-1',
        groupId: 'group-1',
        title: 'Sample Test',
        category: targetCategory,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }
}

void main() {
  group('ExamCategory Enum & Entity Tests', () {
    test('ExamCategory.fromString handles multiple variations and defaults gracefully', () {
      expect(ExamCategory.fromString('real_test'), ExamCategory.realTest);
      expect(ExamCategory.fromString('realtest'), ExamCategory.realTest);
      expect(ExamCategory.fromString('test'), ExamCategory.realTest);
      expect(ExamCategory.fromString('REAL_TEST'), ExamCategory.realTest);

      expect(ExamCategory.fromString('question_bank'), ExamCategory.questionBank);
      expect(ExamCategory.fromString('bank'), ExamCategory.questionBank);
      expect(ExamCategory.fromString('questionbank'), ExamCategory.questionBank);
      expect(ExamCategory.fromString('QUESTION_BANK'), ExamCategory.questionBank);

      expect(ExamCategory.fromString(null), ExamCategory.realTest);
      expect(ExamCategory.fromString('unknown_val'), ExamCategory.realTest);
    });

    test('ExamCategory value and helper getters work as expected', () {
      expect(ExamCategory.realTest.value, 'real_test');
      expect(ExamCategory.realTest.isRealTest, isTrue);
      expect(ExamCategory.realTest.isQuestionBank, isFalse);

      expect(ExamCategory.questionBank.value, 'question_bank');
      expect(ExamCategory.questionBank.isQuestionBank, isTrue);
      expect(ExamCategory.questionBank.isRealTest, isFalse);
    });

    test('ExamEntity defaults to realTest and copyWith updates category', () {
      final exam = ExamEntity(
        id: 'ex-1',
        contentId: 'c-1',
        tenantId: 't-1',
        groupId: 'g-1',
        title: 'Diagnostic Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(exam.category, ExamCategory.realTest);
      expect(exam.category.isRealTest, isTrue);

      final updated = exam.copyWith(category: ExamCategory.questionBank);
      expect(updated.category, ExamCategory.questionBank);
      expect(updated.category.isQuestionBank, isTrue);
      expect(updated.id, exam.id);
    });
  });

  group('ExamModel Serialization Tests', () {
    test('ExamModel.fromJson parses exam_category correctly', () {
      final json = {
        'id': 'exam-99',
        'content_id': 'content-99',
        'tenant_id': 'tenant-99',
        'group_id': 'group-99',
        'title': 'SAT Practice Questions',
        'exam_category': 'question_bank',
        'duration_minutes': 45,
        'max_score': 80,
        'created_at': '2026-11-13T10:00:00.000Z',
        'updated_at': '2026-11-13T10:00:00.000Z',
      };

      final model = ExamModel.fromJson(json);
      expect(model.id, 'exam-99');
      expect(model.category, ExamCategory.questionBank);
      expect(model.category.isQuestionBank, isTrue);

      final output = model.toJson();
      expect(output['exam_category'], 'question_bank');
    });

    test('ExamModel defaults to real_test when exam_category is omitted', () {
      final json = {
        'id': 'exam-100',
        'content_id': 'content-100',
        'tenant_id': 'tenant-100',
        'group_id': 'group-100',
        'title': 'Official Mock Test 1',
        'created_at': '2026-11-13T10:00:00.000Z',
        'updated_at': '2026-11-13T10:00:00.000Z',
      };

      final model = ExamModel.fromJson(json);
      expect(model.category, ExamCategory.realTest);
      expect(model.category.isRealTest, isTrue);

      final output = model.toJson();
      expect(output['exam_category'], 'real_test');
    });
  });

  group('ExamsCubit Optimistic moveExamCategory Tests', () {
    late _FakeExamsRepo fakeRepo;
    late ExamsCubit cubit;

    setUp(() {
      fakeRepo = _FakeExamsRepo();
      cubit = ExamsCubit(repository: fakeRepo);
    });

    tearDown(() {
      cubit.close();
    });

    test('Optimistically updates exam category in-memory (\$0ms) and succeeds', () async {
      final initialExam = ExamEntity(
        id: 'exam-alpha',
        contentId: 'c-alpha',
        tenantId: 't-1',
        groupId: 'grp-1',
        title: 'Algebra 101',
        category: ExamCategory.realTest,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Seed loaded state
      cubit.emit(
        TeacherExamsLoaded(
          exams: [initialExam],
          groupId: 'grp-1',
        ),
      );

      final success = await cubit.moveExamCategory(
        examId: 'exam-alpha',
        targetCategory: ExamCategory.questionBank,
      );

      expect(success, isTrue);
      expect(fakeRepo.lastExamId, 'exam-alpha');
      expect(fakeRepo.lastTargetCategory, ExamCategory.questionBank);

      final finalState = cubit.state as TeacherExamsLoaded;
      expect(finalState.exams.first.category, ExamCategory.questionBank);
      expect(finalState.exams.first.category.isQuestionBank, isTrue);
    });

    test('Rolls back in-memory category on server failure', () async {
      final initialExam = ExamEntity(
        id: 'exam-beta',
        contentId: 'c-beta',
        tenantId: 't-1',
        groupId: 'grp-1',
        title: 'Calculus Final',
        category: ExamCategory.questionBank,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      cubit.emit(
        TeacherExamsLoaded(
          exams: [initialExam],
          groupId: 'grp-1',
        ),
      );

      fakeRepo.shouldFailMove = true;

      final success = await cubit.moveExamCategory(
        examId: 'exam-beta',
        targetCategory: ExamCategory.realTest,
      );

      expect(success, isFalse);

      final finalState = cubit.state as TeacherExamsLoaded;
      // Verified rollback to original category
      expect(finalState.exams.first.category, ExamCategory.questionBank);
      expect(finalState.message, 'Database transfer failed');
    });
  });
}
