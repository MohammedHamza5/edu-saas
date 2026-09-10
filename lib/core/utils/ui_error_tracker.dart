import 'package:flutter/foundation.dart';
import '../router/app_route_observer.dart';
import 'app_logger.dart';

/// 🎯 UiErrorReport — Comprehensive Diagnostic Report for any UI Error
class UiErrorReport {
  final String category;
  final String culpritWidget;
  final String? fileLocation;
  final String activeRoute;
  final String problemSummary;
  final String quickSolution;
  final List<String> widgetTreePath;
  final List<String> appStackFrames;
  final bool isOverflow;
  final double? overflowPixels;
  final String? overflowDirection;

  const UiErrorReport({
    required this.category,
    required this.culpritWidget,
    required this.fileLocation,
    required this.activeRoute,
    required this.problemSummary,
    required this.quickSolution,
    required this.widgetTreePath,
    required this.appStackFrames,
    this.isOverflow = false,
    this.overflowPixels,
    this.overflowDirection,
  });

  /// Formats the report into a high-visibility, colored console box
  String toFormattedConsoleBox() {
    const reset = '\x1B[0m';
    const red = '\x1B[31m';
    const yellow = '\x1B[33m';
    const cyan = '\x1B[36m';
    const green = '\x1B[32m';
    const bold = '\x1B[1m';
    const gray = '\x1B[90m';

    final buffer = StringBuffer();
    const width = 84;
    final topBorder = '╔${'═' * (width - 2)}╗';
    final midBorder = '╠${'═' * (width - 2)}╣';
    final subBorder = '╟${'─' * (width - 2)}╢';
    final botBorder = '╚${'═' * (width - 2)}╝';

    buffer.writeln();
    buffer.writeln('$red$bold$topBorder$reset');
    buffer.writeln('$red$bold║ 🚨 [UI ENGINE ERROR DETECTED] ── $category$reset');
    buffer.writeln('$red$bold$midBorder$reset');

    // 1. Basic Coordinates
    buffer.writeln('$cyan║ 🧭 Active Screen / Route : $bold$activeRoute$reset');
    buffer.writeln('$red$bold║ 💥 Culprit Widget        : $culpritWidget$reset');
    if (fileLocation != null) {
      buffer.writeln('$green$bold║ 📁 File & Line Location   : $fileLocation$reset');
    }
    buffer.writeln('$yellow║ ⚠️ Problem               : $problemSummary$reset');
    buffer.writeln('$green║ 💡 Recommended Fix       : $quickSolution$reset');

    // 2. Widget Tree Ancestry
    if (widgetTreePath.isNotEmpty) {
      buffer.writeln('$gray$subBorder$reset');
      buffer.writeln('$cyan$bold║ 🌳 EXACT WIDGET TREE LOCATION (Root ➔ Leaf):$reset');
      for (int i = 0; i < widgetTreePath.length; i++) {
        final isLast = i == widgetTreePath.length - 1;
        final indent = '   ${'  ' * i}';
        final branch = isLast ? '└─ 💥 ' : '└─ ';
        final color = isLast ? '$red$bold' : cyan;
        buffer.writeln('$color║ $indent$branch${widgetTreePath[i]}$reset');
      }
    }

    // 3. Relevant App Stack Frames (filtered from Flutter engine noise)
    if (appStackFrames.isNotEmpty) {
      buffer.writeln('$gray$subBorder$reset');
      buffer.writeln('$yellow$bold║ 🎯 YOUR PROJECT CODE CALL SITES (App Frames):$reset');
      for (int i = 0; i < appStackFrames.length && i < 4; i++) {
        buffer.writeln('$yellow║   [$i] ${appStackFrames[i]}$reset');
      }
    }

    buffer.writeln('$red$bold$botBorder$reset');
    buffer.writeln();
    return buffer.toString();
  }
}

/// 🔍 UiErrorTracker — Intercepts and dissects Flutter framework UI errors
///
/// Dissects [FlutterErrorDetails] to identify:
/// 1. Exactly which widget broke (`culpritWidget`)
/// 2. Where it lives in your codebase (`fileLocation`)
/// 3. Its position in the Widget Hierarchy Tree (`widgetTreePath`)
/// 4. Overflow direction & pixels if RenderFlex overflowed
/// 5. Precise actionable instructions to solve the bug
class UiErrorTracker {
  UiErrorTracker._();

  /// Main entry point for FlutterError.onError
  static UiErrorReport track(FlutterErrorDetails details) {
    final report = analyze(details);

    // Print high-visibility formatted box in debug console
    if (kDebugMode) {
      // ignore: avoid_print
      print(report.toFormattedConsoleBox());
    }

    // Also send structured log to AppLogger
    AppLogger.e(
      'UI-Tracker',
      'UI Error in <${report.culpritWidget}> at ${report.fileLocation ?? report.activeRoute}',
      error: details.exception,
      stackTrace: details.stack,
    );

    return report;
  }

