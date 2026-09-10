import 'dart:async';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';
import '../utils/secure_storage_helper.dart';

/// Enterprise-grade Dio Network Client
/// Implements OWASP MASVS secure network standards, token injection, and refresh mutex.
class DioClient {
  late final Dio dio;
  static Completer<bool>? _refreshCompleter;

  DioClient({BaseOptions? options}) {
    dio = Dio(
      options ??
          BaseOptions(
            baseUrl: AppConfig.supabaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
    );

    dio.interceptors.add(_createLoggingInterceptor());
    dio.interceptors.add(_createAuthInterceptor());

    AppLogger.i('DioClient', 'HTTP client initialized', data: {
      'baseUrl': AppConfig.supabaseUrl,
      'timeouts': '15s connect / 15s receive / 15s send',
    });
  }

  /// 📡 Logging Interceptor — logs every request, response, and error
  Interceptor _createLoggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        AppLogger.n(
          'HTTP→',
          '${options.method} ${options.path}',
          data: {
            'queryParams': options.queryParameters.isNotEmpty ? options.queryParameters : null,
            'hasBody': options.data != null,
          },
        );
        return handler.next(options);
      },
      onResponse: (response, handler) {
        final statusCode = response.statusCode ?? 0;
        final isSuccess = statusCode >= 200 && statusCode < 300;

        if (isSuccess) {
          AppLogger.n(
            'HTTP←',
            '${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}',
            data: {
              'dataType': response.data.runtimeType.toString(),
            },
          );
        } else {
          AppLogger.w(
            'HTTP←',
            'Non-2xx response: ${response.statusCode} ${response.requestOptions.path}',
            data: response.data,
          );
        }
        return handler.next(response);
      },
      onError: (DioException error, handler) {
        AppLogger.e(
          'HTTP⚠',
          'Request failed: ${error.requestOptions.method} ${error.requestOptions.path}',
          error: error,
          stackTrace: error.stackTrace,
        );
        AppLogger.d('HTTP⚠', 'Error detail', data: {
          'type': error.type.name,
          'statusCode': error.response?.statusCode,
          'responseBody': error.response?.data,
        });
        return handler.next(error);
      },
    );
  }

  Interceptor _createAuthInterceptor() {
    return QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        // Enforce HTTPS
        if (!options.uri.scheme.startsWith('https')) {
          AppLogger.e(
            'DioClient',
            '🔒 SECURITY BLOCK — HTTP cleartext request blocked: ${options.uri}',
          );
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'Cleartext HTTP connection blocked by enterprise security policy.',
            ),
          );
        }

        final token = await SecureStorageHelper.read(key: 'access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
          AppLogger.d('DioClient', 'Auth token injected into request');
        } else {
          AppLogger.d('DioClient', 'No auth token found — sending unauthenticated request');
        }

        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        // Handle 401 Unauthorized with Mutex queue
        if (error.response?.statusCode == 401) {
          AppLogger.w('DioClient', '401 Unauthorized — attempting token refresh');
          final refreshed = await _handleTokenRefresh();
          if (refreshed) {
            AppLogger.s('DioClient', 'Token refreshed — retrying original request');
            final newToken = await SecureStorageHelper.read(key: 'access_token');
            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newToken';

            try {
              final response = await dio.fetch<dynamic>(retryOptions);
              return handler.resolve(response);
            } catch (e) {
              AppLogger.e('DioClient', 'Retry after token refresh also failed', error: e);
              return handler.next(error);
            }
          } else {
            AppLogger.w('DioClient', 'Token refresh failed — user will be logged out');
          }
        }
        return handler.next(error);
      },
    );
  }

  /// Mutex lock for token refresh - guarantees only 1 refresh call even if 10 requests 401 concurrently
  static Future<bool> _handleTokenRefresh() async {
    if (_refreshCompleter != null) {
      AppLogger.d('DioClient', 'Token refresh already in progress — waiting for result');
      return await _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await SecureStorageHelper.read(key: 'refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.w('DioClient', 'No refresh_token found in secure storage — cannot refresh');
        _refreshCompleter!.complete(false);
        return false;
      }

      // Refresh logic will be hooked into Supabase auth refresh in Auth feature
      // For now, cleanly return false if no active session
      _refreshCompleter!.complete(false);
      return false;
    } catch (e, st) {
      AppLogger.e('DioClient', 'Token refresh threw an exception', error: e, stackTrace: st);
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
}
