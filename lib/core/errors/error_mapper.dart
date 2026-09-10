import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../localization/generated/app_localizations.dart';
import 'exceptions.dart';
import 'failures.dart';

/// Representation of an analyzed, user-facing error with full localization support.
class UserFriendlyError {
  final FailureType type;
  final String code;
  final String Function(AppLocalizations l10n) titleBuilder;
  final String Function(AppLocalizations l10n) messageBuilder;
  final String? Function(AppLocalizations l10n)? hintBuilder;
  final IconData icon;
  final bool canRetry;
  final bool isSessionExpired;
  final dynamic rawError;

  const UserFriendlyError({
    required this.type,
    required this.code,
    required this.titleBuilder,
    required this.messageBuilder,
    this.hintBuilder,
    required this.icon,
    this.canRetry = true,
    this.isSessionExpired = false,
    this.rawError,
  });

  /// Evaluates the localized title using the current context.
  String title(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return 'Error';
    return titleBuilder(l10n);
  }

  /// Evaluates the localized description using the current context.
  String message(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return rawError?.toString() ?? 'An unexpected error occurred.';
    return messageBuilder(l10n);
  }

  /// Evaluates the actionable recommendation using the current context.
  String? hint(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null || hintBuilder == null) return null;
    return hintBuilder!(l10n);
  }

  /// Generates a clean technical summary formatted for copy-pasting to tech support.
  String toDiagnosticSummary() {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final raw = rawError?.toString() ?? 'N/A';
    return '--- Issue Report ---\n'
        'Code: $code\n'
        'Type: ${type.name}\n'
        'Timestamp: $timestamp\n'
        'Raw: $raw\n'
        '--------------------';
  }
}

/// Intelligent centralized resolver that maps exceptions, failures, or raw error strings
/// to clear, localized [UserFriendlyError] representations.
class ErrorMapper {
  const ErrorMapper._();

  /// Resolves any error into a [UserFriendlyError].
  static UserFriendlyError resolve(
    dynamic error, {
    FailureType? overrideType,
    String? customCode,
  }) {
    if (error is UserFriendlyError) return error;

    // ── 1. If it's already a domain Failure ─────────────────────────────────
    if (error is Failure) {
      return _mapFailure(error, customCode: customCode);
    }

    // ── 2. If it's a domain Exception ───────────────────────────────────────
    if (error is Exception) {
      return _mapException(error, customCode: customCode);
    }

    // ── 3. Fallback for strings or unknown types ────────────────────────────
    return _mapStringOrUnknown(error?.toString() ?? '', customCode: customCode);
  }

  static UserFriendlyError _mapFailure(Failure failure, {String? customCode}) {
    switch (failure.type) {
      case FailureType.network:
        return _networkError(customCode ?? failure.code ?? 'NET_001', raw: failure);
      case FailureType.auth:
        return _authError(failure.message, customCode ?? failure.code ?? 'AUTH_001', raw: failure);
      case FailureType.sessionExpired:
        return _sessionExpiredError(customCode ?? failure.code ?? 'AUTH_401', raw: failure);
      case FailureType.permission:
        return _permissionError(customCode ?? failure.code ?? 'SEC_403', raw: failure);
      case FailureType.validation:
        return _validationError(failure.message, customCode ?? failure.code ?? 'VAL_001', raw: failure);
      case FailureType.notFound:
        return _notFoundError(customCode ?? failure.code ?? 'RES_404', raw: failure);
      case FailureType.examExpired:
        return _examExpiredError(customCode ?? failure.code ?? 'EXAM_001', raw: failure);
      case FailureType.examSubmitted:
        return _examSubmittedError(customCode ?? failure.code ?? 'EXAM_002', raw: failure);
      case FailureType.videoProcessing:
        return _videoProcessingError(customCode ?? failure.code ?? 'VID_001', raw: failure);
      case FailureType.rateLimit:
        return _rateLimitError(customCode ?? failure.code ?? 'RATE_429', raw: failure);
      case FailureType.conflict:
        return _conflictError(failure.message, customCode ?? failure.code ?? 'CONF_001', raw: failure);
      case FailureType.server:
      case FailureType.unknown:
        // Check message string for known patterns before defaulting to generic server
        return _mapStringOrUnknown(failure.message, customCode: customCode ?? failure.code);
    }
  }

