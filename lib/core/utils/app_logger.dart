import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// 🪵 AppLogger — Central Logging System for EduSaaS
///
/// Provides structured, colored, timestamped logs for every layer:
/// - [d] DEBUG   → Gray   → development details
/// - [i] INFO    → Cyan   → important lifecycle events
/// - [w] WARNING → Yellow → non-fatal issues
/// - [e] ERROR   → Red    → errors with full stack trace
///
/// Usage:
/// ```dart
/// AppLogger.i('Auth', 'User logged in: $email');
/// AppLogger.e('Network', 'Request failed', error: e, stackTrace: st);
/// ```
class AppLogger {
  AppLogger._();

  // ANSI color codes (visible in Android Studio / VS Code debug console)
  static const _reset = '\x1B[0m';
  static const _gray = '\x1B[90m';
  static const _cyan = '\x1B[36m';
  static const _yellow = '\x1B[33m';
  static const _red = '\x1B[31m';
  static const _green = '\x1B[32m';
  static const _magenta = '\x1B[35m';
  static const _blue = '\x1B[34m';

  static bool _enabled = true;

  /// Enable or disable all logging (e.g., disable in release for performance)
  static void setEnabled(bool enabled) => _enabled = enabled;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// 🔍 DEBUG — Low-level implementation detail (only in debug mode)
  static void d(String tag, String message, {Object? data}) {
    if (!kDebugMode) return;
    _log(level: 'DEBUG', tag: tag, message: message, data: data, color: _gray, emoji: '🔍');
  }

  /// ℹ️ INFO — Important lifecycle or business event
  static void i(String tag, String message, {Object? data}) {
    _log(level: 'INFO ', tag: tag, message: message, data: data, color: _cyan, emoji: 'ℹ️');
  }

  /// ⚠️ WARNING — Something unexpected but non-fatal
  static void w(String tag, String message, {Object? data}) {
    _log(level: 'WARN ', tag: tag, message: message, data: data, color: _yellow, emoji: '⚠️');
  }

  /// ❌ ERROR — Fatal or serious error with optional stack trace
  static void e(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!_enabled) return;
    final now = _timestamp();
    final header = '$_red[$now][ERROR][$tag] ❌ $message$_reset';

    if (kDebugMode) {
      // ignore: avoid_print
      print(header);
      if (error != null) {
        // ignore: avoid_print
        print('$_red  ↳ Exception: $error$_reset');
      }
      if (stackTrace != null) {
        // ignore: avoid_print
        print('$_red  ↳ StackTrace:\n$stackTrace$_reset');
      }
    }

    developer.log(
      message,
      name: tag,
      error: error,
      stackTrace: stackTrace,
      level: 1000, // severe
      time: DateTime.now(),
    );
  }

  /// ✅ SUCCESS — Successful completion of an important operation
  static void s(String tag, String message, {Object? data}) {
    _log(level: 'OK   ', tag: tag, message: message, data: data, color: _green, emoji: '✅');
  }

  /// 🌐 NETWORK — HTTP/Supabase request/response tracking
  static void n(String tag, String message, {Object? data}) {
    _log(level: 'NET  ', tag: tag, message: message, data: data, color: _blue, emoji: '🌐');
  }

  /// 🧩 BLOC — Cubit/Bloc state transition
  static void b(String tag, String message, {Object? data}) {
    _log(level: 'BLOC ', tag: tag, message: message, data: data, color: _magenta, emoji: '🧩');
  }

  /// 🛣️ ROUTER — Navigation event
  static void r(String tag, String message, {Object? data}) {
    _log(level: 'ROUTE', tag: tag, message: message, data: data, color: _cyan, emoji: '🛣️');
  }

  // ─── Separators (for visual grouping) ─────────────────────────────────────

  /// Print a visual section separator in the console
  static void separator(String label) {
    if (!_enabled || !kDebugMode) return;
    final line = '─' * 60;
    // ignore: avoid_print
    print('$_gray$line$_reset');
    // ignore: avoid_print
    print('$_cyan  📌 $label$_reset');
    // ignore: avoid_print
    print('$_gray$line$_reset');
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  static void _log({
    required String level,
    required String tag,
    required String message,
    required String color,
    required String emoji,
    Object? data,
  }) {
    if (!_enabled) return;
    final now = _timestamp();
    final line = '$color[$now][$level][$tag] $emoji $message$_reset';

    if (kDebugMode) {
      // ignore: avoid_print
      print(line);
      if (data != null) {
        // ignore: avoid_print
        print('$_gray  ↳ data: $data$_reset');
      }
    }

    developer.log(
      message,
      name: tag,
      time: DateTime.now(),
    );
  }

  static String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
