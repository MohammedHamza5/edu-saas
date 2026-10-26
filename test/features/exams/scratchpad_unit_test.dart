import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/scratchpad_entity.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepoForScratchpad implements ExamsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('In-Exam Scratchpad Logic Unit Tests', () {
    late ExamsCubit cubit;
    final now = DateTime.now();

    final testExam = ExamEntity(
      id: 'e1', contentId: 'c1', tenantId: 't1', groupId: 'g1', title: 'Math Test',
      durationMinutes: 45, maxScore: 50, passingScore: 25,
      createdAt: now, updatedAt: now,
    );

    const q1 = ExamQuestionEntity(
      id: 'q-1', examVersionId: 'v1', questionText: 'Solve for x: 2x = 8',
      questionType: QuestionType.multipleChoice, points: 5, sortOrder: 0,
      options: [],
    );

    const q2 = ExamQuestionEntity(
      id: 'q-2', examVersionId: 'v1', questionText: 'Calculate area of triangle with b=4, h=3',
      questionType: QuestionType.multipleChoice, points: 5, sortOrder: 1,
      options: [],
    );

    setUp(() {
      cubit = ExamsCubit(repository: _FakeRepoForScratchpad());
    });

    tearDown(() {
      cubit.close();
    });

    ExamTakingState createBaseState({int questionIndex = 0}) {
      return ExamTakingState(
        exam: testExam,
        attempt: ExamAttemptEntity(
          id: 'att-1', examId: 'e1', examVersionId: 'v1', studentId: 's1',
          startedAt: now,
        ),
        questions: const [q1, q2],
        currentQuestionIndex: questionIndex,
        remainingSeconds: 2700,
      );
    }

    test('toggleScratchpad and toggleScratchpadBackground toggle state correctly', () {
      cubit.emit(createBaseState());

      expect((cubit.state as ExamTakingState).isScratchpadOpen, isFalse);
      expect((cubit.state as ExamTakingState).isScratchpadGridBackground, isFalse);

      cubit.toggleScratchpad();
      expect((cubit.state as ExamTakingState).isScratchpadOpen, isTrue);

      cubit.toggleScratchpadBackground();
      expect((cubit.state as ExamTakingState).isScratchpadGridBackground, isTrue);

      cubit.toggleScratchpad(open: false);
      expect((cubit.state as ExamTakingState).isScratchpadOpen, isFalse);
    });

    test('setDrawingTool and setDrawingColor update active drawing attributes', () {
      cubit.emit(createBaseState());

      cubit.setDrawingTool(DrawingTool.highlighter);
      expect((cubit.state as ExamTakingState).activeDrawingTool, equals(DrawingTool.highlighter));

      cubit.setDrawingTool(DrawingTool.eraser);
      expect((cubit.state as ExamTakingState).activeDrawingTool, equals(DrawingTool.eraser));

      cubit.setDrawingColor(const Color(0xFF2563EB));
      expect((cubit.state as ExamTakingState).activeDrawingColor, equals(const Color(0xFF2563EB)));
    });

    test('Strokes persist per-question and support undo and clear', () {
      cubit.emit(createBaseState(questionIndex: 0));

      const stroke1 = DrawingStroke(
        points: [DrawingPoint(offset: Offset(10, 10)), DrawingPoint(offset: Offset(20, 20))],
        tool: DrawingTool.pen,
        color: Color(0xFF1E293B),
        strokeWidth: 2.5,
      );

      const stroke2 = DrawingStroke(
        points: [DrawingPoint(offset: Offset(30, 30))],
        tool: DrawingTool.highlighter,
        color: Color(0xFF2563EB),
        strokeWidth: 16.0,
      );

      // Add 2 strokes to question 1
      cubit.addStrokeToCurrentQuestion(stroke1);
      cubit.addStrokeToCurrentQuestion(stroke2);

      var state = cubit.state as ExamTakingState;
      expect(state.currentQuestionStrokes.length, equals(2));

      // Undo last stroke
      cubit.undoLastStroke();
      state = cubit.state as ExamTakingState;
      expect(state.currentQuestionStrokes.length, equals(1));
      expect(state.currentQuestionStrokes.first, equals(stroke1));

      // Switch to question 2: strokes must be empty for question 2
      cubit.emit(state.copyWith(currentQuestionIndex: 1));
      state = cubit.state as ExamTakingState;
      expect(state.currentQuestionStrokes.isEmpty, isTrue);

      // Add a stroke to question 2
      const strokeQ2 = DrawingStroke(
        points: [DrawingPoint(offset: Offset(100, 100))],
        tool: DrawingTool.pen,
        color: Color(0xFFDC2626),
        strokeWidth: 2.5,
      );
      cubit.addStrokeToCurrentQuestion(strokeQ2);
      state = cubit.state as ExamTakingState;
      expect(state.currentQuestionStrokes.length, equals(1));

      // Switch back to question 1: original stroke1 must be preserved!
      cubit.emit(state.copyWith(currentQuestionIndex: 0));
      state = cubit.state as ExamTakingState;
      expect(state.currentQuestionStrokes.length, equals(1));
      expect(state.currentQuestionStrokes.first, equals(stroke1));

      // Clear question 1 scratchpad
      cubit.clearCurrentQuestionScratchpad();
      state = cubit.state as ExamTakingState;
      expect(state.currentQuestionStrokes.isEmpty, isTrue);

      // Verify question 2 stroke was untouched by clearing question 1
      cubit.emit(state.copyWith(currentQuestionIndex: 1));
      state = cubit.state as ExamTakingState;
      expect(state.currentQuestionStrokes.length, equals(1));
    });
  });
}
