import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/saved_question_entity.dart';

/// Provides pre-populated, high-yield Digital SAT questions for the interactive Demo Sandbox.
/// Showcases spaced repetition, LaTeX math, personal notes, and mastery badges.
abstract class SavedQuestionsDemoSeed {
  static List<SavedQuestionEntity> getSeedQuestions() {
    final now = DateTime.now();

    return [
      SavedQuestionEntity(
        id: 'demo_vault_q1',
        questionId: 'demo_q_quadratic_vertex',
        examId: 'demo_exam_sat_practice',
        examTitle: 'Digital SAT Math Practice #1',
        questionText:
            r'The function $f$ is defined by $f(x) = 2(x - 3)^2 - 8$. For what value of $x$ does $f(x)$ reach its minimum value?',
        options: const [
          QuestionOptionEntity(
            id: 'opt_1a',
            questionId: 'demo_q_quadratic_vertex',
            optionText: 'x = -8',
            sortOrder: 0,
            isCorrect: false,
          ),
          QuestionOptionEntity(
            id: 'opt_1b',
            questionId: 'demo_q_quadratic_vertex',
            optionText: 'x = 3',
            sortOrder: 1,
            isCorrect: true,
          ),
          QuestionOptionEntity(
            id: 'opt_1c',
            questionId: 'demo_q_quadratic_vertex',
            optionText: 'x = -3',
            sortOrder: 2,
            isCorrect: false,
          ),
          QuestionOptionEntity(
            id: 'opt_1d',
            questionId: 'demo_q_quadratic_vertex',
            optionText: 'x = 8',
            sortOrder: 3,
            isCorrect: false,
          ),
        ],
        personalNote:
            'تذكير مهم: صيغة الرأس Vertex Form تعطي x مباشرة بعكس الإشارة داخل القوس وبنفس الإشارة للقيمة الثابتة k. يمكن التحقق بـ Desmos بكتابة الدالة ورؤية أدنى نقطة.',
        difficultyRating: QuestionDifficultyRating.medium,
        savedAt: now.subtract(const Duration(days: 2)),
        reviewCount: 2,
        isMastered: false,
        nextReviewAt: now, // Due today! Activates Spaced Repetition card
        intervalDays: 3,
        userAnswerOptionId: 'opt_1b',
        correctOptionId: 'opt_1b',
        explanation:
            r'Since $a = 2 > 0$, the parabola opens upward. The vertex form is $f(x) = a(x - h)^2 + k$, so the minimum occurs at the vertex $x = h = 3$ and the minimum value is $k = -8$.',
      ),
      SavedQuestionEntity(
        id: 'demo_vault_q2',
        questionId: 'demo_q_linear_system',
        examId: 'demo_exam_sat_practice',
        examTitle: 'Digital SAT Math Practice #1',
        questionText:
            r'In the system of equations $kx - 3y = 4$ and $4x - 6y = 9$, the system has no solution. What is the value of the constant $k$?',
        options: const [
          QuestionOptionEntity(
            id: 'opt_2a',
            questionId: 'demo_q_linear_system',
            optionText: 'k = 2',
            sortOrder: 0,
            isCorrect: true,
          ),
          QuestionOptionEntity(
            id: 'opt_2b',
            questionId: 'demo_q_linear_system',
            optionText: 'k = -2',
            sortOrder: 1,
            isCorrect: false,
          ),
          QuestionOptionEntity(
            id: 'opt_2c',
            questionId: 'demo_q_linear_system',
            optionText: 'k = 4',
            sortOrder: 2,
            isCorrect: false,
          ),
          QuestionOptionEntity(
            id: 'opt_2d',
            questionId: 'demo_q_linear_system',
            optionText: 'k = 6',
            sortOrder: 3,
            isCorrect: false,
          ),
        ],
        personalNote:
            r'قاعدة ذهبية في SAT: No solution تعني الخطوط متوازية: $a_1/a_2 = b_1/b_2 \neq c_1/c_2$. إذن $k/4 = -3/-6 = 1/2 \implies k = 2$.',
        difficultyRating: QuestionDifficultyRating.hard,
        savedAt: now.subtract(const Duration(days: 1)),
        reviewCount: 1,
        isMastered: false,
        nextReviewAt: now.add(const Duration(days: 1)),
        intervalDays: 2,
        userAnswerOptionId: 'opt_2a',
        correctOptionId: 'opt_2a',
        explanation:
            r'For a linear system to have no solution, the lines must be parallel (same slope) but distinct y-intercepts. Equating slopes: $k / (-3) = 4 / (-6) \implies k = 2$.',
      ),
      SavedQuestionEntity(
        id: 'demo_vault_q3',
        questionId: 'demo_q_circle_radius',
        examId: 'demo_exam_sat_practice',
        examTitle: 'Digital SAT Math Practice #1',
        questionText:
            r'A circle in the xy-plane has equation $x^2 + y^2 - 6x + 8y = 0$. What is the radius of the circle?',
        options: const [
          QuestionOptionEntity(
            id: 'opt_3a',
            questionId: 'demo_q_circle_radius',
            optionText: 'r = 5',
            sortOrder: 0,
            isCorrect: true,
          ),
          QuestionOptionEntity(
            id: 'opt_3b',
            questionId: 'demo_q_circle_radius',
            optionText: 'r = 25',
            sortOrder: 1,
            isCorrect: false,
          ),
          QuestionOptionEntity(
            id: 'opt_3c',
            questionId: 'demo_q_circle_radius',
            optionText: 'r = 7',
            sortOrder: 2,
            isCorrect: false,
          ),
          QuestionOptionEntity(
            id: 'opt_3d',
            questionId: 'demo_q_circle_radius',
            optionText: 'r = 10',
            sortOrder: 3,
            isCorrect: false,
          ),
        ],
        personalNote:
            r'حيلة إكمال المربع السريع: نصف معامل x مربعه + نصف معامل y مربعه يعطي $r^2$: $(-3)^2 + 4^2 = 25 \implies r = 5$.',
        difficultyRating: QuestionDifficultyRating.easy,
        savedAt: now.subtract(const Duration(days: 4)),
        reviewCount: 4,
        isMastered: true,
        nextReviewAt: null,
        intervalDays: 7,
        userAnswerOptionId: 'opt_3a',
        correctOptionId: 'opt_3a',
        explanation:
            r'Completing the square gives $(x - 3)^2 + (y + 4)^2 = 3^2 + 4^2 = 25 = 5^2$. Thus the radius is $r = 5$.',
      ),
    ];
  }
}
