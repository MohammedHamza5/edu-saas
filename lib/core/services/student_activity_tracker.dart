import 'dart:async';
import 'package:flutter/widgets.dart';
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

  static const int _idleThresholdSeconds = 120; // 2 minutes without input = idle
  static const int _heartbeatIntervalSeconds = 60; // flush to backend every 60s

  Timer? _oneSecondTimer;
  Timer? _heartbeatTimer;
  DateTime _lastInteractionTime = DateTime.now();

  bool _isRunning = false;
  bool _isIdle = false;
  bool _isInForeground = true;

  int _pendingActiveSeconds = 0;
  int _pendingIdleSeconds = 0;

  bool get isIdle => _isIdle;
  bool get isRunning => _isRunning;

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
    _pendingActiveSeconds = 0;
    _pendingIdleSeconds = 0;

    WidgetsBinding.instance.addObserver(this);

    // 1-second tick timer
    _oneSecondTimer = Timer.periodic(const Duration(seconds: 1), _onSecondTick);

    // 60-second periodic heartbeat flush
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: _heartbeatIntervalSeconds), (_) {
      flushHeartbeat();
    });

    // Record login activity event on start
    recordActivity(eventType: 'login');

    AppLogger.i('StudentActivityTracker', 'Tracker started for student: ${user.id}');
  }

  /// Stops tracking and flushes any remaining telemetry
  void stop() {
    if (!_isRunning) return;

    flushHeartbeat();

    _oneSecondTimer?.cancel();
    _oneSecondTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    WidgetsBinding.instance.removeObserver(this);
    _isRunning = false;

    AppLogger.i('StudentActivityTracker', 'Tracker stopped');
  }

  /// Called whenever a pointer, scroll, or key event is detected
  void registerUserInteraction() {
    _lastInteractionTime = DateTime.now();
    if (_isIdle) {
      _isIdle = false;
      AppLogger.d('StudentActivityTracker', 'User transitioned from IDLE to ACTIVE');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isRunning) return;

    if (state == AppLifecycleState.resumed) {
      _isInForeground = true;
      registerUserInteraction();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isInForeground = false;
      _isIdle = true;
      // Immediately flush current active state before backgrounding
      flushHeartbeat();
    }
  }

  void _onSecondTick(Timer timer) {
    if (!_isRunning) return;

    final secondsSinceInteraction =
        DateTime.now().difference(_lastInteractionTime).inSeconds;

    if (secondsSinceInteraction >= _idleThresholdSeconds) {
      _isIdle = true;
    }

    if (_isInForeground) {
      if (!_isIdle) {
        _pendingActiveSeconds++;
      } else {
        _pendingIdleSeconds++;
      }
    } else {
      // In background, count as idle
      _pendingIdleSeconds++;
    }
  }

  /// Sends accumulated active and idle seconds to the backend via RPC
  Future<void> flushHeartbeat() async {
    if (_pendingActiveSeconds == 0 && _pendingIdleSeconds == 0) return;

    final activeToSend = _pendingActiveSeconds;
    final idleToSend = _pendingIdleSeconds;

    // Reset local counters before network call to prevent double counting
    _pendingActiveSeconds = 0;
    _pendingIdleSeconds = 0;

    try {
      if (!SupabaseService.isInitialized) return;
      final client = SupabaseService.client;
      if (client.auth.currentUser == null) return;

      await client.rpc<void>('record_student_heartbeat', params: {
        'p_active_seconds': activeToSend,
        'p_idle_seconds': idleToSend,
        'p_current_route': null,
      });

      AppLogger.d(
        'StudentActivityTracker',
        'Heartbeat flushed',
        data: {'active': activeToSend, 'idle': idleToSend},
      );
    } catch (e) {
      // On network failure, re-accumulate unsent seconds
      _pendingActiveSeconds += activeToSend;
      _pendingIdleSeconds += idleToSend;
      AppLogger.w('StudentActivityTracker', 'Failed to flush heartbeat: $e');
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
      if (client.auth.currentUser == null) return;

      registerUserInteraction();

      final validContentId = (contentId != null && contentId.trim().isNotEmpty) ? contentId.trim() : null;
      final validGroupId = (groupId != null && groupId.trim().isNotEmpty) ? groupId.trim() : null;

      await client.rpc<void>('record_activity_event', params: {
        'p_event_type': eventType,
        'p_content_id': validContentId,
        'p_group_id': validGroupId,
        'p_metadata': metadata ?? {},
      });

      AppLogger.d(
        'StudentActivityTracker',
        'Activity recorded',
        data: {'event_type': eventType, 'content_id': validContentId},
      );
    } catch (e) {
      AppLogger.w('StudentActivityTracker', 'Failed to record activity $eventType: $e');
    }
  }
}
