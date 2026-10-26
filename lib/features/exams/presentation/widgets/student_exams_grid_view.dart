import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';
import 'exam_card.dart';

/// Responsive Grid of Exam Cards for the Student perspective.
class StudentExamsGridView extends StatelessWidget {
  final List<ExamEntity> exams;
  final void Function(ExamEntity exam) onTapExam;
  final void Function(ExamEntity exam) onReviewExam;

  const StudentExamsGridView({
    super.key,
    required this.exams,
    required this.onTapExam,
    required this.onReviewExam,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        if (width < 640) {
          crossAxisCount = 1;
        } else if (width < 1100) {
          crossAxisCount = 2;
        } else if (width < 1550) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 4;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: AppSpacing.s16,
            mainAxisSpacing: AppSpacing.s16,
            mainAxisExtent: 340,
          ),
          itemCount: exams.length,
          itemBuilder: (context, index) {
            final exam = exams[index];
            return ExamCard(
              exam: exam,
              isTeacher: false,
              isLessonQuiz: false,
              onTap: () => onTapExam(exam),
              onReview: exam.hasAttempted &&
                      exam.myLatestAttempt?.isSubmitted == true
                  ? () => onReviewExam(exam)
                  : null,
            );
          },
        );
      },
    );
  }
}
