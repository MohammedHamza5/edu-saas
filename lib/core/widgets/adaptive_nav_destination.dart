import 'package:flutter/material.dart';

/// Destination item representation for [AdaptiveScaffold].
class AdaptiveDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final String? subtitle;
  final int? badgeCount;
  final String? tooltip;
  final Widget? badge;
  final VoidCallback? onHover;

  const AdaptiveDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.subtitle,
    this.badgeCount,
    this.tooltip,
    this.badge,
    this.onHover,
  });
}

/// Represents a categorized group of navigation destinations in the sidebar.
class AdaptiveSidebarSection {
  final String? title;
  final List<AdaptiveDestination> destinations;

  const AdaptiveSidebarSection({this.title, required this.destinations});
}
