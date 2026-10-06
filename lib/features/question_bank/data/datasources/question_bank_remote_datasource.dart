import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/question_revision_entity.dart';
import '../../domain/entities/validation_issue_entity.dart';

abstract class QuestionBankRemoteDataSource {
  // ── Document operations ──
  Future<List<DocumentEntity>> getDocuments();
  Future<DocumentEntity> getDocumentById(String documentId);
  Future<List<QuestionEntity>> getQuestionsByDocument(
    String documentId, {
    String? statusFilter,
  });
  Future<void> deleteDocument(String documentId);
  Future<void> deleteQuestion(String questionId);
  Future<String> retryDocumentIngestion(String documentId);

  // ── Question operations ──
  Future<List<QuestionEntity>> getQuestions({
    String? statusFilter,
    bool sortByPriority = false,
  });
  Future<QuestionEntity> getQuestionById(String questionId);
  Future<QuestionRevisionEntity?> getLatestRevision(String questionId);
  Future<List<QuestionRevisionEntity>> getRevisionHistory(String questionId);
  Future<List<ValidationIssueEntity>> getValidationIssues(String revisionId);
  Future<void> acknowledgeIssue({
    required String revisionId,
    required String issueId,
    String? rationale,
  });
  Future<QuestionRevisionEntity> editBlock({
    required String questionId,
    required String blockId,
    required String newValue,
    required String reason,
  });
  Future<QuestionRevisionEntity> selectAnswer({
    required String questionId,
    required String selectedKey,
  });
  Future<void> mergeWithNext({required String questionId});
  Future<void> splitQuestion({
    required String questionId,
    required int splitIndex,
  });
  Future<void> markSourceUnreadable({
    required String questionId,
    required String reason,
  });
  Future<QuestionRevisionEntity> restoreRevision({
    required String questionId,
    required String revisionId,
  });
  Future<void> sampleSecondReview({required String questionId});
  Future<String> createManualQuestion({
    required String sourceLabel,
    required String questionType,
    required String stemText,
    required List<Map<String, dynamic>> options,
    required String correctAnswer,
    required Map<String, dynamic> rightsAttestation,
    String? imageUrl,
    Map<String, dynamic>? imageMeta,
  });
  Future<void> approveRevision({
    required String revisionId,
    required String contentHash,
    List<String>? acknowledgedIssueIds,
  });
  Future<void> publishRevision({required String revisionId});
  Future<List<QuestionEntity>> ingestExamDocument({
    required String filename,
    required List<int> bytes,
    String? answerKeyFilename,
    required Map<String, dynamic> rightsAttestation,
  });
  Future<Map<String, dynamic>> getJobStatus(String jobId);
  Future<String> createExamFromQuestions({
    required String groupId,
    required String title,
    required int durationMinutes,
    required List<QuestionEntity> questions,
  });
}

class QuestionBankRemoteDataSourceImpl implements QuestionBankRemoteDataSource {
  final SupabaseClient supabaseClient;

  QuestionBankRemoteDataSourceImpl({required this.supabaseClient});

  // ════════════════════════════════════════════════════════════════════════════
  // Document-Level Operations
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Future<List<DocumentEntity>> getDocuments() async {
    // Fetch documents with question count via a subquery approach
    final response = await supabaseClient
        .from('qb_documents')
        .select()
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    final documents = <DocumentEntity>[];

    for (final json in list) {
      final doc = _mapDocument(json as Map<String, dynamic>);
      // Get question count for each document
      final countResponse = await supabaseClient
          .from('qb_questions')
          .select('id')
          .eq('document_id', doc.id);
      final questionCount = (countResponse as List<dynamic>).length;
      documents.add(doc.copyWith(questionCount: questionCount));
    }

    return documents;
  }

  @override
  Future<DocumentEntity> getDocumentById(String documentId) async {
    final response = await supabaseClient
        .from('qb_documents')
        .select()
        .eq('id', documentId)
        .single();

    final doc = _mapDocument(response);
    final countResponse = await supabaseClient
        .from('qb_questions')
        .select('id')
        .eq('document_id', doc.id);
    final questionCount = (countResponse as List<dynamic>).length;
    return doc.copyWith(questionCount: questionCount);
  }

