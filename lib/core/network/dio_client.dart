import 'dart:async';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
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

    dio.interceptors.add(_createAuthInterceptor());
  }

  Interceptor _createAuthInterceptor() {
    return QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        // Enforce HTTPS
        if (!options.uri.scheme.startsWith('https')) {
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
        }

        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        // Handle 401 Unauthorized with Mutex queue
        if (error.response?.statusCode == 401) {
          final refreshed = await _handleTokenRefresh();
          if (refreshed) {
            final newToken = await SecureStorageHelper.read(key: 'access_token');
            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newToken';

            try {
              final response = await dio.fetch<dynamic>(retryOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        return handler.next(error);
      },
    );
  }

  /// Mutex lock for token refresh - guarantees only 1 refresh call even if 10 requests 401 concurrently
  static Future<bool> _handleTokenRefresh() async {
    if (_refreshCompleter != null) {
      return await _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await SecureStorageHelper.read(key: 'refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        _refreshCompleter!.complete(false);
        return false;
      }

      // Refresh logic will be hooked into Supabase auth refresh in Auth feature
      // For now, cleanly return false if no active session
      _refreshCompleter!.complete(false);
      return false;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }
}
