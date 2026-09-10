import 'package:flutter/material.dart';
import '../services/student_activity_tracker.dart';

/// Transparent widget wrapper that detects user gestures, scrolls, and key events
/// to signal user presence to [StudentActivityTracker].
class GlobalActivityListener extends StatelessWidget {
  final Widget child;

  const GlobalActivityListener({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => StudentActivityTracker.instance.registerUserInteraction(),
      onPointerMove: (_) => StudentActivityTracker.instance.registerUserInteraction(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          StudentActivityTracker.instance.registerUserInteraction();
          return false;
        },
        child: child,
      ),
    );
  }
}
