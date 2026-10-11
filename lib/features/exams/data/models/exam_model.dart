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
    super.questionsCount,
    super.myLatestAttempt,
    super.myBestScore,
    super.isLectureExam,
    super.linkedLessonId,
    super.linkedLessonTitle,
    super.folderId,
    super.folderName,
    super.folderColor,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    String title = json['title']?.toString() ?? '';
    String groupId = json['group_id']?.toString() ?? '';
    String? groupName;

    if (json['content'] is Map) {
      final contentMap = json['content'] as Map;
      title = contentMap['title']?.toString() ?? title;
      groupId = contentMap['group_id']?.toString() ?? groupId;

      if (contentMap['groups'] is Map) {
        final groupsMap = contentMap['groups'] as Map;
        groupName = groupsMap['name']?.toString();
      }
    }

    if (json['group_name'] != null) {
      groupName = json['group_name']?.toString();
    }

    // Active version parsing - sort by version_number descending so latest version is picked
    ExamVersionModel? activeVersion;
    if (json['active_version'] is Map) {
      activeVersion = ExamVersionModel.fromJson(
        Map<String, dynamic>.from(json['active_version'] as Map),
      );
    } else if (json['exam_versions'] is List &&
        (json['exam_versions'] as List).isNotEmpty) {
      final versions = (json['exam_versions'] as List)
          .whereType<Map<dynamic, dynamic>>()
          .map((v) => Map<String, dynamic>.from(v))
          .toList();
      versions.sort((a, b) {
        final vA = (a['version_number'] as num?)?.toInt() ?? 0;
        final vB = (b['version_number'] as num?)?.toInt() ?? 0;
        return vB.compareTo(vA);
      });
      if (versions.isNotEmpty) {
        activeVersion = ExamVersionModel.fromJson(versions.first);
      }
    }

    // Student attempts metadata
    ExamAttemptModel? myLatestAttempt;
    int? myBestScore;
    if (json['my_latest_attempt'] is Map) {
      myLatestAttempt = ExamAttemptModel.fromJson(
        Map<String, dynamic>.from(json['my_latest_attempt'] as Map),
      );
    } else if (json['exam_attempts'] is List &&
        (json['exam_attempts'] as List).isNotEmpty) {
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
    } else if (json['exam_attempts'] is List &&
        (json['exam_attempts'] as List).isNotEmpty) {
      final first = (json['exam_attempts'] as List).first;
      if (first is Map && first.containsKey('count')) {
        attemptsCount = (first['count'] as num?)?.toInt() ?? 0;
      }
    }

    int questionsCount = 0;
    if (json['questions_count'] != null) {
      questionsCount = (json['questions_count'] as num).toInt();
    } else if (activeVersion != null && activeVersion.questions.isNotEmpty) {
      questionsCount = activeVersion.questions.length;
    } else if (json['exam_versions'] is List &&
        (json['exam_versions'] as List).isNotEmpty) {
      for (final v in (json['exam_versions'] as List)) {
        if (v is Map &&
            v['exam_questions'] is List &&
            (v['exam_questions'] as List).isNotEmpty) {
          final first = (v['exam_questions'] as List).first;
          if (first is Map && first.containsKey('count')) {
            questionsCount = (first['count'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (json['created_at'] != null) {
      parsedCreatedAt =
          DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    }

    DateTime parsedUpdatedAt = DateTime.now();
    if (json['updated_at'] != null) {
      parsedUpdatedAt =
          DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now();
    }

    final isLectureExam = json['is_lecture_exam'] as bool? ??
        (json['linked_lesson_id'] != null);
    final linkedLessonId = json['linked_lesson_id']?.toString();
    final linkedLessonTitle = json['linked_lesson_title']?.toString();

    String? folderId = json['folder_id']?.toString();
    String? folderName;
    String? folderColor;
    if (json['folder'] is Map) {
      final f = json['folder'] as Map;
      folderId ??= f['id']?.toString();
      folderName = f['name']?.toString();
      folderColor = f['color']?.toString();
    } else if (json['exam_folders'] is Map) {
      final f = json['exam_folders'] as Map;
      folderId ??= f['id']?.toString();
      folderName = f['name']?.toString();
      folderColor = f['color']?.toString();
    }

    return ExamModel(
      id: json['id']?.toString() ?? '',
      contentId: json['content_id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      groupId: groupId,
      groupName: groupName,
      title: title.isNotEmpty ? title : 'امتحان بدون عنوان',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
      maxScore: (json['max_score'] as num?)?.toInt() ?? 100,
      passingScore: (json['passing_score'] as num?)?.toInt(),
      shuffleQuestions: json['shuffle_questions'] as bool? ?? false,
      showResult: json['show_result'] as bool? ?? true,
      allowRetake: json['allow_retake'] as bool? ?? false,
      startAt: json['start_at'] != null
          ? DateTime.tryParse(json['start_at'].toString())
          : null,
      endAt: json['end_at'] != null
          ? DateTime.tryParse(json['end_at'].toString())
          : null,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      activeVersion: activeVersion,
      attemptsCount: attemptsCount,
      questionsCount: questionsCount,
      myLatestAttempt: myLatestAttempt,
      myBestScore: myBestScore,
      isLectureExam: isLectureExam,
      linkedLessonId: linkedLessonId,
      linkedLessonTitle: linkedLessonTitle,
      folderId: folderId,
      folderName: folderName,
      folderColor: folderColor,
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
