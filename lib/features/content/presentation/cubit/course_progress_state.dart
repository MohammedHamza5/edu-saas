import 'package:equatable/equatable.dart';
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
  final bool isRefreshing;

  const CourseProgressLoaded({
    required this.lessons,
    this.isRefreshing = false,
  });

  CourseProgressLoaded copyWith({
    List<LessonAssignmentEntity>? lessons,
    bool? isRefreshing,
  }) {
    return CourseProgressLoaded(
      lessons: lessons ?? this.lessons,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [lessons, isRefreshing];
}

class CourseProgressError extends CourseProgressState {
  final String message;

  const CourseProgressError(this.message);

  @override
  List<Object?> get props => [message];
}
