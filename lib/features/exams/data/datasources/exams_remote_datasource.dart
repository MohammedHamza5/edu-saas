import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/exam_entity.dart';
import '../../../notifications/domain/services/notification_dispatcher.dart';
import '../models/exam_attempt_model.dart';
import '../models/exam_model.dart';
import '../models/exam_question_model.dart';
import '../models/exam_version_model.dart';
import '../models/exam_parent_dispatch_model.dart';
import '../models/mistake_models.dart';

abstract interface class ExamsRemoteDataSource {
  Future<List<ExamModel>> getGroupExams(
    String groupId, {
    int page = 0,
    int pageSize = 15,
  });
  Future<List<ExamModel>> getStudentExams({int page = 0, int pageSize = 15});
  Future<ExamModel> getExamDetails(String examId);
  Future<ExamModel> createExam({
    String? groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = false,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    bool isPublished = false,
    required List<ExamQuestionModel> initialQuestions,
  });
  Future<ExamModel> updateExam({
    required String examId,
    required String title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
  });
  Future<ExamModel> updateDraftExamQuestions({
    required String examId,
    required String title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
    required List<ExamQuestionModel> questions,
  });
  Future<ExamVersionModel> publishExamVersion(String versionId);
  Future<void> unpublishExamVersion({
    required String examId,
    required String versionId,
  });
  Future<ExamVersionModel> createNewExamVersion(String examId);
  Future<ExamAttemptModel> startExam(String examId);
  Future<ExamAttemptModel> submitExam({
    required String attemptId,
    required Map<String, String> answers,
  });
  Future<List<ExamAttemptModel>> getExamAttempts(String examId);
  Future<ExamAttemptModel> getAttemptDetails(String attemptId);
  Future<MistakeSummaryModel> getStudentMistakesSummary(String studentId);
  Future<List<MistakeQuestionModel>> getStudentMistakesQuestions(
    String studentId, {
    String? examId,
    bool onlyUnresolved = true,
  });
  Future<MistakePracticeResultModel> submitMistakesPractice(
    List<Map<String, String>> answers,
  );
  Future<List<Map<String, dynamic>>> getGroupLessons(String groupId);
  Future<void> linkExamToLesson({
    required String examId,
    required String lessonId,
    required String groupId,
  });
  Future<void> unlinkExamFromLesson({
    required String examId,
    required String groupId,
    bool makeGeneralExam = false,
  });
  Future<void> convertExamType({
    required String examId,
    required String contentId,
    required bool toLectureExam,
    required String groupId,
  });
  Future<Map<String, dynamic>> deleteExam({
    required String examId,
    bool force = false,
  });
  Future<ExamParentDispatchRosterModel> getExamParentDispatchRoster(String examId);
  Future<bool> updateStudentParentPhone({
    required String studentId,
    required String parentPhone,
  });
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
    final examsFuture = _safeClient
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
        .neq('content.status', 'archived')
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    final lessonsFuture = _safeClient
        .from('content_groups')
        .select('content_id, associated_exam_id, content:content!content_groups_content_id_fkey(id, title)')
        .eq('group_id', groupId)
        .not('associated_exam_id', 'is', null)
        .catchError((Object e) {
          AppLogger.w('ExamsRemoteDataSource', 'Could not fetch linked lessons map: $e');
          return <dynamic>[];
        });

    final multiLessonsFuture = _safeClient
        .from('lesson_exams')
        .select('content_id, exam_id, content:content!lesson_exams_content_id_fkey(id, title)')
        .eq('group_id', groupId)
        .catchError((Object _) => <dynamic>[]);

    final parallelRes = await Future.wait([
      examsFuture,
      lessonsFuture,
      multiLessonsFuture,
    ]);

    final response = parallelRes[0];
    final lessonsRes = parallelRes[1] as List<dynamic>;
    final multiLessonsRes = parallelRes[2] as List<dynamic>;

    // Build map of examId -> linked lesson info for this group
    final linkedLessonsMap = <String, Map<String, String>>{};
    for (final item in lessonsRes) {
      final examId = item['associated_exam_id'] as String?;
      final contentMap = item['content'] as Map<String, dynamic>?;
      final lessonId = (item['content_id'] ?? contentMap?['id']) as String?;
      final lessonTitle = contentMap?['title'] as String? ?? '';
      if (examId != null && lessonId != null) {
        linkedLessonsMap[examId] = {
          'lesson_id': lessonId,
          'lesson_title': lessonTitle,
        };
      }
    }

