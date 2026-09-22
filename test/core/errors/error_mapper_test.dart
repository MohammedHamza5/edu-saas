import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/error_mapper.dart';
import 'package:edu_saas/core/errors/exceptions.dart';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ErrorMapper Tests', () {
    test('resolves NetworkFailure correctly', () {
      const failure = NetworkFailure('Failed to connect');
      final error = ErrorMapper.resolve(failure);

      expect(error.type, FailureType.network);
      expect(error.canRetry, isTrue);
      expect(error.icon, Icons.wifi_off_rounded);
    });

    test('resolves SocketException to network failure', () {
      const exception = SocketException('Failed host lookup: api.supabase.co');
      final error = ErrorMapper.resolve(exception);

      expect(error.type, FailureType.network);
      expect(error.canRetry, isTrue);
      expect(error.icon, Icons.wifi_off_rounded);
    });

    test('resolves TimeoutException to timeout network failure', () {
      final exception = TimeoutException('Connection timed out');
      final error = ErrorMapper.resolve(exception);

      expect(error.type, FailureType.network);
      expect(error.canRetry, isTrue);
      expect(error.icon, Icons.timer_off_outlined);
    });

    test('resolves AuthException with invalid credentials', () {
      const exception = AuthException('Invalid login credentials');
      final error = ErrorMapper.resolve(exception);

      expect(error.type, FailureType.auth);
      expect(error.canRetry, isFalse);
      expect(error.icon, Icons.lock_outline_rounded);
    });

    test('resolves AuthException with TENANT_SUSPENDED', () {
      const exception = AuthException('TENANT_SUSPENDED');
      final error = ErrorMapper.resolve(exception);

      expect(error.type, FailureType.permission);
      expect(error.icon, Icons.block_rounded);
    });

    test('resolves PostgrestException 42501 (RLS violation) to permission error', () {
      const exception = PostgrestException(
        message: 'new row violates row-level security policy for table students',
        code: '42501',
      );
      final error = ErrorMapper.resolve(exception);

      expect(error.type, FailureType.permission);
      expect(error.icon, Icons.shield_outlined);
    });

    test('resolves PostgrestException exam_expired to ExamExpired error', () {
      const exception = PostgrestException(message: 'EXAM_EXPIRED error');
      final error = ErrorMapper.resolve(exception);

      expect(error.type, FailureType.examExpired);
      expect(error.canRetry, isFalse);
      expect(error.icon, Icons.alarm_off_rounded);
    });

    test('resolves VideoNotReadyException correctly', () {
      const exception = VideoNotReadyException('Processing video');
      final error = ErrorMapper.resolve(exception);

      expect(error.type, FailureType.videoProcessing);
      expect(error.canRetry, isTrue);
      expect(error.icon, Icons.hourglass_top_rounded);
    });

    test('resolves raw string error containing network error keywords', () {
      final error = ErrorMapper.resolve('ClientException: Connection reset by peer');

      expect(error.type, FailureType.network);
      expect(error.canRetry, isTrue);
    });

    test('resolves AuthException with invalid email address to emailInvalidError', () {
      const exception = AuthException(
        'Email address "test@gmail.com" is invalid',
        code: 'email_address_invalid',
        statusCode: '400',
      );
      final error = ErrorMapper.resolve(exception);

      expect(error.type, FailureType.validation);
      expect(error.canRetry, isFalse);
      expect(error.icon, Icons.alternate_email_rounded);
    });

    test('resolves AuthFailure with email_address_invalid to emailInvalidError', () {
      const failure = AuthFailure(
        'Email address "test@gmail.com" is invalid',
        code: 'email_address_invalid',
      );
      final error = ErrorMapper.resolve(failure);

      expect(error.type, FailureType.validation);
      expect(error.canRetry, isFalse);
      expect(error.icon, Icons.alternate_email_rounded);
    });

    test('resolves raw string for invalid email to emailInvalidError', () {
      final error = ErrorMapper.resolve('400: Email address "test@gmail.com" is invalid');

      expect(error.type, FailureType.validation);
      expect(error.canRetry, isFalse);
      expect(error.icon, Icons.alternate_email_rounded);
    });

    test('resolves duplicate email registration to emailAlreadyExistsError', () {
      const failure = AuthFailure('User already registered', code: 'user_already_exists');
      final error = ErrorMapper.resolve(failure);

      expect(error.type, FailureType.conflict);
      expect(error.canRetry, isFalse);
      expect(error.icon, Icons.person_off_rounded);
    });

    test('resolves weak password to weakPasswordError', () {
      const failure = AuthFailure('Password should be at least 6 characters', code: 'weak_password');
      final error = ErrorMapper.resolve(failure);

      expect(error.type, FailureType.validation);
      expect(error.canRetry, isFalse);
      expect(error.icon, Icons.password_rounded);
    });

    test('resolves rate limit to rateLimitError', () {
      const failure = AuthFailure('Rate limit exceeded', code: 'over_email_send_rate_limit');
      final error = ErrorMapper.resolve(failure);

      expect(error.type, FailureType.rateLimit);
      expect(error.canRetry, isTrue);
      expect(error.icon, Icons.hourglass_empty_rounded);
    });

    test('generates clean diagnostic summary for tech support', () {
      const failure = NetworkFailure('Test failure', code: 'NET_TEST');
      final error = ErrorMapper.resolve(failure);
      final summary = error.toDiagnosticSummary();

      expect(summary, contains('Code: NET_TEST'));
      expect(summary, contains('Type: network'));
      expect(summary, contains('Timestamp:'));
    });
  });
}