  static UserFriendlyError _mapException(Exception exception, {String? customCode}) {
    // ── Supabase Auth Exceptions ──
    if (exception is AuthException) {
      final msg = exception.message.toLowerCase();
      final code = exception.statusCode ?? 'AUTH_001';

      if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
        return _invalidCredentialsError(customCode ?? 'AUTH_CREDS', raw: exception);
      }
      if (msg.contains('tenant_suspended')) {
        return _tenantSuspendedError(customCode ?? 'TENANT_SUSPENDED', raw: exception);
      }
      if (msg.contains('expired') || msg.contains('jwt')) {
        return _sessionExpiredError(customCode ?? 'AUTH_EXPIRED', raw: exception);
      }
      if (msg.contains('already registered') || msg.contains('unique') || msg.contains('email_exists')) {
        return _authError(exception.message, customCode ?? 'AUTH_DUP', raw: exception);
      }
      return _authError(exception.message, customCode ?? code, raw: exception);
    }

    // ── Supabase Postgrest Exceptions ──
    if (exception is PostgrestException) {
      final code = exception.code ?? '';
      final msg = exception.message.toLowerCase();

      // RLS or permission error
      if (code == '42501' || msg.contains('row-level security') || msg.contains('permission denied')) {
        return _permissionError(customCode ?? 'SEC_RLS_42501', raw: exception);
      }
      // Not found error
      if (code == 'PGRST116') {
        return _notFoundError(customCode ?? 'RES_PGRST116', raw: exception);
      }
      // Business rules
      if (msg.contains('exam_expired')) {
        return _examExpiredError(customCode ?? 'EXAM_EXP', raw: exception);
      }
      if (msg.contains('exam_already_submitted')) {
        return _examSubmittedError(customCode ?? 'EXAM_SUBMITTED', raw: exception);
      }
      if (msg.contains('attempts_limit_reached')) {
        return _attemptsLimitReachedError(customCode ?? 'EXAM_LIMIT', raw: exception);
      }
      if (msg.contains('video_not_ready')) {
        return _videoProcessingError(customCode ?? 'VID_PROCESSING', raw: exception);
      }
      if (msg.contains('content_not_published')) {
        return _contentNotPublishedError(customCode ?? 'CONTENT_UNPUB', raw: exception);
      }

      return _serverError(customCode ?? (code.isNotEmpty ? 'PG_$code' : 'SRV_500'), raw: exception);
    }

    // ── Domain Exceptions ──
    if (exception is PermissionException) {
      return _permissionError(customCode ?? exception.code ?? 'SEC_403', raw: exception);
    }
    if (exception is AuthRequiredException) {
      return _sessionExpiredError(customCode ?? exception.code ?? 'AUTH_401', raw: exception);
    }
    if (exception is ExamExpiredException) {
      return _examExpiredError(customCode ?? exception.code ?? 'EXAM_EXP', raw: exception);
    }
    if (exception is ExamAlreadySubmittedException) {
      return _examSubmittedError(customCode ?? exception.code ?? 'EXAM_SUB', raw: exception);
    }
    if (exception is VideoNotReadyException) {
      return _videoProcessingError(customCode ?? exception.code ?? 'VID_PROC', raw: exception);
    }
    if (exception is ValidationException) {
      return _validationError(exception.message, customCode ?? exception.code ?? 'VAL_001', raw: exception);
    }
    if (exception is NotFoundException) {
      return _notFoundError(customCode ?? exception.code ?? 'RES_404', raw: exception);
    }
    if (exception is ConflictException) {
      return _conflictError(exception.message, customCode ?? exception.code ?? 'CONF_001', raw: exception);
    }

    // ── Transport & Network Exceptions ──
    if (exception is TimeoutException) {
      return _timeoutError(customCode ?? 'NET_TIMEOUT', raw: exception);
    }
    if (exception is SocketException ||
        exception is HttpException ||
        exception is NetworkException) {
      return _networkError(customCode ?? 'NET_001', raw: exception);
    }

