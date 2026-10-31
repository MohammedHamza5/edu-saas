import 'dart:async';
import 'package:flutter/material.dart';
import '../network/retry_helper.dart';
import '../utils/app_logger.dart';
import 'app_error_view.dart';
import 'app_loading_view.dart';

/// A widget that defers the loading of a screen/bundle until it is actually navigated to.
///
/// Enables Dart Web code-splitting (generating separate `.part.js` chunks) so that
/// heavy administrative/teacher modules are never loaded on initial page launch
/// or by unauthorized user roles.
///
/// On mobile (Android/iOS) and in unit test environments, [loadLibrary] resolves
/// immediately and cleanly without any overhead.
class DeferredWidget extends StatefulWidget {
  final Future<void> Function() loadLibrary;
  final Widget Function() builder;
  final Widget? placeholder;

  const DeferredWidget({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.placeholder,
  });

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadWithSilentRetry();
  }

  Future<void> _loadWithSilentRetry() {
    return retryTransient(
      () => widget.loadLibrary(),
      policy: const RetryPolicy(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 150),
        backoffMultiplier: 1.5,
        maxDelay: Duration(milliseconds: 800),
        jitter: Duration(milliseconds: 40),
      ),
      shouldRetry: (_) => true,
    ).catchError((Object error, StackTrace stack) {
      AppLogger.e(
        'DeferredWidget',
        'Failed to load deferred chunk after 3 attempts: $error',
        error: error,
        stackTrace: stack,
      );
      throw error;
    });
  }

  void _retry() {
    setState(() {
      _loadFuture = _loadWithSilentRetry();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        Widget content;
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          try {
            content = KeyedSubtree(
              key: const ValueKey('deferred_loaded'),
              child: widget.builder(),
            );
          } catch (e) {
            content = Scaffold(
              key: const ValueKey('deferred_build_error'),
              body: AppErrorView(error: e, onRetry: _retry),
            );
          }
        } else if (snapshot.hasError) {
          content = Scaffold(
            key: const ValueKey('deferred_load_error'),
            body: AppErrorView(error: snapshot.error, onRetry: _retry),
          );
        } else {
          content = widget.placeholder ??
              const Scaffold(
                key: ValueKey('deferred_loading'),
                body: Center(
                  child: AppLoadingView(style: AppLoadingStyle.mathCurve),
                ),
              );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: content,
        );
      },
    );
  }
}