  /// Deep analysis of FlutterErrorDetails
  static UiErrorReport analyze(FlutterErrorDetails details) {
    final rawMessage = details.exceptionAsString();
    final stackStr = details.stack?.toString() ?? '';
    final activeRoute = AppRouteObserver.currentRoute;

    // ── 1. Detect Overflow ───────────────────────────────────────────────────
    final isOverflow = rawMessage.contains('overflowed by') ||
        rawMessage.contains('A RenderFlex overflowed');
    double? overflowPixels;
    String? overflowDirection;

    if (isOverflow) {
      final match = RegExp(r'overflowed by ([\d\.]+) pixels on the (\w+)').firstMatch(rawMessage);
      if (match != null) {
        overflowPixels = double.tryParse(match.group(1) ?? '');
        overflowDirection = match.group(2);
      }
    }

    // ── 2. Filter App Stack Frames ───────────────────────────────────────────
    final appFrames = _extractAppStackFrames(stackStr);

    // ── 3. Find Culprit Widget and File Location ─────────────────────────────
    String culpritWidget = _extractCulpritWidget(details, appFrames, isOverflow, overflowDirection);
    String? fileLocation = appFrames.isNotEmpty ? appFrames.first : null;

    // ── 4. Extract Widget Tree Ancestry Path ─────────────────────────────────
    final widgetTreePath = _buildWidgetTreePath(details, culpritWidget, activeRoute);

    // ── 5. Determine Category, Problem & Quick Solution ──────────────────────
    String category = 'Widget Error';
    String problemSummary = rawMessage.split('\n').first;
    String quickSolution = 'Inspect the widget parameters and build method.';

    if (isOverflow) {
      category = 'RenderFlex Overflow (Layout)';
      final dir = overflowDirection ?? 'bottom';
      final px = overflowPixels != null ? '${overflowPixels.toStringAsFixed(1)}px' : 'pixels';
      problemSummary = 'Content overflowed by $px on the $dir edge.';

      if (dir == 'bottom' || dir == 'top') {
        quickSolution =
            'Vertical overflow in Column: Wrap the Column with SingleChildScrollView, or wrap large children with Expanded / Flexible.';
      } else {
        quickSolution =
            'Horizontal overflow in Row: Wrap expanding child in Expanded, use Text(..., overflow: TextOverflow.ellipsis), or replace Row with Wrap.';
      }
    } else if (rawMessage.contains('Null check operator used on a null value')) {
      category = 'Null Check Failure (!) in UI';
      problemSummary = 'A null object was forced with ! operator inside the widget tree.';
      quickSolution = 'Search for "!" in $fileLocation and use safe null checking (?. or ?? fallback).';
    } else if (rawMessage.contains('unbounded') || rawMessage.contains('Vertical viewport was given unbounded height')) {
      category = 'Unbounded Constraints (Infinite Size)';
      problemSummary = 'A scrollable widget (e.g., ListView) has infinite height inside an unconstrained parent (e.g., Column).';
      quickSolution = 'Add shrinkWrap: true and physics: const NeverScrollableScrollPhysics(), or wrap it with Expanded / SizedBox(height: ...).';
    } else if (rawMessage.contains('setState() or markNeedsBuild() called during build')) {
      category = 'Lifecycle Violation (setState during build)';
      problemSummary = 'A state change was triggered while the framework was already building widgets.';
      quickSolution = 'Wrap the state update in WidgetsBinding.instance.addPostFrameCallback((_) => ...).';
    } else if (rawMessage.contains('No MediaQuery widget ancestor found') ||
        rawMessage.contains('No Directionality widget found') ||
        rawMessage.contains('No Theme widget found')) {
      category = 'Missing Inherited Widget Ancestor';
      problemSummary = 'Widget requires an inherited ancestor that is missing above it in the tree.';
      quickSolution = 'Ensure the widget is inside a MaterialApp or provide Directionality / MediaQuery directly.';
    }

    return UiErrorReport(
      category: category,
      culpritWidget: culpritWidget,
      fileLocation: fileLocation,
      activeRoute: activeRoute,
      problemSummary: problemSummary,
      quickSolution: quickSolution,
      widgetTreePath: widgetTreePath,
      appStackFrames: appFrames,
      isOverflow: isOverflow,
      overflowPixels: overflowPixels,
      overflowDirection: overflowDirection,
    );
  }

  // ─── Private Helpers ───────────────────────────────────────────────────────

