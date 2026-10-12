import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../network/supabase_service.dart';
import '../utils/app_logger.dart';

/// Intelligent Student Activity & Engagement Tracker
///
/// Responsibilities:
/// 1. Differentiates between ACTIVE study time and IDLE ghost presence.
/// 2. Monitors user interactions (touch, scroll, keystrokes) with a 120s idle threshold.
/// 3. Observes AppLifecycleState (resumed vs paused/background).
/// 4. Flushes periodic heartbeats to `record_student_heartbeat` RPC every 60s.
/// 5. Records authenticated whitelist activity events via `record_activity_event` RPC.
class StudentActivityTracker with WidgetsBindingObserver {
  StudentActivityTracker._();
  static final StudentActivityTracker instance = StudentActivityTracker._();

  static const int _idleThresholdSeconds =
      120; // 2 minutes without input = idle
  static const int _heartbeatIntervalSeconds = 60; // flush to backend every 60s

  Timer? _oneSecondTimer;
  Timer? _heartbeatTimer;
  StreamSubscription<AuthState>? _authSubscription;
  DateTime _lastInteractionTime = DateTime.now();
  final Map<String, DateTime> _recentEventsDebounce = {};

  bool _isRunning = false;
  bool _isIdle = false;
  bool _isInForeground = true;

  int _pendingActiveSeconds = 0;
  int _pendingIdleSeconds = 0;

  bool get isIdle => _isIdle;
  bool get isRunning => _isRunning;

  DateTime? _lastRegisteredInteraction;
  DateTime? _lastFlushTime;
  bool _isFlushing = false;

  /// Starts the tracking engine if the current user is an authenticated student
  void start() {
    if (_isRunning) return;

    final user = SupabaseService.isInitialized
        ? SupabaseService.client.auth.currentUser
        : null;
    if (user == null) return;

    final role = SupabaseService.cachedRole;
    if (role != null && role != 'student') {
      // Only students require active engagement telemetry
      return;
    }

    _isRunning = true;
    _isInForeground = true;
    _isIdle = false;
    _lastInteractionTime = DateTime.now();
    _lastRegisteredInteraction = null;
    _lastFlushTime = null;
    _pendingActiveSeconds = 0;
    _pendingIdleSeconds = 0;

    WidgetsBinding.instance.addObserver(this);

    // Auto-stop tracker if the student logs out or session is invalidated
    _authSubscription?.cancel();
    if (SupabaseService.isInitialized) {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
        (data) {
          if (data.event == AuthChangeEvent.signedOut || data.session == null) {
            stop();
          }
        },
      );
    }

    // 1-second tick timer for in-memory accounting
    _oneSecondTimer = Timer.periodic(const Duration(seconds: 1), _onSecondTick);