  @override
  Future<List<QuestionEntity>> getQuestionsByDocument(
    String documentId, {
    String? statusFilter,
  }) async {
    var query = supabaseClient
        .from('qb_questions')
        .select()
        .eq('document_id', documentId);

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    final response = await query.order('created_at', ascending: true);
    final list = response as List<dynamic>;
    return list
        .map((json) => _mapQuestion(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    await supabaseClient.rpc<void>(
      'delete_qb_document',
      params: {'p_document_id': documentId},
    );
  }

  @override
  Future<void> deleteQuestion(String questionId) async {
    await supabaseClient.rpc<void>(
      'delete_qb_question',
      params: {'p_question_id': questionId},
    );
  }

  @override
  Future<String> retryDocumentIngestion(String documentId) async {
    // 1. Get the document to retrieve its info
    final docRes = await supabaseClient
        .from('qb_documents')
        .select()
        .eq('id', documentId)
        .single();

    final tenantId = docRes['tenant_id'] as String;
    final storagePath = docRes['storage_path'] as String? ?? '';
    final filename = docRes['original_filename'] as String;
    final uploaderId = docRes['uploader_id'] as String?;
    final sha256 = docRes['sha256'] as String;

    // 2. Reset document status
    await supabaseClient
        .from('qb_documents')
        .update({'status': 'pending'})
        .eq('id', documentId);

    // 3. Delete old questions from this document (fresh extraction)
    final questionsRes = await supabaseClient
        .from('qb_questions')
        .select('id')
        .eq('document_id', documentId);
    final questionIds = (questionsRes as List<dynamic>)
        .map((q) => (q as Map<String, dynamic>)['id'] as String)
        .toList();
    for (final qId in questionIds) {
      await deleteQuestion(qId);
    }

    // 4. Create a new job
    const pipelineVersion = '1.0.0-reconstruct';
    final cacheKey =
        'ingest_document:$pipelineVersion:${sha256}_retry_${DateTime.now().millisecondsSinceEpoch}';

    final jobRow = await supabaseClient
        .from('qb_jobs')
        .insert({
          'tenant_id': tenantId,
          'kind': 'ingest_document',
          'payload': {
            'document_id': documentId,
            'storage_path': storagePath,
            'tenant_id': tenantId,
            'uploader_id': uploaderId,
            'original_filename': filename,
            'sha256': sha256,
          },
          'status': 'pending',
          'cache_key': cacheKey,
        })
        .select('id')
        .single();

    return jobRow['id'] as String;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // Question-Level Operations (existing)
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Future<List<QuestionEntity>> getQuestions({
    String? statusFilter,
    bool sortByPriority = false,
  }) async {
    var query = supabaseClient.from('qb_questions').select();

    if (statusFilter != null &&
        statusFilter.isNotEmpty &&
        statusFilter != 'all') {
      query = query.eq('status', statusFilter);
    }

    final response = await query.order('created_at', ascending: false);
    final list = response as List<dynamic>;

    final questions = list
        .map((json) => _mapQuestion(json as Map<String, dynamic>))
        .toList();
    if (sortByPriority) {
      questions.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    }
    return questions;
  }

  @override
  Future<QuestionEntity> getQuestionById(String questionId) async {
    final response = await supabaseClient
        .from('qb_questions')
        .select()
        .eq('id', questionId)
        .single();
    return _mapQuestion(response);
  }

  @override
  Future<QuestionRevisionEntity?> getLatestRevision(String questionId) async {
    final response = await supabaseClient
        .from('qb_question_revisions')
        .select()
        .eq('question_id', questionId)
        .order('rev_no', ascending: false)
        .limit(1);

    final list = response as List<dynamic>;
    if (list.isEmpty) return null;
    return _mapRevision(list.first as Map<String, dynamic>);
  }

  @override
  Future<List<QuestionRevisionEntity>> getRevisionHistory(
    String questionId,
  ) async {
    final response = await supabaseClient
        .from('qb_question_revisions')
        .select()
        .eq('question_id', questionId)
        .order('rev_no', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((json) => _mapRevision(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ValidationIssueEntity>> getValidationIssues(
    String revisionId,
  ) async {
    final runs = await supabaseClient
        .from('qb_validation_runs')
        .select('id')
        .eq('revision_id', revisionId)
        .order('ran_at', ascending: false)
        .limit(1);

    final runsList = runs as List<dynamic>;
    if (runsList.isEmpty) return [];

    final runId = runsList.first['id'] as String;
    final issues = await supabaseClient
        .from('qb_validation_issues')
        .select()
        .eq('run_id', runId);

    final list = issues as List<dynamic>;
    return list.map((json) => _mapIssue(json as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> acknowledgeIssue({
    required String revisionId,
    required String issueId,
    String? rationale,
  }) async {
    final user = supabaseClient.auth.currentUser;
    await supabaseClient
        .from('qb_validation_issues')
        .update({
          'resolved_at': DateTime.now().toIso8601String(),
          'resolved_by': user?.id,
        })
        .eq('id', issueId);
  }

  @override
  Future<QuestionRevisionEntity> editBlock({
    required String questionId,
    required String blockId,
    required String newValue,
    required String reason,
  }) async {
    final user = supabaseClient.auth.currentUser;
    final latestRev = await getLatestRevision(questionId);
    if (latestRev == null) {
      throw Exception('Question has no prior revision to edit');
    }

    // Deep clone content map
    final updatedContent = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(latestRev.content)) as Map,
    );
    final stem = updatedContent['stem'];
    if (stem is List) {
      for (final block in stem) {
        if (block is Map && block['id'] == blockId) {
          if (block['type'] == 'math') {
            block['latex'] = newValue;
            block['value'] = newValue;
          } else {
            block['value'] = newValue;
          }
        }
      }
    }

    final newHash = sha256
        .convert(utf8.encode(jsonEncode(updatedContent)))
        .toString();
    final newRevNo = latestRev.revNo + 1;

    final revRow = await supabaseClient
        .from('qb_question_revisions')
        .insert({
          'question_id': questionId,
          'tenant_id': latestRev.tenantId,
          'rev_no': newRevNo,
          'content': updatedContent,
          'answer': latestRev.answer,
          'confidence':
              latestRev.confidence ??
              {'boundary': 1.0, 'text': 1.0, 'answer': 1.0},
          'provenance': {
            'stage': 'teacher_edit',
            'parent_rev': latestRev.revNo,
          },
          'content_hash': newHash,
          'created_by': user?.id,
          'created_via': 'teacher_edit',
          'edit_note': reason,
        })
        .select()
        .single();

    return _mapRevision(revRow);
  }

  @override
  Future<QuestionRevisionEntity> selectAnswer({
    required String questionId,
    required String selectedKey,
  }) async {
    final user = supabaseClient.auth.currentUser;
    final latestRev = await getLatestRevision(questionId);
    if (latestRev == null) {
      throw Exception('Question has no prior revision');
    }

    final updatedAnswer = Map<String, dynamic>.from(latestRev.answer);
    updatedAnswer['status'] = 'teacher_confirmed';
    updatedAnswer['raw'] = selectedKey;
    updatedAnswer['normalized'] = selectedKey;
    updatedAnswer['conflict'] = false;

    final contentHash = latestRev.contentHash;
    final newRevNo = latestRev.revNo + 1;

    final revRow = await supabaseClient
        .from('qb_question_revisions')
        .insert({
          'question_id': questionId,
          'tenant_id': latestRev.tenantId,
          'rev_no': newRevNo,
          'content': latestRev.content,
          'answer': updatedAnswer,
          'confidence':
              latestRev.confidence ??
              {'boundary': 1.0, 'text': 1.0, 'answer': 1.0},
          'provenance': {
            'stage': 'teacher_answer_confirmation',
            'parent_rev': latestRev.revNo,
          },
          'content_hash': contentHash,
          'created_by': user?.id,
          'created_via': 'teacher_edit',
          'edit_note': 'Teacher confirmed answer: $selectedKey',
        })
        .select()
        .single();

    return _mapRevision(revRow);
  }

  @override
  Future<void> mergeWithNext({required String questionId}) async {
    // Call Supabase RPC or update status
    await supabaseClient
        .from('qb_questions')
        .update({
          'status': 'merged_with_next',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', questionId);
  }

  @override
  Future<void> splitQuestion({
    required String questionId,
    required int splitIndex,
  }) async {
    await supabaseClient
        .from('qb_questions')
        .update({
          'status': 'split_review_pending',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', questionId);
  }

  @override
  Future<void> markSourceUnreadable({
    required String questionId,
    required String reason,
  }) async {
    await supabaseClient
        .from('qb_questions')
        .update({
          'status': 'quarantined',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', questionId);
  }

  @override
  Future<QuestionRevisionEntity> restoreRevision({
    required String questionId,
    required String revisionId,
  }) async {
    final user = supabaseClient.auth.currentUser;
    final targetRevRow = await supabaseClient
        .from('qb_question_revisions')
        .select()
        .eq('id', revisionId)
        .single();
    final targetRev = _mapRevision(targetRevRow);

    final latestRev = await getLatestRevision(questionId);
    final newRevNo = (latestRev?.revNo ?? 0) + 1;

    final revRow = await supabaseClient
        .from('qb_question_revisions')
        .insert({
          'question_id': questionId,
          'tenant_id': targetRev.tenantId,
          'rev_no': newRevNo,
          'content': targetRev.content,
          'answer': targetRev.answer,
          'confidence':
              targetRev.confidence ??
              {'boundary': 1.0, 'text': 1.0, 'answer': 1.0},
          'provenance': {
            'stage': 'restored_revision',
            'source_rev': targetRev.revNo,
          },
          'content_hash': targetRev.contentHash,
          'created_by': user?.id,
          'created_via': 'teacher_edit',
          'edit_note': 'Restored from revision ${targetRev.revNo}',
        })
        .select()
        .single();

    return _mapRevision(revRow);
  }

  @override
  Future<void> sampleSecondReview({required String questionId}) async {
    await supabaseClient
        .from('qb_questions')
        .update({
          'requires_second_review': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', questionId);
  }

  @override
  Future<String> createManualQuestion({
    required String sourceLabel,
    required String questionType,
    required String stemText,
    required List<Map<String, dynamic>> options,
    required String correctAnswer,
    required Map<String, dynamic> rightsAttestation,
    String? imageUrl,
    Map<String, dynamic>? imageMeta,
  }) async {
    final user = supabaseClient.auth.currentUser;
    if (user == null) {
      throw Exception('AUTH_REQUIRED: User must be signed in');
    }

    final userRow = await supabaseClient
        .from('users')
        .select('tenant_id, role')
        .eq('id', user.id)
        .single();
    final tenantId = userRow['tenant_id'] as String;

    final docSha = sha256
        .convert(utf8.encode('manual-intake-$tenantId'))
        .toString();
    final docRow = await supabaseClient
        .from('qb_documents')
        .upsert({
          'tenant_id': tenantId,
          'sha256': docSha,
          'original_filename': 'manual_entry_intake.pdf',
          'rights_attestation': rightsAttestation,
          'status': 'done',
        }, onConflict: 'tenant_id, sha256')
        .select('id')
        .single();
    final documentId = docRow['id'] as String;

    final questionRow = await supabaseClient
        .from('qb_questions')
        .insert({
          'tenant_id': tenantId,
          'document_id': documentId,
          'source_label': sourceLabel,
          'question_type': questionType == 'true_false' ? 'true_false' : 'multiple_choice',
          'status': 'review_required',
        })
        .select('id')
        .single();
    final questionId = questionRow['id'] as String;

    final formattedOptions = options.map((opt) {
      return {
        'key': opt['key'] ?? 'A',
        'content': [
          {'type': 'text', 'value': opt['text'] ?? ''},
        ],
        'source_refs': ['manual_input'],
      };
    }).toList();

    final stemBlocks = <Map<String, dynamic>>[];
    if (stemText.trim().isNotEmpty) {
      stemBlocks.add({
        'id': 'b1',
        'type': 'text',
        'value': stemText.trim(),
        'source_refs': ['manual_input'],
      });
    }
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      stemBlocks.add({
        'id': 'b_img',
        'type': 'image',
        'value': imageUrl.trim(),
        if (imageMeta != null) 'meta': imageMeta,
        'source_refs': ['manual_input'],
      });
    }
    if (stemBlocks.isEmpty) {
      stemBlocks.add({
        'id': 'b1',
        'type': 'text',
        'value': ' ',
        'source_refs': ['manual_input'],
      });
    }

    final content = {
      'stem': stemBlocks,
      'question_type': questionType,
      'options': formattedOptions,
      'language': 'en',
      'direction': 'ltr',
    };

    final contentJsonStr = jsonEncode(content);
    final contentHash = sha256.convert(utf8.encode(contentJsonStr)).toString();

    final answer = {
      'status': 'teacher_confirmed',
      'raw': correctAnswer,
      'normalized': correctAnswer,
      'source_ref': 'manual_teacher_entry',
    };

    final revRow = await supabaseClient
        .from('qb_question_revisions')
        .insert({
          'question_id': questionId,
          'tenant_id': tenantId,
          'rev_no': 1,
          'content': content,
          'answer': answer,
          'confidence': {'boundary': 1.0, 'text': 1.0, 'answer': 1.0},
          'provenance': {'stage': 'manual_entry', 'version': '1.0'},
          'content_hash': contentHash,
          'created_by': user.id,
          'created_via': 'teacher_edit',
        })
        .select('id')
        .single();
    final revisionId = revRow['id'] as String;

    await supabaseClient.from('qb_validation_runs').insert({
      'revision_id': revisionId,
      'tenant_id': tenantId,
      'pipeline_version': '1.0.0-manual',
    });

    return questionId;
  }

  @override
  Future<void> approveRevision({
    required String revisionId,
    required String contentHash,
    List<String>? acknowledgedIssueIds,
  }) async {
    final user = supabaseClient.auth.currentUser;
    if (user == null) {
      throw Exception('AUTH_REQUIRED: User must be signed in');
    }

    final userRow = await supabaseClient
        .from('users')
        .select('tenant_id')
        .eq('id', user.id)
        .single();
    final tenantId = userRow['tenant_id'] as String;

    await supabaseClient.from('qb_approvals').insert({
      'revision_id': revisionId,
      'tenant_id': tenantId,
      'approver_id': user.id,
      'content_hash': contentHash,
      'acknowledged_issue_ids': acknowledgedIssueIds ?? [],
    });

    final rev = await supabaseClient
        .from('qb_question_revisions')
        .select('question_id')
        .eq('id', revisionId)
        .single();
    final qId = rev['question_id'] as String;

    await supabaseClient
        .from('qb_questions')
        .update({
          'status': 'approved',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', qId);
  }

  @override
  Future<void> publishRevision({required String revisionId}) async {
    await supabaseClient.rpc<void>(
      'publish_revision',
      params: {'p_revision_id': revisionId},
    );
  }

  @override
  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    final response = await supabaseClient
        .from('qb_jobs')
        .select('id, status, result, error, attempts, kind, updated_at')
        .eq('id', jobId)
        .single();
    return response;
  }

  @override
  Future<List<QuestionEntity>> ingestExamDocument({
    required String filename,
    required List<int> bytes,
    String? answerKeyFilename,
    required Map<String, dynamic> rightsAttestation,
  }) async {
    final session = supabaseClient.auth.currentSession;
    if (session == null) {
      throw Exception('AUTH_REQUIRED: User must be signed in');
    }
    final jwt = session.accessToken;

    // ── 1. بناء URL الـ Edge Function ─────────────────────────────────────────
    final supabaseUrl = AppConfig.supabaseUrl;
    final edgeFunctionUrl = '$supabaseUrl/functions/v1/qb-ingest';

    // ── 2. أرسل الملف كـ multipart/form-data للـ Edge Function ───────────────
    //    الـ Edge Function v2 تستخرج الأسئلة مباشرة بـ Gemini وترد بها فوراً
    //    (لا polling، لا job queue — كل شيء synchronous داخل الـ Edge Function)
    final request = http.MultipartRequest('POST', Uri.parse(edgeFunctionUrl))
      ..headers['Authorization'] = 'Bearer $jwt'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType(
            'application',
            filename.toLowerCase().endsWith('.pdf') ? 'pdf' : 'octet-stream',
          ),
        ),
      )
      ..fields['rights_note'] =
          rightsAttestation['uploader_note']?.toString() ?? 'Teacher attested';

    if (answerKeyFilename != null) {
      request.fields['answer_key_filename'] = answerKeyFilename;
    }

    // timeout: 5 دقائق كافية للاستخراج المباشر بـ Gemini
    final streamedResponse = await request.send().timeout(
      const Duration(minutes: 5),
    );
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      final Map<String, dynamic> err;
      try {
        err = json.decode(responseBody) as Map<String, dynamic>;
      } catch (_) {
        throw Exception('INGEST_ERROR: $responseBody');
      }
      throw Exception(
        '${err['code'] ?? 'INGEST_ERROR'}: ${err['message'] ?? responseBody}',
      );
    }

    // ── 3. Edge Function ترد مباشرة بالنتيجة النهائية ────────────────────────
    final ingestResult = json.decode(responseBody) as Map<String, dynamic>;
    final documentId = ingestResult['document_id'] as String;
    final status = ingestResult['status'] as String? ?? 'done';

    // حالة: الملف معالج مسبقاً أو تم الاستخراج للتو
    if (status == 'done' || status == 'already_processed') {
      // الأسئلة قد تأتي في الـ Response ولكنها قد تكون غير مكتملة (مثلاً ينقصها tenant_id)
      // الأفضل والأكثر أماناً هو جلبها دائماً من قاعدة البيانات لضمان اكتمال كل الحقول.
      return _fetchQuestionsByDocument(documentId);
    }

    if (status == 'processing') {
      throw Exception('BACKGROUND_PROCESSING');
    }

    throw Exception(
      'INGEST_ERROR: Unexpected status "$status" from Edge Function',
    );
  }

  /// يجلب أسئلة document_id من qb_questions
  Future<List<QuestionEntity>> _fetchQuestionsByDocument(
    String documentId,
  ) async {
    final response = await supabaseClient
        .from('qb_questions')
        .select()
        .eq('document_id', documentId)
        .order('created_at', ascending: true);
    final list = response as List<dynamic>;
    return list.map((j) => _mapQuestion(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<String> createExamFromQuestions({
    required String groupId,
    required String title,
    required int durationMinutes,
    required List<QuestionEntity> questions,
  }) async {
    final user = supabaseClient.auth.currentUser;
    if (user == null) {
      throw Exception('AUTH_REQUIRED: User must be signed in');
    }

    final userRow = await supabaseClient
        .from('users')
        .select('tenant_id')
        .eq('id', user.id)
        .single();
    final tenantId = userRow['tenant_id'] as String;

    // 1. Create content record
    final contentRes = await supabaseClient
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
    final totalPoints = questions.length * 10;
    final passingPoints = (totalPoints * 0.6).round();

    final examRes = await supabaseClient
        .from('exams')
        .insert({
          'content_id': contentId,
          'tenant_id': tenantId,
          'duration_minutes': durationMinutes,
          'max_score': totalPoints,
          'passing_score': passingPoints,
          'shuffle_questions': true,
          'show_result': true,
          'allow_retake': false,
        })
        .select('id')
        .single();
    final examId = examRes['id'] as String;

    // 3. Create exam version
    final versionRes = await supabaseClient
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

    // 4. Create exam_questions and question_options
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final latestRev = await getLatestRevision(q.id);

      final stemList = (latestRev?.content['stem'] as List?) ?? [];
      final stemParts = stemList
          .map((b) => (b is Map && (b['type'] == 'text' || b['type'] == 'math'))
              ? (b['value'] ?? b['latex'] ?? '')
              : '')
          .where((s) => s.toString().trim().isNotEmpty)
          .join('\n');

      final qImageUrl = latestRev?.imageUrl;
      final qImageMeta = latestRev?.imageMeta;
      final questionText = stemParts.isNotEmpty
          ? stemParts
          : (qImageUrl != null ? ' ' : q.sourceLabel);

      final optionsList = (latestRev?.content['options'] as List?) ?? [];
      final correctKey =
          (latestRev?.answer['normalized'] ?? latestRev?.answer['raw'] ?? 'A')
              .toString();

      final eqRes = await supabaseClient
          .from('exam_questions')
          .insert({
            'exam_version_id': versionId,
            'question_text': questionText,
            'question_type': 'multiple_choice',
            'points': 10,
            'sort_order': i + 1,
            if (qImageUrl != null) 'image_url': qImageUrl,
            if (qImageMeta != null) 'image_meta': qImageMeta,
          })
          .select('id')
          .single();
      final eqId = eqRes['id'] as String;

      int optOrder = 1;
      for (final opt in optionsList) {
        if (opt is! Map) continue;
        final key = opt['key']?.toString() ?? 'A';
        final contentList = opt['content'] as List?;
        final optText =
            (contentList?.isNotEmpty == true && contentList!.first is Map)
            ? contentList.first['value']?.toString() ?? key
            : key;

        await supabaseClient.from('question_options').insert({
          'question_id': eqId,
          'option_text': '$key) $optText',
          'sort_order': optOrder++,
          'is_correct': key.toUpperCase() == correctKey.toUpperCase(),
        });
      }
    }

    return examId;
  }

  DocumentEntity _mapDocument(Map<String, dynamic> json) {
    return DocumentEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      originalFilename: json['original_filename'] as String? ?? 'Unknown',
      status: json['status'] as String? ?? 'pending',
      mime: json['mime'] as String?,
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      pageCount: (json['page_count'] as num?)?.toInt(),
      uploaderId: json['uploader_id'] as String?,
      pipelineVersion: json['pipeline_version'] as String?,
      storagePath: json['storage_path'] as String?,
      rightsAttestation: json['rights_attestation'] as Map<String, dynamic>?,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  QuestionEntity _mapQuestion(Map<String, dynamic> json) {
    return QuestionEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      documentId: json['document_id'] as String?,
      sectionId: json['section_id'] as String?,
      sourceLabel: json['source_label'] as String? ?? 'Untitled',
      questionType: json['question_type'] as String? ?? 'multiple_choice',
      status: json['status'] as String? ?? 'extracted',
      currentPublishedRevisionId:
          json['current_published_revision_id'] as String?,
      priorityScore: (json['priority_score'] as num?)?.toDouble() ?? 0.0,
      policyState: json['policy_state'] as String? ?? 'REVIEW_FAST',
      duplicateClusterId: json['duplicate_cluster_id'] as String?,
      requiresSecondReview: json['requires_second_review'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  QuestionRevisionEntity _mapRevision(Map<String, dynamic> json) {
    return QuestionRevisionEntity(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      tenantId: json['tenant_id'] as String,
      revNo: (json['rev_no'] as num?)?.toInt() ?? 1,
      content: json['content'] as Map<String, dynamic>? ?? {},
      answer: json['answer'] as Map<String, dynamic>? ?? {},
      confidence: json['confidence'] as Map<String, dynamic>?,
      provenance: json['provenance'] as Map<String, dynamic>? ?? {},
      contentHash: json['content_hash'] as String? ?? '',
      createdBy: json['created_by'] as String?,
      createdVia: json['created_via'] as String?,
      editNote: json['edit_note'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  ValidationIssueEntity _mapIssue(Map<String, dynamic> json) {
    return ValidationIssueEntity(
      id: json['id'] as String,
      ruleId: json['rule_id'] as String? ?? 'UNKNOWN',
      severity: json['severity'] as String? ?? 'WARN',
      blockRef: json['block_ref'] as String?,
      message: json['message'] as Map<String, dynamic>? ?? {},
      resolvableBy: json['resolvable_by'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
    );
  }
}
