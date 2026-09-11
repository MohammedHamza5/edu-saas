import 'package:flutter/material.dart';
import '../localization/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/responsive_breakpoints.dart';
import 'animated_math_background.dart';

/// Destination item representation for [AdaptiveScaffold].
class AdaptiveDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final int? badgeCount;
  final String? tooltip;
  final Widget? badge;
  final VoidCallback? onHover;

  const AdaptiveDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
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

  const AdaptiveSidebarSection({
    this.title,
    required this.destinations,
  });
}

/// Adaptive scaffold delivering:
/// - Desktop (>= 840dp): Permanent categorized mathematical styled Sidebar (260dp)
/// - Tablet (600 - 839dp): Material 3 [NavigationRail]
/// - Mobile (< 600dp): Bottom [NavigationBar] with full [Drawer] support for all categorized screens
class AdaptiveScaffold extends StatelessWidget {
  final int currentIndex;
  final List<AdaptiveDestination>? destinations;
  final List<AdaptiveSidebarSection>? sections;
  final ValueChanged<int>? onNavigationIndexChanged;
  final Widget? sidebarHeader;
  final Widget? sidebarFooter;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final List<Widget>? actions;
  final Widget body;

  const AdaptiveScaffold({
    super.key,
    required this.currentIndex,
    this.destinations,
    this.sections,
    required this.body,
    this.onNavigationIndexChanged,
    this.sidebarHeader,
    this.sidebarFooter,
    this.appBar,
    this.floatingActionButton,
    this.actions,
  }) : assert(
          destinations != null || sections != null,
          'Either destinations or sections must be provided',
        );

  /// Flat list of all destinations across all sections.
  List<AdaptiveDestination> get resolvedDestinations {
    if (sections != null && sections!.isNotEmpty) {
      return sections!.expand((s) => s.destinations).toList();
    }
    return destinations ?? const [];
  }

  static const Color _sidebarBg = Color(0xFF0F172A);
  static const Color _sidebarBorder = Color(0xFF1E293B);
  static const Color _sidebarDivider = Color(0xFF1E293B);
  static const Color _sidebarSectionTitle = Color(0xFF94A3B8);
  static const Color _workspaceBg = AppColors.background;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final screenType = ResponsiveBreakpoints.getScreenType(width);

