import '../../domain/entities/exam_entity.dart';
import 'exam_attempt_model.dart';
import 'exam_version_model.dart';

class ExamModel extends ExamEntity {
  const ExamModel({
    required super.id,
    required super.contentId,
    required super.tenantId,
    required super.groupId,
    super.groupName,
    required super.title,
    super.durationMinutes,
    super.maxScore,
    super.passingScore,
    super.shuffleQuestions,
    super.showResult,
    super.allowRetake,
    super.startAt,
    super.endAt,
    required super.createdAt,
    required super.updatedAt,
    super.activeVersion,
    super.attemptsCount,
    super.myLatestAttempt,
    super.myBestScore,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    String title = json['title'] as String? ?? '';
    String groupId = json['group_id'] as String? ?? '';
    String? groupName;

    if (json['content'] is Map<String, dynamic>) {
      final contentMap = json['content'] as Map<String, dynamic>;
      title = contentMap['title'] as String? ?? title;
      groupId = contentMap['group_id'] as String? ?? groupId;

      if (contentMap['groups'] is Map<String, dynamic>) {
        final groupsMap = contentMap['groups'] as Map<String, dynamic>;
        groupName = groupsMap['name'] as String?;
      }
    }

    if (json['group_name'] != null) {
      groupName = json['group_name'] as String?;
    }

    // Active version parsing
    ExamVersionModel? activeVersion;
    if (json['active_version'] is Map) {
      activeVersion = ExamVersionModel.fromJson(
        Map<String, dynamic>.from(json['active_version'] as Map),
      );
    } else if (json['exam_versions'] is List && (json['exam_versions'] as List).isNotEmpty) {
      final versions = (json['exam_versions'] as List).whereType<Map<dynamic, dynamic>>().toList();
      Map<dynamic, dynamic>? published;
      for (final v in versions) {
        if (v['status'] == 'published') {
          published = v;
          break;
        }
      }
      published ??= versions.firstOrNull;
      if (published != null) {
        activeVersion = ExamVersionModel.fromJson(Map<String, dynamic>.from(published));
      }
    }

    // Student attempts metadata
    ExamAttemptModel? myLatestAttempt;
    int? myBestScore;
    if (json['my_latest_attempt'] is Map) {
      myLatestAttempt = ExamAttemptModel.fromJson(
        Map<String, dynamic>.from(json['my_latest_attempt'] as Map),
      );
    } else if (json['exam_attempts'] is List && (json['exam_attempts'] as List).isNotEmpty) {
      // Only parse as ExamAttemptModel if the items actually look like attempts (have an 'id' and 'student_id')
      final validAttemptMaps = (json['exam_attempts'] as List)
          .whereType<Map<dynamic, dynamic>>()
          .where((a) => a['id'] != null && a['student_id'] != null)
          .map((a) => Map<String, dynamic>.from(a))
          .toList();

      final attemptsList = validAttemptMaps
          .map((a) => ExamAttemptModel.fromJson(a))
          .toList();

      if (attemptsList.isNotEmpty) {
        myLatestAttempt = attemptsList.first;
        final scores = attemptsList
            .where((a) => a.score != null)
            .map((a) => a.score!)
            .toList();
        if (scores.isNotEmpty) {
          scores.sort();
          myBestScore = scores.last; // Highest score policy
        }
      }
    }

    if (json['my_best_score'] != null) {
      myBestScore = (json['my_best_score'] as num).toInt();
    }

    int attemptsCount = 0;
    if (json['attempts_count'] != null) {
      attemptsCount = (json['attempts_count'] as num).toInt();
    } else if (json['exam_attempts'] is List && (json['exam_attempts'] as List).isNotEmpty) {
      final first = (json['exam_attempts'] as List).first;
      if (first is Map && first.containsKey('count')) {
        attemptsCount = (first['count'] as num?)?.toInt() ?? 0;
      }
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (json['created_at'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    }

    DateTime parsedUpdatedAt = DateTime.now();
    if (json['updated_at'] != null) {
      parsedUpdatedAt = DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now();
    }

    return ExamModel(
      id: json['id'] as String? ?? '',
      contentId: json['content_id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      groupId: groupId,
      groupName: groupName,
      title: title.isNotEmpty ? title : 'امتحان بدون عنوان',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      maxScore: (json['max_score'] as num?)?.toInt() ?? 100,
      passingScore: (json['passing_score'] as num?)?.toInt(),
      shuffleQuestions: json['shuffle_questions'] as bool? ?? false,
      showResult: json['show_result'] as bool? ?? true,
      allowRetake: json['allow_retake'] as bool? ?? false,
      startAt: json['start_at'] != null ? DateTime.tryParse(json['start_at'].toString()) : null,
      endAt: json['end_at'] != null ? DateTime.tryParse(json['end_at'].toString()) : null,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      activeVersion: activeVersion,
      attemptsCount: attemptsCount,
      myLatestAttempt: myLatestAttempt,
      myBestScore: myBestScore,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_id': contentId,
      'tenant_id': tenantId,
      'duration_minutes': durationMinutes,
      'max_score': maxScore,
      if (passingScore != null) 'passing_score': passingScore,
      'shuffle_questions': shuffleQuestions,
      'show_result': showResult,
      'allow_retake': allowRetake,
      if (startAt != null) 'start_at': startAt!.toIso8601String(),
      if (endAt != null) 'end_at': endAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
