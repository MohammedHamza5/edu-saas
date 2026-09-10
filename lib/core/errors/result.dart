import 'failures.dart';

/// Modern Dart 3 Sealed Result Pattern
/// Enforces exhaustive compile-time checking for operation results.
sealed class Result<T> {
  const Result();

  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(Failure failure) = FailureResult<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T get data => switch (this) {
        Success(:final data) => data,
        FailureResult(:final failure) =>
          throw StateError('Cannot access data on failure: $failure'),
      };

  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        FailureResult() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Success() => null,
        FailureResult(:final failure) => failure,
      };

  R when<R>({
    R Function(T data)? onSuccess,
    R Function(Failure failure)? onFailure,
    R Function(T data)? success,
    R Function(Failure failure)? failure,
  }) {
    final s = onSuccess ?? success;
    final f = onFailure ?? failure;
    return switch (this) {
      Success(:final data) => s!(data),
      FailureResult(:final failure) => f!(failure),
    };
  }
}

final class Success<T> extends Result<T> {
  @override
  final T data;
  const Success(this.data);
}

final class FailureResult<T> extends Result<T> {
  final Failure failure;
  const FailureResult(this.failure);
}
