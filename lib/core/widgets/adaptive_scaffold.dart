import 'package:flutter/material.dart';
import '../localization/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/responsive_breakpoints.dart';
import 'language_switcher_button.dart';
import 'math_grid_background.dart';

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

/// Adaptive scaffold delivering:
/// - Desktop (>= 840dp): Permanent categorized mathematical styled Sidebar (260dp)
/// - Tablet (600 - 839dp): Material 3 [NavigationRail]
/// - Mobile (< 600dp): Bottom [NavigationBar] with full [Drawer] support for all categorized screens
class AdaptiveScaffold extends StatefulWidget {
  final int currentIndex;
  final List<AdaptiveDestination>? destinations;
  final List<AdaptiveSidebarSection>? sections;
  final ValueChanged<int>? onNavigationIndexChanged;
  final Widget? sidebarHeader;
  final Widget? sidebarFooter;
  final Widget? collapsedSidebarHeader;
  final Widget? collapsedSidebarFooter;
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
    this.collapsedSidebarHeader,
    this.collapsedSidebarFooter,
    this.appBar,
    this.floatingActionButton,
    this.actions,
  }) : assert(
         destinations != null || sections != null,
         'Either destinations or sections must be provided',
       );

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  /// Session-wide static state so the collapse/expanded preference persists across route changes
  static bool _isSidebarCollapsed = false;
  static bool _hasUserToggledSidebarCollapse = false;

  void _toggleSidebar(bool currentCollapsed) {
    setState(() {
      _hasUserToggledSidebarCollapse = true;
      _isSidebarCollapsed = !currentCollapsed;
    });
  }

  /// Flat list of all destinations across all sections.
  List<AdaptiveDestination> get resolvedDestinations {
    if (widget.sections != null && widget.sections!.isNotEmpty) {
      return widget.sections!.expand((s) => s.destinations).toList();
    }
    return widget.destinations ?? const [];
  }

  static const Color _sidebarBg = Color(0xFF0F172A);
  static const Color _sidebarBorder = Color(0xFF1E293B);
  static const Color _sidebarDivider = Color(0xFF1E293B);
  static const Color _sidebarSectionTitle = Color(0xFF94A3B8);
  static const Color _workspaceBg = AppColors.background;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Devices below tablet threshold (< 840dp, including phones and portrait tablets like iPad 768-834dp)
    // use the clean Drawer layout so the academic workspace has 100% of the screen width,
    // avoiding squished cards, tables, and cramped multi-column layouts.
    if (width < ResponsiveBreakpoints.tabletThreshold) {
      return _buildMobileScaffold(context);
    }

    return _buildResponsiveSidebarScaffold(context, width);
  }

  Widget _buildMobileScaffold(BuildContext context) {
    return Scaffold(
      appBar: widget.appBar ?? _buildMobileWebHeader(context),
      body: _buildWorkspaceBody(context),
      floatingActionButton: widget.floatingActionButton,
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
      shape: const Border(bottom: BorderSide(color: _sidebarBorder, width: 1)),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
          tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      title: widget.sidebarHeader != null
          ? Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.s16),
              child: SizedBox(
                height: 42,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: widget.sidebarHeader,
                  ),
                ),
              ),
            )
          : null,
      actions: widget.actions ??
          const [
            LanguageSwitcherButton(compact: true),
            SizedBox(width: AppSpacing.s8),
          ],
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
                    child:
                        widget.sidebarHeader ??
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
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF94A3B8),
                        size: 22,
                      ),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _sidebarDivider),
            Expanded(child: _buildCategorizedItems(context, isDrawer: true)),
            if (widget.sidebarFooter != null) ...[
              const Divider(height: 1, color: _sidebarDivider),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: widget.sidebarFooter!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveSidebarScaffold(
    BuildContext context,
    double screenWidth,
  ) {
    final l10n = AppLocalizations.of(context);
    final collapseTooltip = l10n?.collapseSidebar ?? 'طي الشريط';
    final expandTooltip = l10n?.expandSidebar ?? 'إظهار الشريط';

    // Default expanded on wide screens (>= 840dp, e.g. tablet landscape, laptops, desktops).
    // If user explicitly clicked the collapse toggle, honor their choice.
    final isCollapsed = _hasUserToggledSidebarCollapse
        ? _isSidebarCollapsed
        : false;

    final sidebarWidth = isCollapsed ? 74.0 : 274.0;

    return Scaffold(
      appBar: widget.appBar,
      floatingActionButton: widget.floatingActionButton,
      body: Row(
        children: [
          // Responsive Collapsible Categorized Sidebar (74dp collapsed, 274dp expanded)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            width: sidebarWidth,
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
                _buildSidebarHeader(
                  context,
                  isCollapsed: isCollapsed,
                  collapseTooltip: collapseTooltip,
                  expandTooltip: expandTooltip,
                ),
                const Divider(height: 1, color: _sidebarDivider),
                Expanded(
                  child: _buildCategorizedItems(
                    context,
                    isDrawer: false,
                    isCollapsed: isCollapsed,
                  ),
                ),
                _buildSidebarFooter(context, isCollapsed: isCollapsed),
              ],
            ),
          ),
          Expanded(child: _buildWorkspaceBody(context)),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(
    BuildContext context, {
    required bool isCollapsed,
    required String collapseTooltip,
    required String expandTooltip,
  }) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.menu_rounded,
                color: Color(0xFF38BDF8),
                size: 22,
              ),
              tooltip: expandTooltip,
              hoverColor: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              onPressed: () => _toggleSidebar(isCollapsed),
            ),
            const SizedBox(height: AppSpacing.s8),
            if (widget.collapsedSidebarHeader != null)
              widget.collapsedSidebarHeader!
            else if (widget.sidebarHeader != null)
              SizedBox(
                width: 40,
                height: 40,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: widget.sidebarHeader,
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s14,
        AppSpacing.s14,
        AppSpacing.s10,
        AppSpacing.s14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: widget.sidebarHeader ?? const SizedBox.shrink(),
          ),
          const SizedBox(width: AppSpacing.s6),
          IconButton(
            icon: const Icon(
              Icons.menu_open_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
            tooltip: collapseTooltip,
            hoverColor: const Color(0xFF38BDF8).withValues(alpha: 0.15),
            onPressed: () => _toggleSidebar(isCollapsed),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter(
    BuildContext context, {
    required bool isCollapsed,
  }) {
    if (isCollapsed) {
      if (widget.collapsedSidebarFooter != null) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(height: 1, color: _sidebarDivider),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s12,
                horizontal: AppSpacing.s8,
              ),
              child: widget.collapsedSidebarFooter!,
            ),
          ],
        );
      }
      return const SizedBox.shrink();
    }

    if (widget.sidebarFooter != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1, color: _sidebarDivider),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: widget.sidebarFooter!,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildWorkspaceBody(BuildContext context) {
    return Container(
      color: _workspaceBg,
      child: MathGridBackground(
        animated: false,
        opacity: 0.14,
        gridColor: const Color(0xFF38BDF8),
        gridSpacing: 36,
        showCartesianAxes: true,
        showFormulas: true,
        child: Theme(
          data: Theme.of(
            context,
          ).copyWith(scaffoldBackgroundColor: Colors.transparent),
          child: widget.body,
        ),
      ),
    );
  }

  Widget _buildCategorizedItems(
    BuildContext context, {
    required bool isDrawer,
    bool isCollapsed = false,
  }) {
    if (widget.sections != null && widget.sections!.isNotEmpty) {
      int globalIndex = 0;
      final List<Widget> widgets = [];

      for (int sIdx = 0; sIdx < widget.sections!.length; sIdx++) {
        final section = widget.sections![sIdx];

        // Section Title Header / Divider
        if (isCollapsed) {
          if (sIdx > 0) {
            widgets.add(
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s8,
                ),
                color: _sidebarDivider.withValues(alpha: 0.7),
              ),
            );
          }
        } else if (section.title != null && section.title!.isNotEmpty) {
          widgets.add(
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s16,
                sIdx == 0 ? AppSpacing.s14 : AppSpacing.s20,
                AppSpacing.s16,
                AppSpacing.s8,
              ),
              child: Text(
                section.title!,
                style: const TextStyle(
                  color: _sidebarSectionTitle,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        // Section Navigation Items
        for (final item in section.destinations) {
          final itemIndex = globalIndex++;
          final isSelected = itemIndex == widget.currentIndex;

          widgets.add(
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? AppSpacing.s6 : AppSpacing.s10,
                vertical: AppSpacing.s4,
              ),
              child: _DesktopNavTile(
                item: item,
                isSelected: isSelected,
                isCollapsed: isCollapsed,
                onTap: () {
                  if (isDrawer) {
                    Navigator.of(context).pop(); // Close drawer on mobile
                  }
                  widget.onNavigationIndexChanged?.call(itemIndex);
                },
              ),
            ),
          );
        }
      }

      return ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
        children: widgets,
      );
    }

    // Fallback flat destinations
    final all = widget.destinations ?? const [];
    return ListView.separated(
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.s14,
        horizontal: isCollapsed ? AppSpacing.s6 : AppSpacing.s10,
      ),
      itemCount: all.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
      itemBuilder: (context, index) {
        final item = all[index];
        final isSelected = index == widget.currentIndex;

        return _DesktopNavTile(
          item: item,
          isSelected: isSelected,
          isCollapsed: isCollapsed,
          onTap: () {
            if (isDrawer) {
              Navigator.of(context).pop();
            }
            widget.onNavigationIndexChanged?.call(index);
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
  final bool isCollapsed;

  const _DesktopNavTile({
    required this.item,
    required this.isSelected,
    this.onTap,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = isSelected
        ? const Color(0xFF38BDF8)
        : const Color(0xFFCBD5E1);
    const textColor = Colors.white;
    const inactiveTextColor = Color(0xFFE2E8F0);

    Widget iconBox = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF38BDF8).withValues(alpha: 0.16)
            : const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF38BDF8).withValues(alpha: 0.45)
              : const Color(0xFF334155).withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          isSelected ? (item.selectedIcon ?? item.icon) : item.icon,
          color: fgColor,
          size: 20,
        ),
      ),
    );

    if (item.badge != null) {
      iconBox = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          iconBox,
          PositionedDirectional(top: -4, end: -4, child: item.badge!),
        ],
      );
    } else if (item.badgeCount != null && item.badgeCount! > 0) {
      iconBox = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          iconBox,
          PositionedDirectional(
            top: -4,
            end: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66EF4444),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                '${item.badgeCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Center(
          child: Tooltip(
            message: item.label,
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onTap,
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(10),
                hoverColor: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                child: iconBox,
              ),
            ),
          ),
        ),
      );
    }

    final bgColor = isSelected ? const Color(0xFF1E293B) : Colors.transparent;

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
                ? Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                    width: 1,
                  )
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
              iconBox,
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? textColor : inactiveTextColor,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        fontSize: 14,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF7DD3FC)
                              : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (item.badge != null)
                item.badge!
              else if (item.badgeCount != null && item.badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
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
