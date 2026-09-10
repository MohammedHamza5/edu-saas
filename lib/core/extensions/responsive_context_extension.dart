import 'package:flutter/material.dart';
import '../theme/responsive_breakpoints.dart';

/// Extension on [BuildContext] for clean, readable, zero-overhead responsive queries.
extension ResponsiveContextX on BuildContext {
  /// Total width of the current window / screen.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Total height of the current window / screen.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Orientation of the screen (portrait or landscape).
  Orientation get orientation => MediaQuery.orientationOf(this);

  /// Returns true if device is in portrait orientation.
  bool get isPortrait => orientation == Orientation.portrait;

  /// Returns true if device is in landscape orientation.
  bool get isLandscape => orientation == Orientation.landscape;

  /// Current [DeviceScreenType] (compact, medium, expanded, large).
  DeviceScreenType get screenType => ResponsiveBreakpoints.getScreenType(screenWidth);

  /// True for phones and narrow screens (< 600dp).
  bool get isMobile => screenType.isMobile;

  /// True for foldables unfolded and tablets in portrait (600dp .. 839dp).
  bool get isTablet => screenType.isTablet;

  /// True for laptops, desktop monitors, and ultra-wide screens (>= 840dp).
  bool get isDesktop => screenType.isDesktop;

  /// True for large desktop monitors (>= 1200dp).
  bool get isLargeDesktop => screenType.isLargeDesktop;

  /// Dynamically returns a value [T] adapted to the current screen type.
  /// If an upper tier is not provided, it gracefully falls back to the next available tier down to [mobile].
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeDesktop,
  }) {
    switch (screenType) {
      case DeviceScreenType.large:
        return largeDesktop ?? desktop ?? tablet ?? mobile;
      case DeviceScreenType.expanded:
        return desktop ?? tablet ?? mobile;
      case DeviceScreenType.medium:
        return tablet ?? mobile;
      case DeviceScreenType.compact:
        return mobile;
    }
  }

  /// Adaptive horizontal padding for screen content (16dp on mobile, 24dp on tablet, 32dp on desktop).
  EdgeInsetsDirectional get responsivePagePadding {
    final horizontal = responsiveValue<double>(
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );
    final vertical = responsiveValue<double>(
      mobile: 16.0,
      tablet: 20.0,
      desktop: 24.0,
    );
    return EdgeInsetsDirectional.fromSTEB(horizontal, vertical, horizontal, vertical);
  }

  /// Adaptive gap / spacing value.
  double responsiveSpacing({
    double mobile = 16.0,
    double? tablet,
    double? desktop,
  }) {
    return responsiveValue<double>(
      mobile: mobile,
      tablet: tablet ?? (mobile * 1.25),
      desktop: desktop ?? (mobile * 1.5),
    );
  }
}
