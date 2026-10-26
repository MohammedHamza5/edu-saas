import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';

/// Represents a grouped bucket of lessons under a course chapter
class StudentChapterBucket {
  final String? chapterId;
  final String title;
  final int sortOrder;
  final List<LessonAssignmentEntity> lessons = [];

  StudentChapterBucket({
    required this.chapterId,
    required this.title,
    required this.sortOrder,
  });

  /// Distributes course lessons into chapter buckets, ordering and filtering empty WIP chapters
  static List<StudentChapterBucket> buildBuckets(
    List<LessonAssignmentEntity> items,
    List<ChapterEntity> allChapters,
    BuildContext context,
  ) {
    final Map<String, StudentChapterBucket> map = {};

    // 1. Pre-populate defined course chapters that are published
    for (final ch in allChapters) {
      if (!ch.isPublished) continue;
      map[ch.id] = StudentChapterBucket(
        chapterId: ch.id,
        title: ch.title,
        sortOrder: ch.sortOrder,
      );
    }

    StudentChapterBucket? generalBucket;

    // 2. Distribute lessons into their corresponding chapters
    for (final item in items) {
      if (item.chapterId != null && item.chapterId!.isNotEmpty) {
        final id = item.chapterId!;
        map
            .putIfAbsent(
              id,
              () => StudentChapterBucket(
                chapterId: id,
                title: item.chapterTitle ?? context.l10n.chapterPrefix,
                sortOrder: item.chapterSortOrder ?? 999999,
              ),
            )
            .lessons
            .add(item);
      } else {
        generalBucket ??= StudentChapterBucket(
          chapterId: '__general__',
          title: context.l10n.generalLessonsTitle,
          sortOrder: 9999999,
        );
        generalBucket.lessons.add(item);
      }
    }

    var buckets = map.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Never show empty or WIP chapters to students — only chapters with actual published lessons appear
    buckets = buckets.where((b) => b.lessons.isNotEmpty).toList();

    if (generalBucket != null) {
      buckets.add(generalBucket);
    }

    return buckets;
  }
}
