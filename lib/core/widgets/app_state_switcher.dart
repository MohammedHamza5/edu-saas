import 'package:flutter/material.dart';

/// A high-performance state transition wrapper that eliminates abrupt UI pop-in
/// when toggling between the 4 mandatory states (Loading, Empty, Error, Success).
///
/// Features:
/// - Smooth cross-fade transition with configurable duration and curves.
/// - Preserves layout stability using an alignment-preserving layout builder.
/// - Lightweight and composable with BlocBuilder / switch expressions.
class AppStateSwitcher extends StatelessWidget {
  /// The active state widget to render.
  /// Ensure each state branch uses a unique [Key] (e.g., `ValueKey('loading')`,
  /// `ValueKey('loaded')`) so [AnimatedSwitcher] detects the change.
  final Widget child;

  /// Duration of the transition animation (defaults to 240 milliseconds).
  final Duration duration;

  /// Easing curve applied when entering the viewport.
  final Curve switchInCurve;

  /// Easing curve applied when exiting the viewport.
  final Curve switchOutCurve;

  /// Alignment of the switcher container.
  final Alignment alignment;

  const AppStateSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
    this.switchInCurve = Curves.easeOutCubic,
    this.switchOutCurve = Curves.easeInCubic,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: alignment,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: child,
    );
  }
}