    return _mapStringOrUnknown(exception.toString(), customCode: customCode);
  }

  static UserFriendlyError _mapStringOrUnknown(String text, {String? customCode}) {
    final lower = text.toLowerCase();

    // Network indicators
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('clientexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('network error') ||
        lower.contains('network connection error')) {
      return _networkError(customCode ?? 'NET_001', raw: text);
    }

    // Timeout
    if (lower.contains('timeoutexception') || lower.contains('timed out') || lower.contains('deadline exceeded')) {
      return _timeoutError(customCode ?? 'NET_TIMEOUT', raw: text);
    }

    // Auth indicators
    if (lower.contains('invalid login credentials') || lower.contains('invalid_credentials')) {
      return _invalidCredentialsError(customCode ?? 'AUTH_CREDS', raw: text);
    }
    if (lower.contains('tenant_suspended')) {
      return _tenantSuspendedError(customCode ?? 'TENANT_SUSPENDED', raw: text);
    }
    if (lower.contains('jwt expired') || lower.contains('token expired') || lower.contains('session expired')) {
      return _sessionExpiredError(customCode ?? 'AUTH_EXPIRED', raw: text);
    }

    // Permissions
    if (lower.contains('row-level security') ||
        lower.contains('permission denied') ||
        lower.contains('not_authorized') ||
        lower.contains('42501')) {
      return _permissionError(customCode ?? 'SEC_403', raw: text);
    }

    // Exams
    if (lower.contains('exam_expired')) {
      return _examExpiredError(customCode ?? 'EXAM_EXP', raw: text);
    }
    if (lower.contains('exam_already_submitted')) {
      return _examSubmittedError(customCode ?? 'EXAM_SUB', raw: text);
    }
    if (lower.contains('attempts_limit_reached')) {
      return _attemptsLimitReachedError(customCode ?? 'EXAM_LIMIT', raw: text);
    }

    // Video
    if (lower.contains('video_not_ready')) {
      return _videoProcessingError(customCode ?? 'VID_PROC', raw: text);
    }

    // Default server/unknown error
    return _serverError(customCode ?? 'SRV_500', raw: text);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Builders for distinct error archetypes
  // ──────────────────────────────────────────────────────────────────────────

  static UserFriendlyError _networkError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.network,
        code: code,
        titleBuilder: (l10n) => l10n.errorNoInternetTitle,
        messageBuilder: (l10n) => l10n.errorNoInternetMessage,
        hintBuilder: (l10n) => l10n.errorNoInternetHint,
        icon: Icons.wifi_off_rounded,
        canRetry: true,
        rawError: raw,
      );

  static UserFriendlyError _timeoutError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.network,
        code: code,
        titleBuilder: (l10n) => l10n.errorTimeoutTitle,
        messageBuilder: (l10n) => l10n.errorTimeoutMessage,
        hintBuilder: (l10n) => l10n.errorTimeoutHint,
        icon: Icons.timer_off_outlined,
        canRetry: true,
        rawError: raw,
      );

  static UserFriendlyError _invalidCredentialsError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.auth,
        code: code,
        titleBuilder: (l10n) => l10n.errorInvalidCredentialsTitle,
        messageBuilder: (l10n) => l10n.errorInvalidCredentialsMessage,
        hintBuilder: (l10n) => l10n.errorInvalidCredentialsHint,
        icon: Icons.lock_outline_rounded,
        canRetry: false,
        rawError: raw,
      );

  static UserFriendlyError _sessionExpiredError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.sessionExpired,
        code: code,
        titleBuilder: (l10n) => l10n.errorSessionExpiredTitle,
        messageBuilder: (l10n) => l10n.errorSessionExpiredMessage,
        hintBuilder: (l10n) => l10n.errorSessionExpiredHint,
        icon: Icons.history_rounded,
        canRetry: false,
        isSessionExpired: true,
        rawError: raw,
      );

  static UserFriendlyError _tenantSuspendedError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.permission,
        code: code,
        titleBuilder: (l10n) => l10n.errorAccountSuspendedTitle,
        messageBuilder: (l10n) => l10n.tenantSuspendedMessage,
        hintBuilder: (l10n) => l10n.errorAccountSuspendedHint,
        icon: Icons.block_rounded,
        canRetry: false,
        rawError: raw,
      );

  static UserFriendlyError _permissionError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.permission,
        code: code,
        titleBuilder: (l10n) => l10n.errorAccessDeniedTitle,
        messageBuilder: (l10n) => l10n.errorAccessDeniedMessage,
        hintBuilder: (l10n) => l10n.errorAccessDeniedHint,
        icon: Icons.shield_outlined,
        canRetry: false,
        rawError: raw,
      );

  static UserFriendlyError _videoProcessingError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.videoProcessing,
        code: code,
        titleBuilder: (l10n) => l10n.errorVideoProcessingTitle,
        messageBuilder: (l10n) => l10n.errorVideoProcessingMessage,
        hintBuilder: (l10n) => l10n.errorVideoProcessingHint,
        icon: Icons.hourglass_top_rounded,
        canRetry: true,
        rawError: raw,
      );

  static UserFriendlyError _examExpiredError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.examExpired,
        code: code,
        titleBuilder: (l10n) => l10n.errorExamExpiredTitle,
        messageBuilder: (l10n) => l10n.errorExamExpiredMessage,
        hintBuilder: (l10n) => l10n.errorExamExpiredHint,
        icon: Icons.alarm_off_rounded,
        canRetry: false,
        rawError: raw,
      );

  static UserFriendlyError _examSubmittedError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.examSubmitted,
        code: code,
        titleBuilder: (l10n) => l10n.errorExamAlreadySubmittedTitle,
        messageBuilder: (l10n) => l10n.errorExamAlreadySubmittedMessage,
        hintBuilder: (l10n) => l10n.errorExamAlreadySubmittedHint,
        icon: Icons.assignment_turned_in_rounded,
        canRetry: false,
        rawError: raw,
      );

  static UserFriendlyError _attemptsLimitReachedError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.examExpired,
        code: code,
        titleBuilder: (l10n) => l10n.errorAttemptsLimitReachedTitle,
        messageBuilder: (l10n) => l10n.errorAttemptsLimitReachedMessage,
        hintBuilder: (l10n) => l10n.errorAttemptsLimitReachedHint,
        icon: Icons.highlight_off_rounded,
        canRetry: false,
        rawError: raw,
      );

  static UserFriendlyError _contentNotPublishedError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.notFound,
        code: code,
        titleBuilder: (l10n) => l10n.errorContentNotPublishedTitle,
        messageBuilder: (l10n) => l10n.errorContentNotPublishedMessage,
        hintBuilder: (l10n) => l10n.errorContentNotPublishedHint,
        icon: Icons.visibility_off_rounded,
        canRetry: false,
        rawError: raw,
      );

  static UserFriendlyError _notFoundError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.notFound,
        code: code,
        titleBuilder: (l10n) => l10n.errorNotFoundTitle,
        messageBuilder: (l10n) => l10n.errorNotFoundMessage,
        hintBuilder: (l10n) => l10n.errorNotFoundHint,
        icon: Icons.search_off_rounded,
        canRetry: false,
        rawError: raw,
      );

  static UserFriendlyError _validationError(String message, String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.validation,
        code: code,
        titleBuilder: (l10n) => l10n.errorValidationTitle,
        messageBuilder: (l10n) => message.isNotEmpty ? message : l10n.errorValidationMessage,
        hintBuilder: (l10n) => l10n.errorValidationHint,
        icon: Icons.info_outline_rounded,
        canRetry: false,
        rawError: raw,
      );

  static UserFriendlyError _conflictError(String message, String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.conflict,
        code: code,
        titleBuilder: (l10n) => l10n.errorOccurred,
        messageBuilder: (l10n) => message.isNotEmpty ? message : l10n.errorOccurred,
        icon: Icons.sync_problem_rounded,
        canRetry: true,
        rawError: raw,
      );

  static UserFriendlyError _authError(String message, String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.auth,
        code: code,
        titleBuilder: (l10n) => l10n.errorInvalidCredentialsTitle,
        messageBuilder: (l10n) => message.isNotEmpty ? message : l10n.errorInvalidCredentialsMessage,
        hintBuilder: (l10n) => l10n.errorInvalidCredentialsHint,
        icon: Icons.lock_outline_rounded,
        canRetry: false,
        rawError: raw,
      );

  static UserFriendlyError _rateLimitError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.rateLimit,
        code: code,
        titleBuilder: (l10n) => l10n.errorTimeoutTitle,
        messageBuilder: (l10n) => l10n.errorTimeoutMessage,
        hintBuilder: (l10n) => l10n.errorTimeoutHint,
        icon: Icons.hourglass_empty_rounded,
        canRetry: true,
        rawError: raw,
      );

  static UserFriendlyError _serverError(String code, {dynamic raw}) => UserFriendlyError(
        type: FailureType.server,
        code: code,
        titleBuilder: (l10n) => l10n.errorServerTitle,
        messageBuilder: (l10n) => l10n.errorServerMessage,
        hintBuilder: (l10n) => l10n.errorServerHint,
        icon: Icons.cloud_off_rounded,
        canRetry: true,
        rawError: raw,
      );
}
