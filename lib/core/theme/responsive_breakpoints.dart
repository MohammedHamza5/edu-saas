/// Device Screen Types according to standardized modern breakpoints.
/// - compact: Mobile screens (< 600dp)
/// - medium: Foldables unfolded & Tablets in portrait (600dp .. 839dp)
/// - expanded: Tablets in landscape & Small laptops (840dp .. 1199dp)
/// - large: Desktop monitors & Ultra-wide displays (>= 1200dp)
enum DeviceScreenType {
  compact,
  medium,
  expanded,
  large;

  bool get isMobile => this == DeviceScreenType.compact;
  bool get isTablet => this == DeviceScreenType.medium;
  bool get isDesktop => this == DeviceScreenType.expanded || this == DeviceScreenType.large;
  bool get isLargeDesktop => this == DeviceScreenType.large;
}

/// Standardized breakpoint numbers and layout constraint tokens.
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  // Width Breakpoints
  static const double compactMax = 599.0;
  static const double mediumMax = 839.0;
  static const double expandedMax = 1199.0;

  // Convenience threshold points
  static const double mobileThreshold = 600.0;
  static const double tabletThreshold = 840.0;
  static const double desktopThreshold = 1200.0;

  // Maximum content boundaries (to prevent awkward horizontal stretching on large screens)
  static const double maxContentWidth = 1200.0;
  static const double maxFormWidth = 480.0;
  static const double maxReadingWidth = 760.0;
  static const double maxWideContentWidth = 1440.0;

  /// Determines the [DeviceScreenType] given the screen or container width.
  static DeviceScreenType getScreenType(double width) {
    if (width < mobileThreshold) {
      return DeviceScreenType.compact;
    } else if (width < tabletThreshold) {
      return DeviceScreenType.medium;
    } else if (width < desktopThreshold) {
      return DeviceScreenType.expanded;
    } else {
      return DeviceScreenType.large;
    }
  }

  /// Calculates dynamic column count for cards and grids based on width.
  static int getColumnCount(
    double width, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int largeDesktop = 4,
  }) {
    final type = getScreenType(width);
    return switch (type) {
      DeviceScreenType.compact => mobile,
      DeviceScreenType.medium => tablet,
      DeviceScreenType.expanded => desktop,
      DeviceScreenType.large => largeDesktop,
    };
  }
}
