import 'package:flutter/material.dart';
import '../utils/app_logger.dart';

/// 🧭 AppRouteObserver — Real-time Navigation & Screen Tracker
///
/// Tracks the active route path, screen name, and navigation history.
/// Integrated directly into GoRouter and accessible anywhere via [currentRoute].
class AppRouteObserver extends NavigatorObserver {
  AppRouteObserver._();
  static final AppRouteObserver instance = AppRouteObserver._();

  /// The active route path or screen name currently displayed to the user
  static String currentRoute = '/';

  /// Navigation breadcrumbs history (last 10 routes)
  static final List<String> routeHistory = ['/'];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _updateRoute(route, 'Push');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _updateRoute(previousRoute, 'Pop back to');
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _updateRoute(newRoute, 'Replace with');
    }
  }

  void _updateRoute(Route<dynamic> route, String action) {
    final routeName = _extractRouteName(route);
    if (routeName.isNotEmpty && routeName != currentRoute) {
      currentRoute = routeName;
      routeHistory.add(routeName);
      if (routeHistory.length > 10) {
        routeHistory.removeAt(0);
      }
      AppLogger.r('RouteObserver', '$action: $routeName');
    }
  }

  static String _extractRouteName(Route<dynamic> route) {
    // 1. Try route settings name (GoRouter sets this to path or name)
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;

    // 2. Try arguments if name is not set
    final args = route.settings.arguments;
    if (args != null) return args.toString();

    // 3. Fallback to route type
    return route.runtimeType.toString();
  }
}
