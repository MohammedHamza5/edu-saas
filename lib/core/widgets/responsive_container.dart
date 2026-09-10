import 'package:flutter/material.dart';
import '../theme/responsive_breakpoints.dart';

/// A widget that limits its child's maximum width and centers it horizontally.
/// Essential for clean responsive design on desktop/tablet viewports.
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  /// Specialized container for auth & settings forms (max 480dp).
  const ResponsiveContainer.form({
    super.key,
    required this.child,
    this.padding,
    this.alignment = Alignment.center,
  }) : maxWidth = ResponsiveBreakpoints.maxFormWidth;

  /// Specialized container for articles, exam instructions, and reading materials (max 760dp).
  const ResponsiveContainer.reading({
    super.key,
    required this.child,
    this.padding,
    this.alignment = Alignment.topCenter,
  }) : maxWidth = ResponsiveBreakpoints.maxReadingWidth;

  /// Specialized container for dense data tables and ultra-wide dashboards (max 1440dp).
  const ResponsiveContainer.wide({
    super.key,
    required this.child,
    this.padding,
    this.alignment = Alignment.topCenter,
  }) : maxWidth = ResponsiveBreakpoints.maxWideContentWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? ResponsiveBreakpoints.maxContentWidth;

    Widget content = Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: child,
      ),
    );

    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    }

    return content;
  }
}
