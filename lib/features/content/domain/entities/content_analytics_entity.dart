// Domain entities for Content Analytics (Lesson, Chapter, and Course)

class LessonAnalyticsEntity {
  final int totalStudents;
  final int totalViews;
  final int completedStudents;
  final double? averageQuizScore;

  const LessonAnalyticsEntity({
    required this.totalStudents,
    required this.totalViews,
    required this.completedStudents,
    this.averageQuizScore,
  });
}

class ChapterAnalyticsEntity {
  final int totalStudents;
  final int totalViews;
  final int completedCount;
  final int inProgressCount;
  final int notStartedCount;
  final double? averageScore;

  const ChapterAnalyticsEntity({
    required this.totalStudents,
    required this.totalViews,
    required this.completedCount,
    required this.inProgressCount,
    required this.notStartedCount,
    this.averageScore,
  });
}

class StudentAttentionItemEntity {
  final String id;
  final String name;
  final String? avatarUrl;
  final int completionPercentage;

  const StudentAttentionItemEntity({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.completionPercentage,
  });
}

class ChapterMetricItemEntity {
  final String chapterId;
  final String title;
  final int lessonCount;
  final int completionRate;
  final double? quizAvg;

  const ChapterMetricItemEntity({
    required this.chapterId,
    required this.title,
    required this.lessonCount,
    required this.completionRate,
    this.quizAvg,
  });
}

class GroupAnalyticsEntity {
  final int totalStudents;
  final int totalViews;
  final int overallProgress;
  final double? overallQuizzesAverage;
  final List<ChapterMetricItemEntity> chapterMetrics;
  final List<StudentAttentionItemEntity> studentsNeedingAttention;

  const GroupAnalyticsEntity({
    required this.totalStudents,
    required this.totalViews,
    required this.overallProgress,
    this.overallQuizzesAverage,
    required this.chapterMetrics,
    required this.studentsNeedingAttention,
  });
}
