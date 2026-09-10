import 'package:equatable/equatable.dart';

/// Categorized failure types for clear UI presentation and handling
enum FailureType {
  network,
  auth,
  sessionExpired,
  permission,
  validation,
  notFound,
  conflict,
  examExpired,
  examSubmitted,
  videoProcessing,
  server,
  rateLimit,
  unknown,
}

abstract class Failure extends Equatable {
  final String message;
  final String? code;
  final FailureType type;
  final dynamic details;

  const Failure(
    this.message, {
    this.code,
    this.type = FailureType.unknown,
    this.details,
  });

  @override
  List<Object?> get props => [message, code, type, details];
}

class ServerFailure extends Failure {
  const ServerFailure(
    super.message, {
    super.code,
    super.type = FailureType.server,
    super.details,
  });
}

class AuthFailure extends Failure {
  const AuthFailure(
    super.message, {
    super.code,
    super.type = FailureType.auth,
    super.details,
  });
}

class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    super.code,
    super.type = FailureType.network,
    super.details,
  });
}

class CacheFailure extends Failure {
  const CacheFailure(
    super.message, {
    super.code,
    super.type = FailureType.unknown,
    super.details,
  });
}

class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    super.code,
    super.type = FailureType.validation,
    super.details,
  });
}

class PermissionFailure extends Failure {
  const PermissionFailure(
    super.message, {
    super.code,
    super.type = FailureType.permission,
    super.details,
  });
}

class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure(
    super.message, {
    super.code,
    super.type = FailureType.sessionExpired,
    super.details,
  });
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(
    super.message, {
    super.code,
    super.type = FailureType.notFound,
    super.details,
  });
}

class ExamExpiredFailure extends Failure {
  const ExamExpiredFailure(
    super.message, {
    super.code,
    super.type = FailureType.examExpired,
    super.details,
  });
}

class ExamAlreadySubmittedFailure extends Failure {
  const ExamAlreadySubmittedFailure(
    super.message, {
    super.code,
    super.type = FailureType.examSubmitted,
    super.details,
  });
}

class VideoNotReadyFailure extends Failure {
  const VideoNotReadyFailure(
    super.message, {
    super.code,
    super.type = FailureType.videoProcessing,
    super.details,
  });
}

class ConflictFailure extends Failure {
  const ConflictFailure(
    super.message, {
    super.code,
    super.type = FailureType.conflict,
    super.details,
  });
}
