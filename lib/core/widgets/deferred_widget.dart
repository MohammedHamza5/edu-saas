import 'package:flutter/material.dart';
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
    _loadFuture = widget.loadLibrary();
  }

  void _retry() {
    setState(() {
      _loadFuture = widget.loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          try {
            return widget.builder();
          } catch (e) {
            return Scaffold(
              body: AppErrorView(error: e, onRetry: _retry),
            );
          }
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: AppErrorView(error: snapshot.error, onRetry: _retry),
          );
        }

        return widget.placeholder ??
            const Scaffold(
              body: Center(
                child: AppLoadingView(style: AppLoadingStyle.mathCurve),
              ),
            );
      },
    );
  }
}
