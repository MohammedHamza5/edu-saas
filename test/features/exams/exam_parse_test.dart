import 'package:edu_saas/features/exams/data/models/exam_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse exam json with attempts_count object safely', () {
    final rawItem = {
      'id': '1fea2c9c-977e-42c5-a93a-17f46ed3bd74',
      'content_id': '27335428-5e04-4e57-a812-87fed98e12ed',
      'tenant_id': '11111111-1111-1111-1111-111111111111',
      'duration_minutes': 30,
      'max_score': 20,
      'passing_score': 10,
      'shuffle_questions': true,
      'show_result': true,
      'allow_retake': false,
      'start_at': null,
      'end_at': null,
      'created_at': '2026-09-14T15:27:03.67556+00:00',
      'updated_at': '2026-09-14T15:27:03.67556+00:00',
      'content': {
        'id': '27335428-5e04-4e57-a812-87fed98e12ed',
        'title': 'تجريبي',
        'groups': {
          'name': 'SAT Advanced Prep',
        },
        'status': 'published',
        'group_id': '22222222-2222-2222-2222-222222222222',
        'description': null,
      },
      'exam_versions': [
        {
          'id': '64a1f786-4ca9-423c-b5df-d4ef1bd7233e',
          'status': 'published',
          'exam_id': '1fea2c9c-977e-42c5-a93a-17f46ed3bd74',
          'created_at': '2026-09-14T15:27:04.138891+00:00',
          'published_at': '2026-09-14T16:28:38.78+00:00',
          'version_number': 1,
        },
      ],
      'exam_attempts': [
        {
          'count': 0,
        },
      ],
    };

    final map = Map<String, dynamic>.from(rawItem);
    if (map['exam_attempts'] is List && (map['exam_attempts'] as List).isNotEmpty) {
      final countMap = (map['exam_attempts'] as List).first as Map<String, dynamic>;
      map['attempts_count'] = countMap['count'] ?? 0;
    } else {
      map['attempts_count'] = 0;
    }

    final exam = ExamModel.fromJson(map);
    expect(exam.id, '1fea2c9c-977e-42c5-a93a-17f46ed3bd74');
    expect(exam.attemptsCount, 0);
    expect(exam.title, 'تجريبي');
    expect(exam.activeVersion?.versionNumber, 1);
  });
}
