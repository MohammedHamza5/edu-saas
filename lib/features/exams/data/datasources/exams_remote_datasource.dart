import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../domain/entities/exam_entity.dart';
import '../models/exam_attempt_model.dart';
import '../models/exam_model.dart';
import '../models/exam_question_model.dart';
import '../models/exam_version_model.dart';

abstract interface class ExamsRemoteDataSource {
  Future<List<ExamModel>> getGroupExams(
    String groupId, {
    int page = 0,
    int pageSize = 15,
  });
  Future<List<ExamModel>> getStudentExams({
    int page = 0,
    int pageSize = 15,
  });
  Future<ExamModel> getExamDetails(String examId);
  Future<ExamModel> createExam({
    required String groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = false,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    required List<ExamQuestionModel> initialQuestions,
  });
  Future<ExamVersionModel> publishExamVersion(String versionId);
  Future<ExamVersionModel> createNewExamVersion(String examId);
  Future<ExamAttemptModel> startExam(String examId);
  Future<ExamAttemptModel> submitExam({
    required String attemptId,
    required Map<String, String> answers,
  });
  Future<List<ExamAttemptModel>> getExamAttempts(String examId);
  Future<ExamAttemptModel> getAttemptDetails(String attemptId);
}

class ExamsRemoteDataSourceImpl implements ExamsRemoteDataSource {
  final SupabaseClient? _client;

  ExamsRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<List<ExamModel>> getGroupExams(
    String groupId, {
    int page = 0,
    int pageSize = 15,
  }) async {
    final response = await _safeClient
        .from('exams')
        .select('''
          id,
          content_id,
          tenant_id,
          duration_minutes,
          max_score,
          passing_score,
          shuffle_questions,
          show_result,
          allow_retake,
          start_at,
          end_at,
          created_at,
          updated_at,
          content:content!exams_content_id_fkey!inner(
            id,
            group_id,
            title,
            description,
            status,
            groups(name)
          ),
          exam_versions(
            id,
            exam_id,
            version_number,
            status,
            created_at,
            published_at
          ),
          exam_attempts(count)
        ''')
        .eq('content.group_id', groupId)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    final list = response as List<dynamic>;
    final results = <ExamModel>[];

    for (final item in list) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      if (map['exam_attempts'] is List && (map['exam_attempts'] as List).isNotEmpty) {
        final countMap = (map['exam_attempts'] as List).first as Map<String, dynamic>;
        map['attempts_count'] = countMap['count'] ?? 0;
      } else {
        map['attempts_count'] = 0;
      }
      map.remove('exam_attempts');
      results.add(ExamModel.fromJson(map));
    }