    switch (screenType) {
      case DeviceScreenType.compact:
        return _buildMobileScaffold(context);
      case DeviceScreenType.medium:
        return _buildTabletScaffold(context);
      case DeviceScreenType.expanded:
      case DeviceScreenType.large:
        return _buildDesktopScaffold(context);
    }
  }

  Widget _buildMobileScaffold(BuildContext context) {
    return Scaffold(
      appBar: appBar ?? _buildMobileWebHeader(context),
      body: _buildWorkspaceBody(context),
      floatingActionButton: floatingActionButton,
      drawer: _buildMobileDrawer(context),
    );
  }

  PreferredSizeWidget _buildMobileWebHeader(BuildContext context) {
    return AppBar(
      backgroundColor: _sidebarBg,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      shape: const Border(
        bottom: BorderSide(color: _sidebarBorder, width: 1),
      ),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
          tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: sidebarHeader != null
          ? Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.s16),
              child: SizedBox(
                height: 42,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: sidebarHeader,
                  ),
                ),
              ),
            )
          : null,
      actions: actions,
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: _sidebarBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s12,
                AppSpacing.s8,
                AppSpacing.s12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: sidebarHeader ??
                        Text(
                          AppLocalizations.of(context)?.appTitle ?? 'EduSaaS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 22),
                      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _sidebarDivider),
            Expanded(
              child: _buildCategorizedItems(context, isDrawer: true),
            ),
            if (sidebarFooter != null) ...[
              const Divider(height: 1, color: _sidebarDivider),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: sidebarFooter!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabletScaffold(BuildContext context) {
    final all = resolvedDestinations;

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex.clamp(0, all.isEmpty ? 0 : all.length - 1),
            onDestinationSelected: onNavigationIndexChanged,
            labelType: NavigationRailLabelType.all,
            backgroundColor: _sidebarBg,
            unselectedIconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
            selectedIconTheme: const IconThemeData(color: Color(0xFF38BDF8)),
            unselectedLabelTextStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            indicatorColor: const Color(0xFF1E293B),
            leading: sidebarHeader != null
                ? SizedBox(
                    width: 72,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.s16,
                        top: AppSpacing.s8,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: 256,
                            child: sidebarHeader,
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
            trailing: sidebarFooter != null
                ? Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                        child: SizedBox(
                          width: 72,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: 256,
                                child: sidebarFooter,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
            destinations: all.map((d) {
              Widget iconWidget = Icon(d.icon);
              if (d.badge != null) {
                iconWidget = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    iconWidget,
                    Positioned(top: -4, right: -4, child: d.badge!),
                  ],
                );
              } else if (d.badgeCount != null && d.badgeCount! > 0) {
                iconWidget = Badge(label: Text('${d.badgeCount}'), child: iconWidget);
              }

              Widget selectedIconWidget = Icon(d.selectedIcon ?? d.icon);
              if (d.badge != null) {
                selectedIconWidget = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    selectedIconWidget,
                    Positioned(top: -4, right: -4, child: d.badge!),
                  ],
                );
              } else if (d.badgeCount != null && d.badgeCount! > 0) {
                selectedIconWidget = Badge(label: Text('${d.badgeCount}'), child: selectedIconWidget);
              }

              return NavigationRailDestination(
                icon: iconWidget,
                selectedIcon: selectedIconWidget,
                label: Text(d.label),
              );
            }).toList(),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: _sidebarBorder),
          Expanded(
            child: _buildWorkspaceBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopScaffold(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          // Permanent Desktop Categorized Sidebar (260dp)
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: _sidebarBg,
              border: Border(
                left: Directionality.of(context) == TextDirection.rtl
                    ? const BorderSide(color: _sidebarBorder)
                    : BorderSide.none,
                right: Directionality.of(context) == TextDirection.ltr
                    ? const BorderSide(color: _sidebarBorder)
                    : BorderSide.none,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (sidebarHeader != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: sidebarHeader!,
                  ),
                const Divider(height: 1, color: _sidebarDivider),
                Expanded(
                  child: _buildCategorizedItems(context, isDrawer: false),
                ),
                if (sidebarFooter != null) ...[
                  const Divider(height: 1, color: _sidebarDivider),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: sidebarFooter!,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _buildWorkspaceBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceBody(BuildContext context) {
    return Container(
      color: _workspaceBg,
      child: AnimatedMathBackground(
        opacity: 0.18,
        gridColor: const Color(0xFF38BDF8),
        waveColor: const Color(0xFF38BDF8),
        gridSpacing: 36,
        showAxes: true,
        showWave: true,
        showFormulas: true,
        showNodes: true,
        cycleDuration: const Duration(seconds: 30),
        child: Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: Colors.transparent,
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _buildCategorizedItems(BuildContext context, {required bool isDrawer}) {
    if (sections != null && sections!.isNotEmpty) {
      int globalIndex = 0;
      final List<Widget> widgets = [];

      for (int sIdx = 0; sIdx < sections!.length; sIdx++) {
        final section = sections![sIdx];

        // Section Title Header
        if (section.title != null && section.title!.isNotEmpty) {
          widgets.add(
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s16,
                sIdx == 0 ? AppSpacing.s12 : AppSpacing.s16,
                AppSpacing.s16,
                AppSpacing.s6,
              ),
              child: Text(
                section.title!,
                style: const TextStyle(
                  color: _sidebarSectionTitle,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
            ),
          );
        }

        // Section Navigation Items
        for (final item in section.destinations) {
          final itemIndex = globalIndex++;
          final isSelected = itemIndex == currentIndex;

          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: 2,
              ),
              child: _DesktopNavTile(
                item: item,
                isSelected: isSelected,
                onTap: () {
                  if (isDrawer) {
                    Navigator.of(context).pop(); // Close drawer on mobile
                  }
                  onNavigationIndexChanged?.call(itemIndex);
                },
              ),
            ),
          );
        }
      }

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
        children: widgets,
      );
    }

    // Fallback flat destinations
    final all = destinations ?? const [];
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s12,
        horizontal: AppSpacing.s8,
      ),
      itemCount: all.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s4),
      itemBuilder: (context, index) {
        final item = all[index];
        final isSelected = index == currentIndex;

        return _DesktopNavTile(
          item: item,
          isSelected: isSelected,
          onTap: () {
            if (isDrawer) {
              Navigator.of(context).pop();
            }
            onNavigationIndexChanged?.call(index);
          },
        );
      },
    );
  }
}

class _DesktopNavTile extends StatelessWidget {
  final AdaptiveDestination item;
  final bool isSelected;
  final VoidCallback? onTap;

  const _DesktopNavTile({
    required this.item,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? const Color(0xFF1E293B)
        : Colors.transparent;
    final fgColor = isSelected ? const Color(0xFF38BDF8) : const Color(0xFFCBD5E1);
    const textColor = Colors.white;
    const inactiveTextColor = Color(0xFFE2E8F0);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        onHover: (hovered) {
          if (hovered) {
            item.onHover?.call();
          }
        },
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(10),
        hoverColor: const Color(0xFF1E293B).withValues(alpha: 0.5),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s10,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.45), width: 1)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? (item.selectedIcon ?? item.icon) : item.icon,
                color: fgColor,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? textColor : inactiveTextColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.badge != null)
                item.badge!
              else if (item.badgeCount != null && item.badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${item.badgeCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
