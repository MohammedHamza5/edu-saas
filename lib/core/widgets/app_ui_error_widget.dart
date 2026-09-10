import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/ui_error_tracker.dart';

/// 🚨 AppUiErrorWidget — Interactive In-App Diagnostic Error Display
///
/// Replaces Flutter's default Red Screen of Death (`ErrorWidget.builder`).
/// Displays:
/// - Exact failing widget name
/// - Source file & line location
/// - Plain-language description of the problem
/// - Actionable recommendation to resolve the error
/// - Interactive Widget Tree Ancestry path
class AppUiErrorWidget extends StatefulWidget {
  final FlutterErrorDetails details;

  const AppUiErrorWidget({
    super.key,
    required this.details,
  });

  @override
  State<AppUiErrorWidget> createState() => _AppUiErrorWidgetState();
}

class _AppUiErrorWidgetState extends State<AppUiErrorWidget> {
  bool _showDetails = false;
  late final UiErrorReport _report;

  @override
  void initState() {
    super.initState();
    _report = UiErrorTracker.analyze(widget.details);
  }

  @override
  Widget build(BuildContext context) {
    // ── Release Mode: Graceful Fallback ──────────────────────────────────────
    if (kReleaseMode) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'An error occurred displaying content',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // ── Debug / Profile Mode: Developer Diagnostic Card ─────────────────────
    return Directionality(
      textDirection: TextDirection.ltr, // Keep code / paths in LTR for readability
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.s8),
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2), // Light Rose
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: const Color(0xFFE11D48), width: 1.5), // Rose 600
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Error Badge & Culprit Widget
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'UI ERROR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        _report.culpritWidget,
                        style: const TextStyle(
                          color: Color(0xFF881337), // Dark Rose
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),

                // File Location
                if (_report.fileLocation != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.code_rounded, size: 14, color: Color(0xFF9F1239)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _report.fileLocation!,
                          style: const TextStyle(
                            color: Color(0xFF9F1239),
                            fontSize: 11,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s6),
                ],

                // Active Route
                Row(
                  children: [
                    const Icon(Icons.navigation_outlined, size: 14, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text(
                      'Route: ${_report.activeRoute}',
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),

                // Problem Summary Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(color: const Color(0xFFFDA4AF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _report.problemSummary,
                        style: const TextStyle(
                          color: Color(0xFFBE123C),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '💡 Fix: ${_report.quickSolution}',
                        style: const TextStyle(
                          color: Color(0xFF047857), // Green
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),

                // Expand Widget Tree Button
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _showDetails = !_showDetails),
                  child: Row(
                    children: [
                      Icon(
                        _showDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 16,
                        color: const Color(0xFFE11D48),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showDetails ? 'Hide Widget Tree' : 'View Widget Tree Path',
                        style: const TextStyle(
                          color: Color(0xFFE11D48),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

                // Expanded Widget Tree Path
                if (_showDetails) ...[
                  const SizedBox(height: AppSpacing.s6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B), // Dark Slate
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🌳 Widget Hierarchy:',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (int i = 0; i < _report.widgetTreePath.length; i++)
                          Padding(
                            padding: EdgeInsets.only(left: (i * 10).toDouble(), bottom: 2),
                            child: Text(
                              i == _report.widgetTreePath.length - 1
                                  ? '└─ 💥 ${_report.widgetTreePath[i]}'
                                  : '└─ ${_report.widgetTreePath[i]}',
                              style: TextStyle(
                                color: i == _report.widgetTreePath.length - 1
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFFE2E8F0),
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: i == _report.widgetTreePath.length - 1
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