  /// Extracts app-specific stack frames (ignoring flutter engine internals)
  static List<String> _extractAppStackFrames(String stack) {
    final lines = stack.split('\n');
    final appFrames = <String>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      // Match package:edu_saas or lib/ or test/
      if (line.contains('package:edu_saas') ||
          line.contains('edu_saas/lib/') ||
          line.contains('lib/core/') ||
          line.contains('lib/features/')) {
        // Clean up format: e.g., "package:edu_saas/features/auth/... 45:10 in build"
        final cleaned = line
            .replaceAll(RegExp(r'#\d+\s+'), '')
            .replaceAll('package:edu_saas/', 'lib/')
            .trim();
        appFrames.add(cleaned);
      }
    }
    return appFrames;
  }

  /// Discovers the exact failing widget name
  static String _extractCulpritWidget(
    FlutterErrorDetails details,
    List<String> appFrames,
    bool isOverflow,
    String? overflowDirection,
  ) {
    // 1. Try informationCollector for explicit widget diagnostic
    try {
      final nodes = details.informationCollector?.call() ?? <DiagnosticsNode>[];
      for (final node in nodes) {
        final desc = node.toDescription();
        final name = node.name ?? '';
        if (name.contains('error-causing widget') || name.contains('widget') || desc.contains('relevant error-causing widget')) {
          final match = RegExp(r'([A-Z][A-Za-z0-9_]+)').firstMatch(desc);
          if (match != null) return match.group(1)!;
        }
      }
    } catch (_) {}

    // 2. Try details.context (e.g. "building AcademicHeroBanner(dirty)")
    final contextDesc = details.context?.toDescription() ?? '';
    if (contextDesc.isNotEmpty) {
      final match = RegExp(r'building\s+([A-Z][A-Za-z0-9_]+)').firstMatch(contextDesc);
      if (match != null) return match.group(1)!;
    }

    // 3. Try app stack frames to find widget class
    String? foundWidget;
    for (final frame in appFrames) {
      // 3.1 Try "in _ClassName.method"
      final methodMatch = RegExp(r'in\s+([_A-Za-z0-9]+)\.').firstMatch(frame);
      if (methodMatch != null) {
        var rawName = methodMatch.group(1)!;
        rawName = rawName.replaceAll(RegExp(r'^_'), '');
        if (rawName.endsWith('State') && rawName.length > 5) {
          rawName = rawName.substring(0, rawName.length - 5);
        }
        if (!rawName.endsWith('Cubit') && !rawName.endsWith('Repository') && !rawName.endsWith('Test')) {
          foundWidget = rawName;
          break;
        }
      }

      // 3.2 Fallback to snake_case file name (e.g. teacher_dashboard_page.dart -> TeacherDashboardPage)
      final fileMatch = RegExp(r'/([a-z0-9_]+)\.dart').firstMatch(frame);
      if (fileMatch != null) {
        final fileName = fileMatch.group(1)!;
        if (!fileName.endsWith('_test') && !fileName.endsWith('_cubit') && !fileName.endsWith('_repository')) {
          final pascal = fileName
              .split('_')
              .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
              .join();
          if (pascal.isNotEmpty) {
            foundWidget = pascal;
            break;
          }
        }
      }
    }

    // 4. Default for layout overflows
    if (isOverflow) {
      final flexType = (overflowDirection == 'right' || overflowDirection == 'left') ? 'Row' : 'Column';
      if (foundWidget != null && foundWidget.isNotEmpty) {
        return '$flexType (in $foundWidget)';
      }
      return flexType;
    }

    if (foundWidget != null && foundWidget.isNotEmpty) {
      return foundWidget;
    }

    return 'UnknownWidget';
  }

  /// Builds a visual breadcrumb tree from Root down to the failing widget
  static List<String> _buildWidgetTreePath(
    FlutterErrorDetails details,
    String culpritWidget,
    String activeRoute,
  ) {
    final tree = <String>[];

    // Try to extract creator chain from diagnostics
    try {
      final nodes = details.informationCollector?.call() ?? <DiagnosticsNode>[];
      for (final node in nodes) {
        final desc = node.toDescription();
        // Flutter often includes creator chains formatted with arrows (←)
        if (desc.contains('←')) {
          final parts = desc.split('←').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          if (parts.isNotEmpty) {
            // Reverse so it goes Root ➔ Leaf
            for (final part in parts.reversed) {
              final clean = part.split('(').first.split(':').first.trim();
              if (clean.isNotEmpty && !tree.contains(clean)) {
                tree.add(clean);
              }
            }
            if (!tree.contains(culpritWidget)) {
              tree.add(culpritWidget);
            }
            return tree;
          }
        }
      }
    } catch (_) {}

    // Fallback: Construct structural hierarchy from active route
    tree.add('EduSaaSApp');
    tree.add('MaterialApp.router');

    final screenName = _resolveScreenNameFromRoute(activeRoute);
    if (screenName != null) {
      if (activeRoute.startsWith('/teacher')) {
        tree.add('TeacherShell');
      }
      tree.add(screenName);
    }

    if (!tree.contains(culpritWidget)) {
      tree.add(culpritWidget);
    }

    return tree;
  }

  static String? _resolveScreenNameFromRoute(String route) {
    if (route == '/' || route == '/splash') return 'SplashPage';
    if (route == '/login') return 'LoginPage';
    if (route == '/teacher') return 'TeacherDashboardPage';
    if (route == '/teacher/students') return 'StudentsListPage';
    if (route == '/teacher/groups') return 'GroupsListPage';
    if (route == '/teacher/attendance') return 'TeacherAttendancePage';
    if (route == '/student') return 'StudentDashboardPage';
    if (route == '/parent') return 'ParentDashboardPage';
    if (route.contains('/exams')) return 'TeacherExamsPage';
    if (route.contains('/content')) return 'TeacherContentLibraryPage';
    if (route.contains('/assignments')) return 'TeacherAssignmentsPage';
    return null;
  }
}
