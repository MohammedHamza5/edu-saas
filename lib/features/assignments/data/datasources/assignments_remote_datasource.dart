import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/assignment_model.dart';
import '../models/assignment_submission_model.dart';

abstract interface class AssignmentsRemoteDataSource {
  Future<List<AssignmentModel>> getGroupAssignments(String groupId);
  Future<List<AssignmentModel>> getStudentAssignments();
  Future<AssignmentModel> getAssignmentDetails(String assignmentId);
  Future<List<AssignmentSubmissionModel>> getSubmissions(String assignmentId);
  Future<AssignmentSubmissionModel?> getMySubmission(String assignmentId);
  Future<AssignmentModel> createAssignment({
    required String groupId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    bool allowLateSubmission = false,
    int maxScore = 100,
  });
  Future<AssignmentSubmissionModel> submitAssignment({
    required String assignmentId,
    required List<({String fileName, List<int> bytes, String mimeType})> files,
  });
  Future<AssignmentSubmissionModel> gradeSubmission({
    required String submissionId,
    required int score,
    String? feedback,
  });
  Future<String> getSubmissionFileSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  });
}

class AssignmentsRemoteDataSourceImpl implements AssignmentsRemoteDataSource {
  final SupabaseClient? _client;

  AssignmentsRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<List<AssignmentModel>> getGroupAssignments(String groupId) async {
    // 1. Fetch assignments with content & group join
    final response = await _safeClient
        .from('assignments')
        .select('''
          id,
          content_id,
          tenant_id,
          instructions,
          due_at,
          allow_late_submission,
          max_score,
          created_at,
          updated_at,
          content!inner(
            id,
            group_id,
            title,
            description,
            status,
            groups(name)
          )
        ''')
        .eq('content.group_id', groupId)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;

    // 2. Aggregate submissions counts for each assignment
    final results = <AssignmentModel>[];
    for (final item in list) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final assignmentId = map['id'] as String;

      // Count submissions and reviewed submissions
      final submissionsRes = await _safeClient
          .from('assignment_submissions')
          .select('id, status')
          .eq('assignment_id', assignmentId);

      final subsList = submissionsRes as List<dynamic>;
      map['submissions_count'] = subsList.length;
      map['reviewed_count'] =
          subsList.where((s) => s['status'] == 'reviewed').length;

      results.add(AssignmentModel.fromJson(map));
    }

