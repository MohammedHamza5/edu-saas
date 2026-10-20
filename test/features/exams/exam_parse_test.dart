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
        'groups': {'name': 'SAT Advanced Prep'},
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
        {'count': 0},
      ],
    };

    final map = Map<String, dynamic>.from(rawItem);
    if (map['exam_attempts'] is List &&
        (map['exam_attempts'] as List).isNotEmpty) {
      final countMap =
          (map['exam_attempts'] as List).first as Map<String, dynamic>;
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

  test('parse exam json with exam_questions count aggregation without crash', () {
    final rawItem = {
      'id': '1fea2c9c-977e-42c5-a93a-17f46ed3bd74',
      'content_id': '27335428-5e04-4e57-a812-87fed98e12ed',
      'tenant_id': '11111111-1111-1111-1111-111111111111',
      'duration_minutes': 45,
      'max_score': 100,
      'created_at': '2026-10-10T12:00:00Z',
      'updated_at': '2026-10-10T12:00:00Z',
      'folder_id': 'f01de960-4444-4444-4444-444444444444',
      'folder': {
        'id': 'f01de960-4444-4444-4444-444444444444',
        'name': 'Algebra & Functions',
        'color': '#5B4FE0',
        'icon': 'folder',
      },
      'content': {
        'id': '27335428-5e04-4e57-a812-87fed98e12ed',
        'title': 'SAT Practice Test 1',
        'groups': {'name': 'SAT Advanced'},
        'status': 'published',
        'group_id': '22222222-2222-2222-2222-222222222222',
      },
      'exam_versions': [
        {
          'id': '64a1f786-4ca9-423c-b5df-d4ef1bd7233e',
          'status': 'published',
          'exam_id': '1fea2c9c-977e-42c5-a93a-17f46ed3bd74',
          'version_number': 1,
          'exam_questions': [
            {'count': 15},
          ],
        },
      ],
      'exam_attempts': [
        {'count': 3},
      ],
    };

    final exam = ExamModel.fromJson(rawItem);
    expect(exam.id, '1fea2c9c-977e-42c5-a93a-17f46ed3bd74');
    expect(exam.title, 'SAT Practice Test 1');
    expect(exam.groupName, 'SAT Advanced');
    expect(exam.folderId, 'f01de960-4444-4444-4444-444444444444');
    expect(exam.folderName, 'Algebra & Functions');
    expect(exam.activeVersion?.versionNumber, 1);
    expect(exam.activeVersion?.questions.isEmpty, true);
    expect(exam.questionsCount, 15);
  });

  test('parse all real group exams from TEST-TEST 2 without type errors', () {
    final rawList = [
      {
        'id': '84864849-fa1f-4543-9e96-fab02d033762',
        'content_id': 'f82f0dcf-623e-456c-a0fc-77bd0fbef7dc',
        'tenant_id': '11111111-1111-1111-1111-111111111111',
        'duration_minutes': 0,
        'max_score': 10,
        'passing_score': 6,
        'shuffle_questions': true,
        'show_result': true,
        'allow_retake': false,
        'start_at': null,
        'end_at': null,
        'created_at': '2026-10-01 18:23:29.036676+00',
        'updated_at': '2026-10-05 20:02:53.549989+00',
        'folder_id': null,
        'folder': null,
        'content': {
          'id': 'f82f0dcf-623e-456c-a0fc-77bd0fbef7dc',
          'group_id': '41c2bce0-88c4-4f9f-b75c-27dd4de60506',
          'title': 'Test',
          'description': null,
          'status': 'draft',
          'groups': {'name': 'TEST-TEST 2'}
        },
        'exam_versions': [
          {
            'id': 'b3c8140b-cc22-4200-b961-d93990b373a1',
            'exam_id': '84864849-fa1f-4543-9e96-fab02d033762',
            'version_number': 1,
            'status': 'draft',
            'created_at': '2026-10-01T18:23:29.455132+00:00',
            'published_at': '2026-10-01T19:25:11.554+00:00',
            'exam_questions': [
              {'count': 1}
            ]
          }
        ],
        'exam_attempts': [
          {'count': 3}
        ]
      },
      {
        'id': '81dd2c58-40d2-4bcf-b6e2-8325ddffb7cf',
        'content_id': '1182840c-7b23-40df-865b-17823aa36910',
        'tenant_id': '11111111-1111-1111-1111-111111111111',
        'duration_minutes': 0,
        'max_score': 10,
        'passing_score': 6,
        'shuffle_questions': true,
        'show_result': true,
        'allow_retake': false,
        'start_at': null,
        'end_at': null,
        'created_at': '2026-10-01 19:02:11.023514+00',
        'updated_at': '2026-10-05 20:02:53.549989+00',
        'folder_id': null,
        'folder': null,
        'content': {
          'id': '1182840c-7b23-40df-865b-17823aa36910',
          'group_id': '41c2bce0-88c4-4f9f-b75c-27dd4de60506',
          'title': 'Test',
          'description': null,
          'status': 'published',
          'groups': {'name': 'TEST-TEST 2'}
        },
        'exam_versions': [
          {
            'id': '58dc2ed7-5bcd-4b71-80e9-6634d71f4e8c',
            'exam_id': '81dd2c58-40d2-4bcf-b6e2-8325ddffb7cf',
            'version_number': 1,
            'status': 'published',
            'created_at': '2026-10-01T19:02:11.301172+00:00',
            'published_at': '2026-10-01T20:03:53.467+00:00',
            'exam_questions': [
              {'count': 2}
            ]
          },
          {
            'id': '434df22d-6bde-453d-9645-38dc1c63cae7',
            'exam_id': '81dd2c58-40d2-4bcf-b6e2-8325ddffb7cf',
            'version_number': 2,
            'status': 'draft',
            'created_at': '2026-10-10T15:29:25.980163+00:00',
            'published_at': null,
            'exam_questions': [
              {'count': 2}
            ]
          }
        ],
        'exam_attempts': [
          {'count': 4}
        ]
      }
    ];

    for (final item in rawList) {
      final exam = ExamModel.fromJson(item);
      expect(exam.id.isNotEmpty, true);
      expect(exam.groupName, 'TEST-TEST 2');
    }
  });

  test('parse get_exam_details response with root questions and populate activeVersion', () {
    final rpcDetails = {
      'id': 'dcacbf7f-2100-4b17-9a47-a857151bb548',
      'content_id': 'bd703631-ca79-48bd-8efc-72650c518d55',
      'title': 'تجريب PDF',
      'description': null,
      'group_id': '41c2bce0-88c4-4f9f-b75c-27dd4de60506',
      'group_name': 'TEST-TEST 2',
      'status': 'published',
      'duration_minutes': 8,
      'max_score': 24,
      'passing_score': 14,
      'shuffle_questions': true,
      'show_result': true,
      'allow_retake': true,
      'pdf_file_id': '5ed8ebac-9760-47c7-be35-f1457ef529d4',
      'pdf_file_name': 'facebook-page-service-offer.pdf',
      'pdf_file_size': 115617,
      'pdf_storage_path': 'materials/1111/test.pdf',
      'pdf_storage_provider': 'supabase',
      'created_at': '2026-10-19T23:56:11.697943+00:00',
      'version_id': 'a62f87d8-ab84-4f26-9f13-30c0d4b9bc70',
      'version_number': 1,
      'version_status': 'published',
      'contexts': <Map<String, dynamic>>[],
      'questions': [
        {
          'id': 'q1',
          'points': 8,
          'sort_order': 1,
          'question_text': '',
          'question_type': 'multiple_choice',
          'image_url': 'https://example.com/q1.webp',
          'options': [
            {'id': 'o1', 'option_text': 'A', 'sort_order': 1, 'is_correct': true},
            {'id': 'o2', 'option_text': 'B', 'sort_order': 2, 'is_correct': false},
          ],
        },
        {
          'id': 'q2',
          'points': 8,
          'sort_order': 2,
          'question_text': '',
          'question_type': 'multiple_choice',
          'image_url': 'https://example.com/q2.webp',
          'options': [
            {'id': 'o3', 'option_text': 'A', 'sort_order': 1, 'is_correct': true},
          ],
        },
        {
          'id': 'q3',
          'points': 8,
          'sort_order': 3,
          'question_text': '',
          'question_type': 'multiple_choice',
          'image_url': 'https://example.com/q3.webp',
          'options': [
            {'id': 'o4', 'option_text': 'A', 'sort_order': 1, 'is_correct': true},
          ],
        },
      ],
    };

    final exam = ExamModel.fromJson(rpcDetails);
    expect(exam.id, 'dcacbf7f-2100-4b17-9a47-a857151bb548');
    expect(exam.title, 'تجريب PDF');
    expect(exam.pdfStorageProvider, 'supabase');
    expect(exam.hasAttachedPdf, true);
    expect(exam.activeVersion, isNotNull);
    expect(exam.activeVersion?.id, 'a62f87d8-ab84-4f26-9f13-30c0d4b9bc70');
    expect(exam.activeVersion?.questions.length, 3);
    expect(exam.questionsCount, 3);
    expect(exam.totalQuestions, 3);
    expect(exam.activeVersion?.questions.first.imageUrl, 'https://example.com/q1.webp');
  });

  test('parse get_student_exams with student_score and active attempt preserves completed score', () {
    final rpcStudentExam = {
      'id': '8b09c8ec-9d6d-4cdb-a3be-1f5f744e99fe',
      'title': 'تجربة الاله',
      'end_at': null,
      'status': 'published',
      'group_id': '41c2bce0-88c4-4f9f-b75c-27dd4de60506',
      'start_at': null,
      'folder_id': '980f7e6b-be25-45d0-81b2-11cb9d5e8810',
      'max_score': 10,
      'best_score': 10,
      'my_best_score': 10,
      'student_score': 10,
      'my_best_percentage': 100,
      'student_percentage': 100,
      'passing_score': 6,
      'has_passed': true,
      'attempts_count': 3,
      'has_active_attempt': true,
      'latest_attempt_id': '7b7bf502-3abd-4bd2-8483-00b800f06d59',
      'latest_attempt_status': 'in_progress',
      'my_latest_attempt': {
        'id': '7b7bf502-3abd-4bd2-8483-00b800f06d59',
        'score': null,
        'status': 'in_progress',
        'percentage': null,
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'submitted_at': null,
      },
    };

    final exam = ExamModel.fromJson(rpcStudentExam);
    expect(exam.id, '8b09c8ec-9d6d-4cdb-a3be-1f5f744e99fe');
    expect(exam.myBestScore, 10);
    expect(exam.attemptsCount, 3);
    expect(exam.hasPassed, true);
    expect(exam.hasActiveAttempt, true);
    expect(exam.hasAttempted, true);
    expect(exam.myLatestAttempt, isNotNull);
    expect(exam.myLatestAttempt?.isInProgress, true);
  });
}