    // 60-second periodic heartbeat flush
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: _heartbeatIntervalSeconds),
      (_) {
        flushHeartbeat();
      },
    );

    // Record login activity event on start
    recordActivity(eventType: 'login');

    AppLogger.i(
      'StudentActivityTracker',
      'Tracker started for student: ${user.id}',
    );
  }

  /// Stops tracking and flushes any remaining telemetry
  void stop() {
    if (!_isRunning) return;

    _authSubscription?.cancel();
    _authSubscription = null;

    flushHeartbeat();

    _oneSecondTimer?.cancel();
    _oneSecondTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    WidgetsBinding.instance.removeObserver(this);
    _isRunning = false;

    AppLogger.i('StudentActivityTracker', 'Tracker stopped');
  }

  /// Called whenever a pointer, scroll, or key event is detected.
  /// Throttled to at most once per 3 seconds in memory to eliminate high-frequency
  /// overhead from 60Hz-120Hz pointermove / scroll streams.
  void registerUserInteraction() {
    final now = DateTime.now();
    if (_lastRegisteredInteraction != null &&
        now.difference(_lastRegisteredInteraction!).inSeconds < 3 &&
        !_isIdle) {
      return;
    }
    _lastRegisteredInteraction = now;
    _lastInteractionTime = now;
    if (_isIdle) {
      _isIdle = false;
      AppLogger.d(
        'StudentActivityTracker',
        'User transitioned from IDLE to ACTIVE',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isRunning) return;

    if (state == AppLifecycleState.resumed) {
      _isInForeground = true;
      registerUserInteraction();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _isInForeground = false;
      _isIdle = true;
      // Immediately flush current active state before backgrounding
      flushHeartbeat();
    }
    // Note: AppLifecycleState.inactive is intentionally omitted on Web
    // because touching iframe embeds (video player) or inputs triggers inactive,
    // which should NOT trigger premature heartbeat network flushes.
  }

  void _onSecondTick(Timer timer) {
    if (!_isRunning) return;

    final secondsSinceInteraction = DateTime.now()
        .difference(_lastInteractionTime)
        .inSeconds;

    if (secondsSinceInteraction >= _idleThresholdSeconds) {
      if (!_isIdle) {
        _isIdle = true;
        // On transition from active to idle: flush remaining active seconds
        flushHeartbeat();
      }
    }

    if (_isInForeground && !_isIdle) {
      _pendingActiveSeconds++;
    } else {
      _pendingIdleSeconds++;
    }
  }

  bool _isAuthError(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('401') ||
        str.contains('auth_required') ||
        str.contains('unauthorized') ||
        str.contains('jwt') ||
        str.contains('permission denied') ||
        str.contains('42501') ||
        str.contains('not_authorized') ||
        str.contains('invalid claim');
  }

  /// Sends accumulated active and idle seconds to the backend via RPC.
  /// Smartly batched: avoids spamming the database when the user is idle.
  Future<void> flushHeartbeat() async {
    if (_isFlushing) return;
    if (_pendingActiveSeconds == 0 && _pendingIdleSeconds == 0) return;

    // If completely idle with zero active time, do NOT ping the database every 60s
    // while the student is away. Accumulate idle time up to 10 minutes locally.
    if (_isIdle && _pendingActiveSeconds == 0 && _pendingIdleSeconds < 600) {
      return;
    }

    final now = DateTime.now();
    // Guard against rapid duplicate flushes within 10 seconds
    if (_lastFlushTime != null && now.difference(_lastFlushTime!).inSeconds < 10) {
      return;
    }

    _isFlushing = true;
    _lastFlushTime = now;

    final activeToSend = _pendingActiveSeconds;
    final idleToSend = _pendingIdleSeconds;

    // Reset local counters before network call to prevent double counting
    _pendingActiveSeconds = 0;
    _pendingIdleSeconds = 0;

    try {
      if (!SupabaseService.isInitialized) return;
      final client = SupabaseService.client;
      if (client.auth.currentUser == null) {
        stop();
        return;
      }

      await client.rpc<void>(
        'record_student_heartbeat',
        params: {
          'p_active_seconds': activeToSend,
          'p_idle_seconds': idleToSend,
          'p_current_route': null,
        },
      );

      AppLogger.d(
        'StudentActivityTracker',
        'Heartbeat flushed',
        data: {'active': activeToSend, 'idle': idleToSend},
      );
    } catch (e) {
      if (_isAuthError(e)) {
        AppLogger.w(
          'StudentActivityTracker',
          'Auth expired during heartbeat; stopping tracker: $e',
        );
        stop();
        return;
      }
      // On network failure, re-accumulate unsent seconds
      _pendingActiveSeconds += activeToSend;
      _pendingIdleSeconds += idleToSend;
      AppLogger.w('StudentActivityTracker', 'Failed to flush heartbeat: $e');
    } finally {
      _isFlushing = false;
    }
  }

  /// Records a whitelist activity event via `record_activity_event` RPC
  Future<void> recordActivity({
    required String eventType,
    String? contentId,
    String? groupId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (!SupabaseService.isInitialized) return;
      final client = SupabaseService.client;
      if (client.auth.currentUser == null) {
        stop();
        return;
      }

      registerUserInteraction();

      final validContentId = (contentId != null && contentId.trim().isNotEmpty)
          ? contentId.trim()
          : null;
      final validGroupId = (groupId != null && groupId.trim().isNotEmpty)
          ? groupId.trim()
          : null;

      // Throttle identical rapid events (within 5 seconds) to protect backend
      final eventKey =
          '$eventType:${validContentId ?? ''}:${validGroupId ?? ''}';
      final lastFired = _recentEventsDebounce[eventKey];
      final now = DateTime.now();
      if (lastFired != null && now.difference(lastFired).inSeconds < 5) {
        return;
      }
      _recentEventsDebounce[eventKey] = now;

      await client.rpc<void>(
        'record_activity_event',
        params: {
          'p_event_type': eventType,
          'p_content_id': validContentId,
          'p_group_id': validGroupId,
          'p_metadata': metadata ?? {},
        },
      );

      AppLogger.d(
        'StudentActivityTracker',
        'Activity recorded',
        data: {'event_type': eventType, 'content_id': validContentId},
      );
    } catch (e) {
      if (_isAuthError(e)) {
        AppLogger.w(
          'StudentActivityTracker',
          'Auth expired during recordActivity; stopping tracker: $e',
        );
        stop();
        return;
      }
      AppLogger.w(
        'StudentActivityTracker',
        'Failed to record activity $eventType: $e',
      );
    }
  }
}
