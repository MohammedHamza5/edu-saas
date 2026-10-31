import 'dart:async';
import 'dart:io';
import 'package:edu_saas/core/network/retry_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('RetryHelper.isTransient', () {
    test('identifies SocketException and TimeoutException as transient', () {
      expect(RetryHelper.isTransient(const SocketException('failed host lookup')), isTrue);
      expect(RetryHelper.isTransient(TimeoutException('timed out')), isTrue);
      expect(RetryHelper.isTransient(const HttpException('Connection reset by peer')), isTrue);
    });

    test('identifies browser fetch and network errors as transient', () {
      expect(RetryHelper.isTransient(Exception('TypeError: Failed to fetch')), isTrue);
      expect(RetryHelper.isTransient(Exception('ClientException: XMLHttpRequest error.')), isTrue);
      expect(RetryHelper.isTransient(Exception('net::ERR_CONNECTION_RESET')), isTrue);
    });

    test('identifies transient PostgrestException codes and messages', () {
      expect(
        RetryHelper.isTransient(
          const PostgrestException(message: 'Statement timed out', code: '57014'),
        ),
        isTrue,
      );
      expect(
        RetryHelper.isTransient(
          const PostgrestException(message: 'Connection exception', code: '08006'),
        ),
        isTrue,
      );
      expect(
        RetryHelper.isTransient(
          const PostgrestException(message: '502 Bad Gateway from cloudflare'),
        ),
        isTrue,
      );
    });

    test('does NOT identify RLS or business validation errors as transient', () {
      expect(
        RetryHelper.isTransient(
          const PostgrestException(message: 'new row violates row-level security policy', code: '42501'),
        ),
        isFalse,
      );
      expect(
        RetryHelper.isTransient(
          const PostgrestException(message: 'JSON object requested, multiple (or no) rows returned', code: 'PGRST116'),
        ),
        isFalse,
      );
      expect(
        RetryHelper.isTransient(FormatException('Invalid JSON format')),
        isFalse,
      );
    });
  });

  group('RetryHelper.retry', () {
    test('succeeds immediately on attempt 1 if no error', () async {
      int executions = 0;
      final result = await RetryHelper.retry(
        () async {
          executions++;
          return 'success_val';
        },
        policy: const RetryPolicy(maxAttempts: 3),
      );

      expect(result, 'success_val');
      expect(executions, 1);
    });

    test('retries transient failure and succeeds on attempt 2', () async {
      int executions = 0;
      final retryAttempts = <int>[];

      final result = await RetryHelper.retry(
        () async {
          executions++;
          if (executions == 1) {
            throw Exception('TypeError: Failed to fetch');
          }
          return 'recovered_data';
        },
        policy: const RetryPolicy(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 10),
          jitter: Duration.zero,
        ),
        onRetry: (_, attempt, __) => retryAttempts.add(attempt),
      );

      expect(result, 'recovered_data');
      expect(executions, 2);
      expect(retryAttempts, [1]);
    });

    test('rethrows if non-transient error occurs without retrying', () async {
      int executions = 0;

      await expectLater(
        () => RetryHelper.retry(
          () async {
            executions++;
            throw const PostgrestException(message: 'Forbidden', code: '42501');
          },
          policy: const RetryPolicy(maxAttempts: 3),
        ),
        throwsA(isA<PostgrestException>()),
      );

      expect(executions, 1);
    });

    test('rethrows after exhausting maxAttempts for continuous transient error', () async {
      int executions = 0;

      await expectLater(
        () => RetryHelper.retry(
          () async {
            executions++;
            throw const SocketException('Connection refused');
          },
          policy: const RetryPolicy(
            maxAttempts: 3,
            initialDelay: Duration(milliseconds: 5),
            jitter: Duration.zero,
          ),
        ),
        throwsA(isA<SocketException>()),
      );

      expect(executions, 3);
    });
  });
}