    for (final item in multiLessonsRes) {
      final examId = item['exam_id'] as String?;
      final contentMap = item['content'] as Map<String, dynamic>?;
      final lessonId = (item['content_id'] ?? contentMap?['id']) as String?;
      final lessonTitle = contentMap?['title'] as String? ?? '';
      if (examId != null && lessonId != null) {
        linkedLessonsMap[examId] = {
          'lesson_id': lessonId,
          'lesson_title': lessonTitle,
        };
      }
    }

    final list = response as List<dynamic>;
    final results = <ExamModel>[];

    for (final item in list) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      if (map['exam_attempts'] is List &&
          (map['exam_attempts'] as List).isNotEmpty) {
        final countMap =
            (map['exam_attempts'] as List).first as Map<String, dynamic>;
        map['attempts_count'] = countMap['count'] ?? 0;
      } else {
        map['attempts_count'] = 0;
      }
      map.remove('exam_attempts');

      final examId = map['id'] as String? ?? '';
      final contentMap = map['content'] as Map<String, dynamic>?;
      final desc = (contentMap?['description'] as String? ?? '').trim().toLowerCase();
      final title = (map['title'] as String? ?? contentMap?['title'] as String? ?? '').toLowerCase();

      final linkedInfo = linkedLessonsMap[examId];
      if (linkedInfo != null) {
        map['is_lecture_exam'] = true;
        map['linked_lesson_id'] = linkedInfo['lesson_id'];
        map['linked_lesson_title'] = linkedInfo['lesson_title'];
      } else {
        final isIntendedAsQuiz = desc == 'lecture_quiz' ||
            desc == 'quiz' ||
            title.contains('كويز') ||
            title.contains('quiz') ||
            title.contains('درس') ||
            title.contains('محاضرة');
        map['is_lecture_exam'] = isIntendedAsQuiz;
        map['linked_lesson_id'] = null;
        map['linked_lesson_title'] = null;
      }

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

    // Run exam retrieval and attached quiz filters concurrently
    final examsFuture = _safeClient
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
        .eq('content.status', 'published')
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    final cgFuture = _safeClient
        .from('content_groups')
        .select('associated_exam_id, prerequisite_exam_id')
        .inFilter('group_id', groupIds)
        .catchError((Object _) => <dynamic>[]);

    final cFuture = _safeClient
        .from('content')
        .select('associated_exam_id, prerequisite_exam_id')
        .inFilter('group_id', groupIds)
        .catchError((Object _) => <dynamic>[]);

    final parallelStudentRes = await Future.wait([examsFuture, cgFuture, cFuture]);
    final rawList = parallelStudentRes[0] as List<dynamic>;
    final cgRes = parallelStudentRes[1] as List<dynamic>;
    final cRes = parallelStudentRes[2] as List<dynamic>;

    final lessonExamIds = <String>{};
    for (final row in cgRes) {
      final aId = (row as Map<String, dynamic>)['associated_exam_id'] as String?;
      final pId = row['prerequisite_exam_id'] as String?;
      if (aId != null && aId.isNotEmpty) lessonExamIds.add(aId);
      if (pId != null && pId.isNotEmpty) lessonExamIds.add(pId);
    }
    for (final row in cRes) {
      final aId = (row as Map<String, dynamic>)['associated_exam_id'] as String?;
      final pId = row['prerequisite_exam_id'] as String?;
      if (aId != null && aId.isNotEmpty) lessonExamIds.add(aId);
      if (pId != null && pId.isNotEmpty) lessonExamIds.add(pId);
    }
    if (rawList.isEmpty) return [];

    final list = rawList.where((item) {
      final id = (item as Map<String, dynamic>)['id'] as String?;
      return id != null;
    }).toList();

    if (list.isEmpty) return [];

