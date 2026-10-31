import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';
import 'supabase_service.dart';

/// Configuration options for transient network operation retries.
class RetryPolicy {
  /// Maximum number of execution attempts before rethrowing the error.
  final int maxAttempts;

  /// Initial backoff delay before the first retry attempt.
  final Duration initialDelay;

  /// Multiplier applied to the delay on each subsequent retry attempt.
  final double backoffMultiplier;

  /// Upper bound ceiling for the backoff delay.
  final Duration maxDelay;

  /// Maximum jitter duration added to the delay to prevent thundering herd spikes.
  final Duration jitter;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 250),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 2),
    this.jitter = const Duration(milliseconds: 80),
  });

  /// Standard policy for fast idempotent GET / read queries on Flutter Web.
  static const RetryPolicy fastWebRead = RetryPolicy(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 200),
    backoffMultiplier: 2.0,
    maxDelay: Duration(milliseconds: 1200),
    jitter: Duration(milliseconds: 50),
  );
}

/// Robust resilience helper that executes asynchronous operations with
/// exponential backoff and jitter for transient network, handshake, and transport hiccups.
class RetryHelper {
  const RetryHelper._();

  static final Random _random = Random();

  /// Determines whether an error is transient (e.g. dropped socket, SSL handshake,
  /// browser fetch failure, 502/503/504 gateway error) and safe to retry.
  static bool isTransient(Object error) {
    if (error is SocketException ||
        error is HttpException ||
        error is TimeoutException) {
      return true;
    }

    if (error is PostgrestException) {
      final code = error.code ?? '';
      final msg = error.message.toLowerCase();

      // PostgreSQL connection exceptions (SQLSTATE class 08) or statement cancel (57014)
      if (code.startsWith('08') || code == '57014' || code == 'PGRST000') {
        return true;
      }

      // Gateway / Server capacity / Transport errors reported via PostgREST
      if (msg.contains('bad gateway') ||
          msg.contains('gateway timeout') ||
          msg.contains('service unavailable') ||
          msg.contains('server is busy') ||
          msg.contains('connection refused') ||
          msg.contains('connection reset') ||
          msg.contains('network error') ||
          msg.contains('failed to fetch')) {
        return true;
      }

      // Explicitly reject non-transient PostgREST errors (RLS 42501, not found PGRST116, validation)
      return false;
    }

    final lower = error.toString().toLowerCase();

    // Browser Web / Fetch / Socket transport error signatures
    return lower.contains('failed to fetch') ||
        lower.contains('load failed') ||
        lower.contains('typeerror: failed to fetch') ||
        lower.contains('typeerror: load failed') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('clientexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('networkerror') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('connection refused') ||
        lower.contains('connection aborted') ||
        lower.contains('broken pipe') ||
        lower.contains('net::err') ||
        lower.contains('err_internet_disconnected') ||
        lower.contains('err_name_not_resolved') ||
        lower.contains('err_connection_refused') ||
        lower.contains('err_connection_timed_out') ||
        lower.contains('err_connection_reset') ||
        lower.contains('host lookup failed') ||
        lower.contains('failed host lookup') ||
        lower.contains('http status code 0') ||
        lower.contains('status code 0');
  }

  /// Executes [operation] with exponential backoff and jitter.
  ///
  /// Retries are triggered ONLY if [isTransient] evaluates to true (or [shouldRetry] if provided).
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    RetryPolicy policy = const RetryPolicy(),
    bool Function(Object error)? shouldRetry,
    void Function(Object error, int attempt, Duration delay)? onRetry,
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        return await operation();
      } catch (error) {
        final canRetry = (shouldRetry != null)
            ? shouldRetry(error)
            : isTransient(error);

        if (attempt >= policy.maxAttempts || !canRetry) {
          rethrow;
        }

        // If the transient error mentions JWT or token expiry, proactively refresh auth session
        final errorStr = error.toString().toLowerCase();
        if (errorStr.contains('jwt') || errorStr.contains('token')) {
          try {
            await SupabaseService.ensureFreshSession();
          } catch (_) {}
        }

        // Calculate jittered exponential backoff:
        // delay = min(initialDelay * (multiplier ^ (attempt - 1)), maxDelay) + random(jitter)
        final exponentialMs = policy.initialDelay.inMilliseconds *
            pow(policy.backoffMultiplier, attempt - 1);
        final clampedMs =
            min(exponentialMs.toInt(), policy.maxDelay.inMilliseconds);
        final jitterMs = policy.jitter.inMilliseconds > 0
            ? _random.nextInt(policy.jitter.inMilliseconds)
            : 0;
        final totalDelay = Duration(milliseconds: clampedMs + jitterMs);

        AppLogger.w(
          'RetryHelper',
          'Transient network glitch on attempt $attempt/${policy.maxAttempts}. '
          'Retrying in ${totalDelay.inMilliseconds}ms... (Error: $error)',
        );

        onRetry?.call(error, attempt, totalDelay);
        await Future<void>.delayed(totalDelay);
      }
    }
  }
}

/// Convenience top-level alias for [RetryHelper.retry].
Future<T> retryTransient<T>(
  Future<T> Function() operation, {
  RetryPolicy policy = const RetryPolicy(),
  bool Function(Object error)? shouldRetry,
  void Function(Object error, int attempt, Duration delay)? onRetry,
}) =>
    RetryHelper.retry<T>(
      operation,
      policy: policy,
      shouldRetry: shouldRetry,
      onRetry: onRetry,
    );
