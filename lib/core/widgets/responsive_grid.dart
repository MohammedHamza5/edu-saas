import 'package:flutter/material.dart';
import '../theme/responsive_breakpoints.dart';

/// A dynamic responsive grid widget that automatically distributes children across
/// columns based on the available container width.
/// Ideal for stat cards, course cards, and modular dashboard widgets.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final int largeDesktopColumns;
  final double spacing;
  final double runSpacing;
  final Alignment alignment;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.largeDesktopColumns = 4,
    this.spacing = 16.0,
    this.runSpacing = 16.0,
    this.alignment = Alignment.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columns = ResponsiveBreakpoints.getColumnCount(
          availableWidth,
          mobile: mobileColumns,
          tablet: tabletColumns,
          desktop: desktopColumns,
          largeDesktop: largeDesktopColumns,
        );

        // Compute width per item so all columns fit within available width
        final totalSpacing = (columns - 1) * spacing;
        final itemWidth = ((availableWidth - totalSpacing) / columns).clamp(0.0, availableWidth);

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}
