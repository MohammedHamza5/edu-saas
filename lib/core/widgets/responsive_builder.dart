import 'package:flutter/material.dart';
import '../theme/responsive_breakpoints.dart';

typedef ResponsiveWidgetBuilder = Widget Function(
  BuildContext context,
  BoxConstraints constraints,
);

/// A declarative widget that switches layouts based on available constraints width.
/// Ideal for swapping layouts between Mobile (Single Column), Tablet (Two Columns / Split),
/// and Desktop (Three Columns / Master-Detail).
class ResponsiveBuilder extends StatelessWidget {
  final ResponsiveWidgetBuilder mobile;
  final ResponsiveWidgetBuilder? tablet;
  final ResponsiveWidgetBuilder? desktop;
  final ResponsiveWidgetBuilder? largeDesktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = ResponsiveBreakpoints.getScreenType(constraints.maxWidth);

        switch (screenType) {
          case DeviceScreenType.large:
            if (largeDesktop != null) return largeDesktop!(context, constraints);
            if (desktop != null) return desktop!(context, constraints);
            if (tablet != null) return tablet!(context, constraints);
            return mobile(context, constraints);

          case DeviceScreenType.expanded:
            if (desktop != null) return desktop!(context, constraints);
            if (tablet != null) return tablet!(context, constraints);
            return mobile(context, constraints);

          case DeviceScreenType.medium:
            if (tablet != null) return tablet!(context, constraints);
            return mobile(context, constraints);

          case DeviceScreenType.compact:
            return mobile(context, constraints);
        }
      },
    );
  }
}

/// A responsive widget that adapts between Portrait and Landscape orientations.
class OrientationResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) portrait;
  final Widget Function(BuildContext context) landscape;

  const OrientationResponsiveBuilder({
    super.key,
    required this.portrait,
    required this.landscape,
  });

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return orientation == Orientation.portrait
            ? portrait(context)
            : landscape(context);
      },
    );
  }
}