    return results;
  }

  @override
  Future<List<AssignmentModel>> getStudentAssignments() async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) return [];

    // 1. Find the groups this student belongs to
    final memberships = await _safeClient
        .from('group_members')
        .select('group_id')
        .eq('student_id', currentUserId)
        .eq('status', 'active');

    final groupIds = (memberships as List<dynamic>)
        .map((m) => m['group_id'] as String)
        .toList();

    if (groupIds.isEmpty) return [];

    // 2. Fetch published assignments in these groups
    final response = await _safeClient
        .from('assignments')
        .select('''
          id,
          content_id,
          tenant_id,
          instructions,
          due_at,
          allow_late_submission,
          max_score,
          created_at,
          updated_at,
          content!inner(
            id,
            group_id,
            title,
            description,
            status,
            groups(name)
          )
        ''')
        .inFilter('content.group_id', groupIds)
        .eq('content.status', 'published')
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    final results = <AssignmentModel>[];

    for (final item in list) {
      final map = Map<String, dynamic>.from(item as Map<String, dynamic>);
      final assignmentId = map['id'] as String;

      // Check student's submission
      final subRes = await _safeClient
          .from('assignment_submissions')
          .select('''
            id,
            assignment_id,
            student_id,
            attempt_number,
            submitted_at,
            status,
            score,
            teacher_feedback,
            reviewed_at,
            reviewed_by,
            submission_files(*)
          ''')
          .eq('assignment_id', assignmentId)
          .eq('student_id', currentUserId)
          .order('attempt_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (subRes != null) {
        map['my_submission'] = subRes;
      }

      results.add(AssignmentModel.fromJson(map));
    }

    return results;
  }

  @override
  Future<AssignmentModel> getAssignmentDetails(String assignmentId) async {
    final response = await _safeClient
        .from('assignments')
        .select('''
          id,
          content_id,
          tenant_id,
          instructions,
          due_at,
          allow_late_submission,
          max_score,
          created_at,
          updated_at,
          content!inner(
            id,
            group_id,
            title,
            description,
            status,
            groups(name)
          )
        ''')
        .eq('id', assignmentId)
        .single();

    final map = Map<String, dynamic>.from(response);

    // If current user is student, attach submission
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId != null) {
      final subRes = await _safeClient
          .from('assignment_submissions')
          .select('''
            id,
            assignment_id,
            student_id,
            attempt_number,
            submitted_at,
            status,
            score,
            teacher_feedback,
            reviewed_at,
            reviewed_by,
            submission_files(*)
          ''')
          .eq('assignment_id', assignmentId)
          .eq('student_id', currentUserId)
          .order('attempt_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (subRes != null) {
        map['my_submission'] = subRes;
      }
    }

    return AssignmentModel.fromJson(map);
  }

  @override
  Future<List<AssignmentSubmissionModel>> getSubmissions(String assignmentId) async {
    final response = await _safeClient
        .from('assignment_submissions')
        .select('''
          id,
          assignment_id,
          student_id,
          attempt_number,
          submitted_at,
          status,
          score,
          teacher_feedback,
          reviewed_at,
          reviewed_by,
          users!student_id(id, full_name, email, phone, avatar_url),
          submission_files(*)
        ''')
        .eq('assignment_id', assignmentId)
        .order('submitted_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((item) => AssignmentSubmissionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AssignmentSubmissionModel?> getMySubmission(String assignmentId) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) return null;

    final response = await _safeClient
        .from('assignment_submissions')
        .select('''
          id,
          assignment_id,
          student_id,
          attempt_number,
          submitted_at,
          status,
          score,
          teacher_feedback,
          reviewed_at,
          reviewed_by,
          users!student_id(id, full_name, email),
          submission_files(*)
        ''')
        .eq('assignment_id', assignmentId)
        .eq('student_id', currentUserId)
        .order('attempt_number', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return AssignmentSubmissionModel.fromJson(response);
  }

  @override
  Future<AssignmentModel> createAssignment({
    required String groupId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    bool allowLateSubmission = false,
    int maxScore = 100,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('User not authenticated');
    }

    // Lookup user's tenant_id
    final userRes = await _safeClient
        .from('users')
        .select('tenant_id')
        .eq('id', currentUserId)
        .single();
    final tenantId = userRes['tenant_id'] as String;

    // 1. Create content row
    final contentRes = await _safeClient
        .from('content')
        .insert({
          'tenant_id': tenantId,
          'group_id': groupId,
          'title': title,
          'description': instructions,
          'type': 'assignment',
          'status': 'published',
          'published_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    final contentId = contentRes['id'] as String;

    // 2. Create assignments row
    final assignmentRes = await _safeClient
        .from('assignments')
        .insert({
          'content_id': contentId,
          'tenant_id': tenantId,
          'instructions': instructions,
          'due_at': dueAt?.toUtc().toIso8601String(),
          'allow_late_submission': allowLateSubmission,
          'max_score': maxScore,
        })
        .select()
        .single();

    final map = Map<String, dynamic>.from(assignmentRes);
    map['title'] = title;
    map['group_id'] = groupId;

    return AssignmentModel.fromJson(map);
  }

  @override
  Future<AssignmentSubmissionModel> submitAssignment({
    required String assignmentId,
    required List<({String fileName, List<int> bytes, String mimeType})> files,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('User not authenticated');
    }

    // 1. Fetch assignment to check due date and late policy
    final assignmentRes = await _safeClient
        .from('assignments')
        .select('id, due_at, allow_late_submission')
        .eq('id', assignmentId)
        .single();

    final dueAtStr = assignmentRes['due_at'] as String?;
    final allowLate = assignmentRes['allow_late_submission'] as bool? ?? false;
    final now = DateTime.now();

    var status = 'submitted';
    if (dueAtStr != null) {
      final dueAt = DateTime.parse(dueAtStr);
      if (now.isAfter(dueAt)) {
        if (!allowLate) {
          throw const PostgrestException(
            message: 'انتهى موعد تسليم الواجب ولا يُسمح بالتسليم المتأخر.',
          );
        }
        status = 'late';
      }
    }

    // 2. Determine attempt number
    final existingSubs = await _safeClient
        .from('assignment_submissions')
        .select('attempt_number')
        .eq('assignment_id', assignmentId)
        .eq('student_id', currentUserId)
        .order('attempt_number', ascending: false)
        .limit(1);

    int nextAttempt = 1;
    if ((existingSubs as List).isNotEmpty) {
      nextAttempt = ((existingSubs.first['attempt_number'] as num?)?.toInt() ?? 0) + 1;
    }

    // 3. Insert submission record
    final subRes = await _safeClient
        .from('assignment_submissions')
        .insert({
          'assignment_id': assignmentId,
          'student_id': currentUserId,
          'attempt_number': nextAttempt,
          'submitted_at': now.toUtc().toIso8601String(),
          'status': status,
        })
        .select()
        .single();

    final submissionId = subRes['id'] as String;
    final uploadedFiles = <Map<String, dynamic>>[];

    // 4. Upload files to private storage bucket 'submission-files'
    for (final file in files) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cleanName = file.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final storagePath = '$assignmentId/$currentUserId/${timestamp}_$cleanName';

      await _safeClient.storage.from('submission-files').uploadBinary(
            storagePath,
            Uint8List.fromList(file.bytes),
            fileOptions: FileOptions(contentType: file.mimeType, upsert: true),
          );

      // 5. Insert submission_files record
      final fileRes = await _safeClient
          .from('submission_files')
          .insert({
            'submission_id': submissionId,
            'storage_path': storagePath,
            'file_name': file.fileName,
            'mime_type': file.mimeType,
            'file_size': file.bytes.length,
          })
          .select()
          .single();

      uploadedFiles.add(fileRes);
    }

    final fullSubMap = Map<String, dynamic>.from(subRes);
    fullSubMap['submission_files'] = uploadedFiles;

    return AssignmentSubmissionModel.fromJson(fullSubMap);
  }

  @override
  Future<AssignmentSubmissionModel> gradeSubmission({
    required String submissionId,
    required int score,
    String? feedback,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;

    final updatedRes = await _safeClient
        .from('assignment_submissions')
        .update({
          'score': score,
          'teacher_feedback': feedback,
          'status': 'reviewed',
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          if (currentUserId != null) 'reviewed_by': currentUserId,
        })
        .eq('id', submissionId)
        .select('''
          id,
          assignment_id,
          student_id,
          attempt_number,
          submitted_at,
          status,
          score,
          teacher_feedback,
          reviewed_at,
          reviewed_by,
          users!student_id(id, full_name, email),
          submission_files(*)
        ''')
        .single();

    return AssignmentSubmissionModel.fromJson(updatedRes);
  }

  @override
  Future<String> getSubmissionFileSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    final signedUrl = await _safeClient.storage
        .from('submission-files')
        .createSignedUrl(storagePath, expiresInSeconds);
    return signedUrl;
  }
}