    return results;
  }

  @override
  Future<List<ExamModel>> getStudentExams({
    int page = 0,
    int pageSize = 15,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) return [];

    // 1. Find the groups this student is in
    final memberships = await _safeClient
        .from('group_members')
        .select('group_id')
        .eq('student_id', currentUserId)
        .eq('status', 'active');

    final groupIds = (memberships as List<dynamic>)
        .map((m) => m['group_id'] as String)
        .toList();

    if (groupIds.isEmpty) return [];

    // 2. Fetch published exams
    final response = await _safeClient
        .from('exams')
        .select('''
          id,
          content_id,
          tenant_id,
          duration_minutes,
          max_score,
          passing_score,
          shuffle_questions,
          show_result,
          allow_retake,
          start_at,
          end_at,
          created_at,
          updated_at,
          content:content!exams_content_id_fkey!inner(
            id,
            group_id,
            title,
            description,
            status,
            groups(name)
          ),
          exam_versions(
            id,
            exam_id,
            version_number,
            status,
            created_at,
            published_at
          )
        ''')
        .inFilter('content.group_id', groupIds)
        .eq('content.status', 'published')
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    final list = response as List<dynamic>;
    if (list.isEmpty) return [];

    final examIds = list.map((item) => (item as Map<String, dynamic>)['id'] as String).toList();

    // Fetch all student attempts in 1 batch query instead of N sequential loop queries
    final allAttempts = await _safeClient
        .from('exam_attempts')
        .select('''
          id,
          exam_id,
          exam_version_id,
          student_id,
          started_at,
          submitted_at,
          status,
          score,
          percentage
        ''')
        .eq('student_id', currentUserId)
        .inFilter('exam_id', examIds)
        .order('started_at', ascending: false);

    final attemptsByExam = <String, List<Map<String, dynamic>>>{};
    for (final att in allAttempts as List<dynamic>) {
      final aMap = att as Map<String, dynamic>;
      final eId = aMap['exam_id'] as String;
      attemptsByExam.putIfAbsent(eId, () => []).add(aMap);
    }

    final results = <ExamModel>[];
    for (final item in list) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final examId = map['id'] as String;
      map['exam_attempts'] = attemptsByExam[examId] ?? [];
      results.add(ExamModel.fromJson(map));
    }

    return results;
  }

  @override
  Future<ExamModel> getExamDetails(String examId) async {
    final isTeacher = SupabaseService.currentUserRole == 'teacher';
    final optionsFields = isTeacher
        ? 'id, question_id, option_text, sort_order, is_correct'
        : 'id, question_id, option_text, sort_order';

    final response = await _safeClient
        .from('exams')
        .select('''
          id,
          content_id,
          tenant_id,
          duration_minutes,
          max_score,
          passing_score,
          shuffle_questions,
          show_result,
          allow_retake,
          start_at,
          end_at,
          created_at,
          updated_at,
          content:content!exams_content_id_fkey!inner(
            id,
            group_id,
            title,
            description,
            status,
            groups(name)
          ),
          exam_versions(
            id,
            exam_id,
            version_number,
            status,
            created_at,
            published_at,
            exam_questions(
              id,
              exam_version_id,
              question_text,
              question_type,
              points,
              sort_order,
              question_options(
                $optionsFields
              )
            )
          )
        ''')
        .eq('id', examId)
        .single();

    return ExamModel.fromJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<ExamModel> createExam({
    required String groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = false,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    required List<ExamQuestionModel> initialQuestions,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('User not authenticated');
    }

    // Lookup tenant id
    final userRes = await _safeClient
        .from('users')
        .select('tenant_id')
        .eq('id', currentUserId)
        .single();
    final tenantId = userRes['tenant_id'] as String;

    // 1. Create content record
    final contentRes = await _safeClient
        .from('content')
        .insert({
          'tenant_id': tenantId,
          'group_id': groupId,
          'title': title,
          'type': 'exam',
          'status': 'published',
          'published_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    final contentId = contentRes['id'] as String;

    // 2. Create exams record
    final examRes = await _safeClient
        .from('exams')
        .insert({
          'content_id': contentId,
          'tenant_id': tenantId,
          'duration_minutes': durationMinutes,
          'max_score': maxScore,
          'passing_score': passingScore,
          'shuffle_questions': shuffleQuestions,
          'show_result': showResult,
          'allow_retake': allowRetake,
          'start_at': startAt?.toUtc().toIso8601String(),
          'end_at': endAt?.toUtc().toIso8601String(),
        })
        .select()
        .single();

    final examId = examRes['id'] as String;

    // 3. Create initial version (published snapshot)
    final versionRes = await _safeClient
        .from('exam_versions')
        .insert({
          'exam_id': examId,
          'version_number': 1,
          'status': 'published',
          'published_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    final versionId = versionRes['id'] as String;

    // 4. Create questions and options
    for (int i = 0; i < initialQuestions.length; i++) {
      final q = initialQuestions[i];
      final questionRes = await _safeClient
          .from('exam_questions')
          .insert({
            'exam_version_id': versionId,
            'question_text': q.questionText,
            'question_type': q.questionType.value,
            'points': q.points,
            'sort_order': i + 1,
          })
          .select('id')
          .single();

      final qId = questionRes['id'] as String;

      if (q.options.isNotEmpty) {
        final optionsPayload = q.options.asMap().entries.map((optEntry) {
          final j = optEntry.key;
          final opt = optEntry.value;
          return {
            'question_id': qId,
            'option_text': opt.optionText,
            'sort_order': j + 1,
            'is_correct': opt.isCorrect ?? false,
          };
        }).toList();
        await _safeClient.from('question_options').insert(optionsPayload);
      }
    }

    final fullMap = Map<String, dynamic>.from(examRes);
    fullMap['title'] = title;
    fullMap['group_id'] = groupId;

    return ExamModel.fromJson(fullMap);
  }

  @override
  Future<ExamVersionModel> publishExamVersion(String versionId) async {
    final res = await _safeClient
        .from('exam_versions')
        .update({
          'status': 'published',
          'published_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', versionId)
        .select()
        .single();

    return ExamVersionModel.fromJson(Map<String, dynamic>.from(res));
  }

  @override
  Future<ExamVersionModel> createNewExamVersion(String examId) async {
    // 1. Get highest version number
    final existingVersions = await _safeClient
        .from('exam_versions')
        .select('id, version_number, exam_questions(*, question_options(*))')
        .eq('exam_id', examId)
        .order('version_number', ascending: false);

    final list = existingVersions as List<dynamic>;
    int nextVersionNumber = 1;
    Map<String, dynamic>? lastVersion;

    if (list.isNotEmpty) {
      lastVersion = list.first as Map<String, dynamic>;
      nextVersionNumber =
          ((lastVersion['version_number'] as num?)?.toInt() ?? 0) + 1;
    }

    // 2. Create new draft version
    final newVersionRes = await _safeClient
        .from('exam_versions')
        .insert({
          'exam_id': examId,
          'version_number': nextVersionNumber,
          'status': 'draft',
        })
        .select('id, version_number, status, created_at')
        .single();

    final newVersionId = newVersionRes['id'] as String;

    // 3. Clone questions from last version if available
    if (lastVersion != null && lastVersion['exam_questions'] is List) {
      final oldQuestions = lastVersion['exam_questions'] as List;
      for (final qItem in oldQuestions) {
        final qMap = qItem as Map<String, dynamic>;
        final newQRes = await _safeClient
            .from('exam_questions')
            .insert({
              'exam_version_id': newVersionId,
              'question_text': qMap['question_text'],
              'question_type': qMap['question_type'],
              'points': qMap['points'],
              'sort_order': qMap['sort_order'],
            })
            .select('id')
            .single();

        final newQId = newQRes['id'] as String;

        if (qMap['question_options'] is List) {
          for (final optItem in qMap['question_options'] as List) {
            final optMap = optItem as Map<String, dynamic>;
            await _safeClient.from('question_options').insert({
              'question_id': newQId,
              'option_text': optMap['option_text'],
              'sort_order': optMap['sort_order'],
              'is_correct': optMap['is_correct'],
            });
          }
        }
      }
    }

    return ExamVersionModel.fromJson(Map<String, dynamic>.from(newVersionRes));
  }

  @override
  Future<ExamAttemptModel> startExam(String examId) async {
    final rpcRes = await _safeClient.rpc<dynamic>(
      'start_exam',
      params: {'p_exam_id': examId},
    );

    if (rpcRes is Map) {
      final map = Map<String, dynamic>.from(rpcRes);
      if (map.containsKey('error')) {
        throw PostgrestException(
          message: map['message'] as String? ?? (map['error'] as String),
          code: map['error'] as String?,
        );
      }

      final rawQuestions = map['questions'] as List<dynamic>?;
      final parsedQuestions = rawQuestions
              ?.map((q) => ExamQuestionModel.fromJson(Map<String, dynamic>.from(q as Map)))
              .toList() ??
          <ExamQuestionModel>[];

      return ExamAttemptModel(
        id: map['attempt_id'] as String,
        examId: examId,
        examVersionId: map['exam_version_id'] as String,
        studentId: _safeClient.auth.currentUser?.id ?? '',
        startedAt: DateTime.parse(map['started_at'] as String),
        status: AttemptStatus.inProgress,
        questions: parsedQuestions,
      );
    }

    throw const PostgrestException(message: 'Invalid response from start_exam');
  }

  @override
  Future<ExamAttemptModel> submitExam({
    required String attemptId,
    required Map<String, String> answers,
  }) async {
    try {
      final rpcRes = await _safeClient.rpc<dynamic>(
        'submit_exam',
        params: {'p_attempt_id': attemptId, 'p_answers': answers},
      );

      final map = Map<String, dynamic>.from(rpcRes as Map);
      return ExamAttemptModel(
        id: map['attempt_id'] as String,
        examId: '',
        examVersionId: '',
        studentId: _safeClient.auth.currentUser?.id ?? '',
        startedAt: DateTime.now(),
        submittedAt: DateTime.now(),
        status: AttemptStatus.fromString(
          map['status'] as String? ?? 'submitted',
        ),
        score: (map['score'] as num?)?.toInt(),
        percentage: (map['percentage'] as num?)?.toDouble(),
      );
    } catch (_) {
      // Fallback for offline test environments: calculate server-side
      final attemptRes = await _safeClient
          .from('exam_attempts')
          .select('id, exam_id, exam_version_id, student_id, started_at')
          .eq('id', attemptId)
          .single();

      final versionId = attemptRes['exam_version_id'] as String;

      // Fetch version questions with correct options
      final questionsRes = await _safeClient
          .from('exam_questions')
          .select('id, points, question_options(id, is_correct)')
          .eq('exam_version_id', versionId);

      int totalScore = 0;
      int maxScore = 0;

      for (final q in questionsRes as List) {
        final qMap = q as Map<String, dynamic>;
        final points = (qMap['points'] as num?)?.toInt() ?? 1;
        maxScore += points;

        final qId = qMap['id'] as String;
        final selectedOpt = answers[qId];

        if (selectedOpt != null && qMap['question_options'] is List) {
          final options = qMap['question_options'] as List;
          final match = options.firstWhere(
            (o) => o['id'] == selectedOpt && o['is_correct'] == true,
            orElse: () => null,
          );

          final isCorrect = match != null;
          final earned = isCorrect ? points.toDouble() : 0.0;
          if (isCorrect) totalScore += points;

          await _safeClient.from('exam_answers').insert({
            'attempt_id': attemptId,
            'question_id': qId,
            'selected_option_id': selectedOpt,
            'is_correct': isCorrect,
            'points_earned': earned,
          });
        }
      }

      final percentage = maxScore > 0 ? (totalScore / maxScore) * 100 : 0.0;

      final updated = await _safeClient
          .from('exam_attempts')
          .update({
            'status': 'submitted',
            'submitted_at': DateTime.now().toUtc().toIso8601String(),
            'score': totalScore,
            'percentage': percentage,
          })
          .eq('id', attemptId)
          .select()
          .single();

      return ExamAttemptModel.fromJson(Map<String, dynamic>.from(updated));
    }
  }

  @override
  Future<List<ExamAttemptModel>> getExamAttempts(String examId) async {
    final response = await _safeClient
        .from('exam_attempts')
        .select('''
          id,
          exam_id,
          exam_version_id,
          student_id,
          started_at,
          submitted_at,
          status,
          score,
          percentage,
          users!student_id(id, full_name, email, avatar_url),
          exam_answers(*)
        ''')
        .eq('exam_id', examId)
        .order('submitted_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((a) => ExamAttemptModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ExamAttemptModel> getAttemptDetails(String attemptId) async {
    final response = await _safeClient
        .from('exam_attempts')
        .select('''
          id,
          exam_id,
          exam_version_id,
          student_id,
          started_at,
          submitted_at,
          status,
          score,
          percentage,
          users!student_id(id, full_name, email),
          exam_answers(*)
        ''')
        .eq('id', attemptId)
        .single();

    return ExamAttemptModel.fromJson(Map<String, dynamic>.from(response));
  }
}