    final examIds = list
        .map((item) => (item as Map<String, dynamic>)['id'] as String)
        .toList();

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
    try {
      final rpcRes = await _safeClient.rpc<dynamic>(
        'get_exam_details',
        params: {'p_exam_id': examId},
      );
      if (rpcRes is Map<String, dynamic>) {
        return ExamModel.fromJson(rpcRes);
      } else if (rpcRes is Map) {
        return ExamModel.fromJson(Map<String, dynamic>.from(rpcRes));
      }
    } on PostgrestException catch (e) {
      // Fall back to the direct select only if the RPC doesn't exist yet.
      // Any other error (auth, authorization, ...) must surface as-is.
      if (e.code != 'PGRST202' && e.code != '42883') rethrow;
    }

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
            exam_contexts(
              id,
              exam_version_id,
              title,
              context_text,
              image_url,
              image_meta,
              sort_order
            ),
            exam_questions(
              id,
              exam_version_id,
              question_text,
              question_type,
              points,
              sort_order,
              image_url,
              image_meta,
              context_id,
              question_options(
                $optionsFields,
                image_url,
                image_meta
              )
            )
          )
        ''')
        .eq('id', examId)
        .single();

    final map = Map<String, dynamic>.from(response);
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId != null) {
      try {
        final attempts = await _safeClient
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
            .eq('exam_id', examId)
            .eq('student_id', currentUserId)
            .order('started_at', ascending: false);

        map['exam_attempts'] = attempts;
      } catch (_) {}
    }

    return ExamModel.fromJson(map);
  }

  @override
  Future<ExamModel> createExam({
    String? groupId,
    required String title,
    int durationMinutes = 60,
    int maxScore = 100,
    int? passingScore,
    bool shuffleQuestions = false,
    bool showResult = true,
    bool allowRetake = false,
    DateTime? startAt,
    DateTime? endAt,
    bool isPublished = false,
    required List<ExamQuestionModel> initialQuestions,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('User not authenticated');
    }

    final questionsPayload = initialQuestions.asMap().entries.map((entry) {
      final i = entry.key;
      final q = entry.value;
      return {
        'question_text': q.questionText,
        'question_type': q.questionType.value,
        'points': q.points,
        'sort_order': i + 1,
        if (q.imageUrl != null) 'image_url': q.imageUrl,
        if (q.imageMeta != null) 'image_meta': q.imageMeta,
        if (q.contextId != null) 'context_id': q.contextId,
        'options': q.options.asMap().entries.map((optEntry) {
          final j = optEntry.key;
          final opt = optEntry.value;
          return {
            'option_text': opt.optionText,
            'sort_order': j + 1,
            'is_correct': opt.isCorrect ?? false,
            if (opt.imageUrl != null) 'image_url': opt.imageUrl,
            if (opt.imageMeta != null) 'image_meta': opt.imageMeta,
          };
        }).toList(),
      };
    }).toList();

    // Fast-path: Execute atomic database transaction via RPC in < 150ms
    // Eliminates race conditions, duplicate copies, and partial question sets.
    try {
      final rpcRes = await _safeClient.rpc<dynamic>(
        'create_exam_with_questions',
        params: {
          'p_title': title.trim(),
          if (groupId != null && groupId.isNotEmpty) 'p_group_id': groupId,
          'p_duration_minutes': durationMinutes,
          'p_max_score': maxScore,
          if (passingScore != null) 'p_passing_score': passingScore,
          'p_shuffle_questions': shuffleQuestions,
          'p_show_result': showResult,
          'p_allow_retake': allowRetake,
          'p_is_published': isPublished,
          if (startAt != null) 'p_start_at': startAt.toUtc().toIso8601String(),
          if (endAt != null) 'p_end_at': endAt.toUtc().toIso8601String(),
          'p_questions': questionsPayload,
        },
      );

      if (rpcRes != null && rpcRes is Map) {
        final examId = rpcRes['exam_id'] as String?;
        if (examId != null) {
          if (isPublished && groupId != null && groupId.isNotEmpty) {
            unawaited(
              NotificationDispatcher.notifyNewExam(
                title: title,
                groupId: groupId,
                examId: examId,
                maxScore: maxScore,
                durationMinutes: durationMinutes,
              ),
            );
          }
          return getExamDetails(examId);
        }
      }
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202' && e.code != '42883') rethrow;
    }

    // Direct fallback (legacy sequential inserts)
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
          if (groupId != null) 'group_id': groupId,
          'title': title,
          'type': 'exam',
          'status': isPublished ? 'published' : 'draft',
          if (isPublished) 'published_at': DateTime.now().toUtc().toIso8601String(),
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
          'status': isPublished ? 'published' : 'draft',
          if (isPublished) 'published_at': DateTime.now().toUtc().toIso8601String(),
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
            if (q.imageUrl != null) 'image_url': q.imageUrl,
            if (q.imageMeta != null) 'image_meta': q.imageMeta,
            if (q.contextId != null) 'context_id': q.contextId,
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
            if (opt.imageUrl != null) 'image_url': opt.imageUrl,
            if (opt.imageMeta != null) 'image_meta': opt.imageMeta,
          };
        }).toList();
        await _safeClient.from('question_options').insert(optionsPayload);
      }
    }

    final fullMap = Map<String, dynamic>.from(examRes);
    fullMap['title'] = title;
    fullMap['group_id'] = groupId;

    if (isPublished && groupId != null && groupId.isNotEmpty) {
      unawaited(
        NotificationDispatcher.notifyNewExam(
          title: title,
          groupId: groupId,
          examId: examId,
          maxScore: maxScore,
          durationMinutes: durationMinutes,
        ),
      );
    }

    return ExamModel.fromJson(fullMap);
  }

  @override
  Future<ExamModel> updateExam({
    required String examId,
    required String title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('User not authenticated');
    }

    final examRes = await _safeClient
        .from('exams')
        .select('id, content_id')
        .eq('id', examId)
        .single();
    final contentId = examRes['content_id'] as String;

    final contentUpdates = <String, dynamic>{
      'title': title.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (isPublished != null) {
      contentUpdates['status'] = isPublished ? 'published' : 'draft';
      if (isPublished) {
        contentUpdates['published_at'] = DateTime.now().toUtc().toIso8601String();
      }
    }
    await _safeClient.from('content').update(contentUpdates).eq('id', contentId);

    final examUpdates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (durationMinutes != null) examUpdates['duration_minutes'] = durationMinutes;
    if (maxScore != null) examUpdates['max_score'] = maxScore;
    if (passingScore != null) examUpdates['passing_score'] = passingScore;
    if (shuffleQuestions != null) examUpdates['shuffle_questions'] = shuffleQuestions;
    if (showResult != null) examUpdates['show_result'] = showResult;
    if (allowRetake != null) examUpdates['allow_retake'] = allowRetake;
    if (startAt != null) examUpdates['start_at'] = startAt.toUtc().toIso8601String();
    if (endAt != null) examUpdates['end_at'] = endAt.toUtc().toIso8601String();

    await _safeClient.from('exams').update(examUpdates).eq('id', examId);

    if (isPublished == true) {
      await _safeClient
          .from('exam_versions')
          .update({
            'status': 'published',
            'published_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('exam_id', examId)
          .eq('status', 'draft');
    }

    return getExamDetails(examId);
  }

  @override
  Future<ExamModel> updateDraftExamQuestions({
    required String examId,
    required String title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    bool? isPublished,
    required List<ExamQuestionModel> questions,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('User not authenticated');
    }

    final questionsPayload = questions.asMap().entries.map((entry) {
      final i = entry.key;
      final q = entry.value;
      return {
        'question_text': q.questionText,
        'question_type': q.questionType.value,
        'points': q.points,
        'sort_order': i + 1,
        if (q.imageUrl != null) 'image_url': q.imageUrl,
        if (q.imageMeta != null) 'image_meta': q.imageMeta,
        if (q.contextId != null) 'context_id': q.contextId,
        'options': q.options.asMap().entries.map((optEntry) {
          final j = optEntry.key;
          final opt = optEntry.value;
          return {
            'option_text': opt.optionText,
            'sort_order': j + 1,
            'is_correct': opt.isCorrect ?? false,
            if (opt.imageUrl != null) 'image_url': opt.imageUrl,
            if (opt.imageMeta != null) 'image_meta': opt.imageMeta,
          };
        }).toList(),
      };
    }).toList();

    try {
      final rpcRes = await _safeClient.rpc<dynamic>(
        'update_draft_exam_questions',
        params: {
          'p_exam_id': examId,
          'p_title': title.trim(),
          if (durationMinutes != null) 'p_duration_minutes': durationMinutes,
          if (maxScore != null) 'p_max_score': maxScore,
          if (passingScore != null) 'p_passing_score': passingScore,
          if (shuffleQuestions != null) 'p_shuffle_questions': shuffleQuestions,
          if (showResult != null) 'p_show_result': showResult,
          if (allowRetake != null) 'p_allow_retake': allowRetake,
          if (isPublished != null) 'p_is_published': isPublished,
          'p_questions': questionsPayload,
        },
      );
      if (rpcRes != null) {
        return getExamDetails(examId);
      }
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202' && e.code != '42883') rethrow;
    }

    // Direct fallback
    final examRes = await _safeClient
        .from('exams')
        .select('id, content_id')
        .eq('id', examId)
        .single();
    final contentId = examRes['content_id'] as String;

    final contentUpdates = <String, dynamic>{
      'title': title.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (isPublished != null) {
      contentUpdates['status'] = isPublished ? 'published' : 'draft';
      if (isPublished) {
        contentUpdates['published_at'] = DateTime.now().toUtc().toIso8601String();
      }
    }
    await _safeClient.from('content').update(contentUpdates).eq('id', contentId);

    final examUpdates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (durationMinutes != null) examUpdates['duration_minutes'] = durationMinutes;
    if (maxScore != null) examUpdates['max_score'] = maxScore;
    if (passingScore != null) examUpdates['passing_score'] = passingScore;
    if (shuffleQuestions != null) examUpdates['shuffle_questions'] = shuffleQuestions;
    if (showResult != null) examUpdates['show_result'] = showResult;
    if (allowRetake != null) examUpdates['allow_retake'] = allowRetake;
    if (startAt != null) examUpdates['start_at'] = startAt.toUtc().toIso8601String();
    if (endAt != null) examUpdates['end_at'] = endAt.toUtc().toIso8601String();
    await _safeClient.from('exams').update(examUpdates).eq('id', examId);

    final versionsRes = await _safeClient
        .from('exam_versions')
        .select('id, version_number, status')
        .eq('exam_id', examId)
        .order('version_number', ascending: false)
        .limit(1);
    final versionsList = versionsRes as List<dynamic>;

    String versionId;
    if (versionsList.isEmpty) {
      final newVer = await _safeClient
          .from('exam_versions')
          .insert({
            'exam_id': examId,
            'version_number': 1,
            'status': isPublished == true ? 'published' : 'draft',
            if (isPublished == true) 'published_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id')
          .single();
      versionId = newVer['id'] as String;
    } else {
      final latest = versionsList.first as Map<String, dynamic>;
      versionId = latest['id'] as String;
      if (isPublished == true) {
        await _safeClient
            .from('exam_versions')
            .update({
              'status': 'published',
              'published_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', versionId);
      }
    }

    final existingQ = await _safeClient
        .from('exam_questions')
        .select('id')
        .eq('exam_version_id', versionId);
    final qIds = (existingQ as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['id'] as String)
        .toList();

    if (qIds.isNotEmpty) {
      await _safeClient
          .from('question_options')
          .delete()
          .inFilter('question_id', qIds);
    }

    await _safeClient
        .from('exam_questions')
        .delete()
        .eq('exam_version_id', versionId);

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final qRes = await _safeClient
          .from('exam_questions')
          .insert({
            'exam_version_id': versionId,
            'question_text': q.questionText,
            'question_type': q.questionType.value,
            'points': q.points,
            'sort_order': i + 1,
            if (q.imageUrl != null) 'image_url': q.imageUrl,
            if (q.imageMeta != null) 'image_meta': q.imageMeta,
            if (q.contextId != null) 'context_id': q.contextId,
          })
          .select('id')
          .single();
      final qId = qRes['id'] as String;

      if (q.options.isNotEmpty) {
        final optionsPayload = q.options.asMap().entries.map((optEntry) {
          final j = optEntry.key;
          final opt = optEntry.value;
          return {
            'question_id': qId,
            'option_text': opt.optionText,
            'sort_order': j + 1,
            'is_correct': opt.isCorrect ?? false,
            if (opt.imageUrl != null) 'image_url': opt.imageUrl,
            if (opt.imageMeta != null) 'image_meta': opt.imageMeta,
          };
        }).toList();
        await _safeClient.from('question_options').insert(optionsPayload);
      }
    }

    return getExamDetails(examId);
  }

  @override
  Future<ExamVersionModel> publishExamVersion(String versionId) async {
    try {
      final rpcRes = await _safeClient.rpc<dynamic>(
        'publish_exam_version',
        params: {'p_version_id': versionId},
      );
      if (rpcRes != null) {
        final res = await _safeClient
            .from('exam_versions')
            .select('*, exams!inner(content_id)')
            .eq('id', versionId)
            .single();
        final map = Map<String, dynamic>.from(res);
        final examsMap = map['exams'] as Map<String, dynamic>?;
        final contentId = examsMap?['content_id'] as String?;
        if (contentId != null) {
          final now = DateTime.now().toUtc().toIso8601String();
          await _safeClient.from('content').update({
            'status': 'published',
            'published_at': now,
            'updated_at': now,
          }).eq('id', contentId);
        }
        return ExamVersionModel.fromJson(map);
      }
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202' && e.code != '42883') rethrow;
    }

    final res = await _safeClient
        .from('exam_versions')
        .update({
          'status': 'published',
          'published_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', versionId)
        .select('*, exams!inner(content_id)')
        .single();

    final map = Map<String, dynamic>.from(res);
    final examsMap = map['exams'] as Map<String, dynamic>?;
    final contentId = examsMap?['content_id'] as String?;
    if (contentId != null) {
      await _safeClient.from('content').update({
        'status': 'published',
        'published_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', contentId);
    }

    return ExamVersionModel.fromJson(map);
  }

  @override
  Future<void> unpublishExamVersion({
    required String examId,
    required String versionId,
  }) async {
    try {
      await _safeClient.rpc<dynamic>(
        'unpublish_exam',
        params: {
          'p_exam_id': examId,
          'p_version_id': versionId,
        },
      );
      return;
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202' && e.code != '42883') rethrow;
    }

    // Fallback: direct updates
    await _safeClient
        .from('exam_versions')
        .update({'status': 'draft'})
        .eq('id', versionId);

    final examRes = await _safeClient
        .from('exams')
        .select('content_id')
        .eq('id', examId)
        .single();
    final contentId = examRes['content_id'] as String?;
    if (contentId != null) {
      await _safeClient.from('content').update({
        'status': 'draft',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', contentId);
    }
  }

  @override
  Future<ExamVersionModel> createNewExamVersion(String examId) async {
    final res = await _safeClient.rpc<dynamic>(
      'create_exam_version',
      params: {'p_exam_id': examId},
    );
    final map = Map<String, dynamic>.from(res as Map);
    return ExamVersionModel.fromJson(map);
  }

  @override
  Future<List<Map<String, dynamic>>> getGroupLessons(String groupId) async {
    final response = await _safeClient
        .from('content_groups')
        .select('''
          content_id,
          sort_order,
          associated_exam_id,
          content:content!content_groups_content_id_fkey(
            id,
            title,
            type,
            chapter_id
          )
        ''')
        .eq('group_id', groupId)
        .order('sort_order', ascending: true);

    final list = response as List<dynamic>;
    return list.map((item) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final contentMap = map['content'] as Map<String, dynamic>?;
      return {
        'id': (contentMap?['id'] ?? map['content_id']) as String,
        'title': (contentMap?['title'] as String?) ?? 'محاضرة بدون عنوان',
        'type': contentMap?['type'] as String? ?? 'video',
        'sort_order': map['sort_order'] ?? 0,
        'associated_exam_id': map['associated_exam_id'] as String?,
      };
    }).toList();
  }

  @override
  Future<void> linkExamToLesson({
    required String examId,
    required String lessonId,
    required String groupId,
  }) async {
    // 1. Unlink this exam from any other lessons in this group
    await _safeClient
        .from('content_groups')
        .update({'associated_exam_id': null})
        .eq('group_id', groupId)
        .eq('associated_exam_id', examId);

    await _safeClient
        .from('content')
        .update({'associated_exam_id': null})
        .eq('associated_exam_id', examId);

    try {
      await _safeClient
          .from('lesson_exams')
          .delete()
          .eq('group_id', groupId)
          .eq('exam_id', examId);
    } catch (_) {}

    // 2. Link this exam to the target lesson in lesson_exams
    try {
      final tenantRes = await _safeClient
          .from('content')
          .select('tenant_id')
          .eq('id', lessonId)
          .maybeSingle();
      final tenantId = tenantRes?['tenant_id'];
      if (tenantId != null) {
        await _safeClient.from('lesson_exams').upsert({
          'tenant_id': tenantId,
          'group_id': groupId,
          'content_id': lessonId,
          'exam_id': examId,
          'is_required': true,
        });
      }
    } catch (_) {}

    // 3. Link this exam to the target lesson in content_groups for backward compatibility
    final currentCg = await _safeClient
        .from('content_groups')
        .select('associated_exam_id')
        .eq('group_id', groupId)
        .eq('content_id', lessonId)
        .maybeSingle();

    if (currentCg == null || currentCg['associated_exam_id'] == null) {
      await _safeClient
          .from('content_groups')
          .update({'associated_exam_id': examId})
          .eq('group_id', groupId)
          .eq('content_id', lessonId);

      await _safeClient
          .from('content')
          .update({
            'associated_exam_id': examId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', lessonId);
    }

    // 4. Mark the exam's parent content record description as 'lecture_quiz'
    final examRes = await _safeClient
        .from('exams')
        .select('content_id')
        .eq('id', examId)
        .maybeSingle();
    if (examRes != null && examRes['content_id'] != null) {
      await _safeClient
          .from('content')
          .update({'description': 'lecture_quiz'})
          .eq('id', examRes['content_id'] as Object);
    }
  }

  @override
  Future<void> unlinkExamFromLesson({
    required String examId,
    required String groupId,
    bool makeGeneralExam = false,
  }) async {
    // 1. Delete from lesson_exams
    try {
      await _safeClient
          .from('lesson_exams')
          .delete()
          .eq('group_id', groupId)
          .eq('exam_id', examId);
    } catch (_) {}

    // 2. Unlink from content_groups
    await _safeClient
        .from('content_groups')
        .update({'associated_exam_id': null})
        .eq('group_id', groupId)
        .eq('associated_exam_id', examId);

    await _safeClient
        .from('content')
        .update({'associated_exam_id': null})
        .eq('associated_exam_id', examId);

    // 3. If other exams remain for this lesson, promote the first one to associated_exam_id
    try {
      final remaining = await _safeClient
          .from('lesson_exams')
          .select('content_id, exam_id')
          .eq('group_id', groupId)
          .order('sort_order', ascending: true)
          .limit(1);
      if (remaining.isNotEmpty) {
        final nextExamId = remaining.first['exam_id'] as String;
        final contentId = remaining.first['content_id'] as String;
        await _safeClient
            .from('content_groups')
            .update({'associated_exam_id': nextExamId})
            .eq('group_id', groupId)
            .eq('content_id', contentId);
      }
    } catch (_) {}

    if (makeGeneralExam) {
      final examRes = await _safeClient
          .from('exams')
          .select('content_id')
          .eq('id', examId)
          .maybeSingle();
      if (examRes != null && examRes['content_id'] != null) {
        await _safeClient
            .from('content')
            .update({'description': 'general_exam'})
            .eq('id', examRes['content_id'] as Object);
      }
    }
  }

  @override
  Future<void> convertExamType({
    required String examId,
    required String contentId,
    required bool toLectureExam,
    required String groupId,
  }) async {
    if (toLectureExam) {
      await _safeClient
          .from('content')
          .update({'description': 'lecture_quiz'})
          .eq('id', contentId);
    } else {
      await unlinkExamFromLesson(
        examId: examId,
        groupId: groupId,
        makeGeneralExam: true,
      );
      await _safeClient
          .from('content')
          .update({'description': 'general_exam'})
          .eq('id', contentId);
    }
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
      final parsedQuestions =
          rawQuestions
              ?.map(
                (q) => ExamQuestionModel.fromJson(
                  Map<String, dynamic>.from(q as Map),
                ),
              )
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
      final studentId = _safeClient.auth.currentUser?.id ?? '';
      final score = (map['score'] as num?)?.toInt() ?? 0;
      final maxScore = (map['max_score'] as num?)?.toInt() ?? 100;
      final percentage = (map['percentage'] as num?)?.toDouble();
      final pct = percentage?.round() ?? (maxScore > 0 ? ((score / maxScore) * 100).round() : 0);

      if (studentId.isNotEmpty) {
        unawaited(
          NotificationDispatcher.notifyExamResult(
            examTitle: 'الاختبار',
            studentId: studentId,
            score: score,
            maxScore: maxScore,
            percentage: pct,
            attemptId: attemptId,
            examId: map['exam_id'] as String? ?? '',
          ),
        );
      }

      return ExamAttemptModel(
        id: map['attempt_id'] as String,
        examId: map['exam_id'] as String? ?? '',
        examVersionId: '',
        studentId: studentId,
        startedAt: DateTime.now(),
        submittedAt: DateTime.now(),
        status: AttemptStatus.fromString(
          map['status'] as String? ?? 'submitted',
        ),
        score: (map['score'] as num?)?.toInt(),
        percentage: percentage,
      );
    } catch (e, st) {
      AppLogger.e(
        'ExamsRemoteDataSource',
        'submit_exam RPC failed: $e',
        error: e,
        stackTrace: st,
      );
      rethrow;
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
    try {
      final rpcRes = await _safeClient.rpc<dynamic>(
        'get_exam_review',
        params: {'p_attempt_id': attemptId},
      );
      if (rpcRes is Map<String, dynamic>) {
        return ExamAttemptModel.fromJson(rpcRes);
      } else if (rpcRes is Map) {
        return ExamAttemptModel.fromJson(Map<String, dynamic>.from(rpcRes));
      }
    } catch (e) {
      AppLogger.w(
        'ExamsRemoteDataSource',
        'get_exam_review RPC failed, falling back to direct select: $e',
      );
    }

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

  @override
  Future<MistakeSummaryModel> getStudentMistakesSummary(String studentId) async {
    final response = await _safeClient.rpc<dynamic>(
      'get_student_mistakes_summary',
      params: {'p_student_id': studentId},
    );
    if (response is Map) {
      return MistakeSummaryModel.fromJson(Map<String, dynamic>.from(response));
    }
    return const MistakeSummaryModel(
      totalMistakes: 0,
      unresolvedCount: 0,
      resolvedCount: 0,
      sources: [],
    );
  }

  @override
  Future<List<MistakeQuestionModel>> getStudentMistakesQuestions(
    String studentId, {
    String? examId,
    bool onlyUnresolved = true,
  }) async {
    final response = await _safeClient.rpc<dynamic>(
      'get_student_mistakes_questions',
      params: {
        'p_student_id': studentId,
        if (examId != null) 'p_exam_id': examId,
        'p_only_unresolved': onlyUnresolved,
      },
    );
    if (response is List) {
      return response
          .map((q) => MistakeQuestionModel.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList();
    }
    return [];
  }

  @override
  Future<MistakePracticeResultModel> submitMistakesPractice(
    List<Map<String, String>> answers,
  ) async {
    final response = await _safeClient.rpc<dynamic>(
      'submit_mistakes_practice',
      params: {'p_answers': answers},
    );
    if (response is Map) {
      return MistakePracticeResultModel.fromJson(Map<String, dynamic>.from(response));
    }
    throw const PostgrestException(message: 'Invalid response from submit_mistakes_practice');
  }

  @override
  Future<Map<String, dynamic>> deleteExam({
    required String examId,
    bool force = false,
  }) async {
    final response = await _safeClient.rpc<dynamic>(
      'delete_exam',
      params: {
        'p_exam_id': examId,
        'p_force': force,
      },
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {'success': true};
  }

  @override
  Future<ExamParentDispatchRosterModel> getExamParentDispatchRoster(String examId) async {
    try {
      final response = await _safeClient.rpc<dynamic>(
        'get_exam_parent_dispatch_roster',
        params: {'p_exam_id': examId},
      );
      if (response is Map<String, dynamic>) {
        return ExamParentDispatchRosterModel.fromJson(response);
      } else if (response is Map) {
        return ExamParentDispatchRosterModel.fromJson(
          Map<String, dynamic>.from(response),
        );
      }
      throw const PostgrestException(
        message: 'Invalid response from get_exam_parent_dispatch_roster',
      );
    } catch (e) {
      AppLogger.e('ExamsRemoteDataSource', 'getExamParentDispatchRoster failed', error: e);
      rethrow;
    }
  }

  @override
  Future<bool> updateStudentParentPhone({
    required String studentId,
    required String parentPhone,
  }) async {
    try {
      final response = await _safeClient.rpc<dynamic>(
        'update_student_parent_phone',
        params: {
          'p_student_id': studentId,
          'p_parent_phone': parentPhone,
        },
      );
      return response != null;
    } catch (e) {
      AppLogger.e('ExamsRemoteDataSource', 'updateStudentParentPhone failed', error: e);
      rethrow;
    }
  }
}

