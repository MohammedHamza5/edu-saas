import 'package:equatable/equatable.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';

abstract class CourseProgressState extends Equatable {
  const CourseProgressState();

  @override
  List<Object?> get props => [];
}

class CourseProgressInitial extends CourseProgressState {
  const CourseProgressInitial();
}

class CourseProgressLoading extends CourseProgressState {
  const CourseProgressLoading();
}

class CourseProgressLoaded extends CourseProgressState {
  final List<LessonAssignmentEntity> lessons;
  final List<ChapterEntity> chapters;
  final bool isRefreshing;

  const CourseProgressLoaded({
    required this.lessons,
    this.chapters = const [],
    this.isRefreshing = false,
  });

  CourseProgressLoaded copyWith({
    List<LessonAssignmentEntity>? lessons,
    List<ChapterEntity>? chapters,
    bool? isRefreshing,
  }) {
    return CourseProgressLoaded(
      lessons: lessons ?? this.lessons,
      chapters: chapters ?? this.chapters,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [lessons, chapters, isRefreshing];
}

class CourseProgressError extends CourseProgressState {
  final String message;

  const CourseProgressError(this.message);

  @override
  List<Object?> get props => [message];
}
