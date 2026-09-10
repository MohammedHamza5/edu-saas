class ServerException implements Exception {
  final String message;
  final String? code;

  const ServerException(this.message, {this.code});

  @override
  String toString() => 'ServerException: $message (code: $code)';
}

class NetworkException implements Exception {
  final String message;

  const NetworkException([this.message = 'Network connection error']);

  @override
  String toString() => 'NetworkException: $message';
}

class CacheException implements Exception {
  final String message;

  const CacheException([this.message = 'Cache error']);

  @override
  String toString() => 'CacheException: $message';
}

class AuthRequiredException implements Exception {
  final String message;
  final String? code;

  const AuthRequiredException([this.message = 'Authentication required', this.code]);

  @override
  String toString() => 'AuthRequiredException: $message (code: $code)';
}

class PermissionException implements Exception {
  final String message;
  final String? code;

  const PermissionException([this.message = 'Access denied', this.code]);

  @override
  String toString() => 'PermissionException: $message (code: $code)';
}

class ValidationException implements Exception {
  final String message;
  final String? code;

  const ValidationException([this.message = 'Validation error', this.code]);

  @override
  String toString() => 'ValidationException: $message (code: $code)';
}

class ExamExpiredException implements Exception {
  final String message;
  final String? code;

  const ExamExpiredException([this.message = 'Exam time expired', this.code]);

  @override
  String toString() => 'ExamExpiredException: $message (code: $code)';
}

class ExamAlreadySubmittedException implements Exception {
  final String message;
  final String? code;

  const ExamAlreadySubmittedException([this.message = 'Exam already submitted', this.code]);

  @override
  String toString() => 'ExamAlreadySubmittedException: $message (code: $code)';
}

class ConflictException implements Exception {
  final String message;
  final String? code;

  const ConflictException([this.message = 'Conflict with existing resource or attempt', this.code]);

  @override
  String toString() => 'ConflictException: $message (code: $code)';
}

class VideoNotReadyException implements Exception {
  final String message;
  final String? code;

  const VideoNotReadyException([this.message = 'Video is still processing', this.code]);

  @override
  String toString() => 'VideoNotReadyException: $message (code: $code)';
}

class NotFoundException implements Exception {
  final String message;
  final String? code;

  const NotFoundException([this.message = 'Resource not found', this.code]);

  @override
  String toString() => 'NotFoundException: $message (code: $code)';
}
