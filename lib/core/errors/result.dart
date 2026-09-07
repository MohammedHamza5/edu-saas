import 'failures.dart';

/// Modern Dart 3 Sealed Result Pattern
/// Enforces exhaustive compile-time checking for operation results.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        FailureResult() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Success() => null,
        FailureResult(:final failure) => failure,
      };

  R when<R>({
    required R Function(T data) onSuccess,
    required R Function(Failure failure) onFailure,
  }) =>
      switch (this) {
        Success(:final data) => onSuccess(data),
        FailureResult(:final failure) => onFailure(failure),
      };
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class FailureResult<T> extends Result<T> {
  final Failure failure;
  const FailureResult(this.failure);
}
