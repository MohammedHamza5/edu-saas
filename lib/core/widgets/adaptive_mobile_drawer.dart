import 'package:flutter/material.dart';

import '../localization/generated/app_localizations.dart';
import '../theme/app_spacing.dart';
import 'adaptive_nav_destination.dart';
import 'adaptive_nav_tile.dart';

/// Mobile drawer layout for the Adaptive Scaffold.
class AdaptiveMobileDrawer extends StatelessWidget {
  final Widget? sidebarHeader;
  final Widget? sidebarFooter;
  final List<AdaptiveSidebarSection>? sections;
  final List<AdaptiveDestination>? destinations;
  final int currentIndex;
  final ValueChanged<int>? onNavigationIndexChanged;

  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarDivider = Color(0xFF1E293B);
  static const Color sidebarSectionTitle = Color(0xFF94A3B8);

  const AdaptiveMobileDrawer({
    super.key,
    this.sidebarHeader,
    this.sidebarFooter,
    this.sections,
    this.destinations,
    required this.currentIndex,
    this.onNavigationIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: sidebarBg,
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
                        sidebarHeader ??
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
            const Divider(height: 1, color: sidebarDivider),
            Expanded(child: _buildItems(context)),
            if (sidebarFooter != null) ...[
              const Divider(height: 1, color: sidebarDivider),
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

  Widget _buildItems(BuildContext context) {
    if (sections != null && sections!.isNotEmpty) {
      int globalIndex = 0;
      final List<Widget> widgets = [];

      for (int sIdx = 0; sIdx < sections!.length; sIdx++) {
        final section = sections![sIdx];

        if (section.title != null && section.title!.isNotEmpty) {
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
                  color: sidebarSectionTitle,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }

        for (final item in section.destinations) {
          final itemIndex = globalIndex++;
          final isSelected = itemIndex == currentIndex;

          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s10,
                vertical: AppSpacing.s4,
              ),
              child: AdaptiveNavTile(
                item: item,
                isSelected: isSelected,
                isCollapsed: false,
                onTap: () {
                  Navigator.of(context).pop();
                  onNavigationIndexChanged?.call(itemIndex);
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

    final all = destinations ?? const [];
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s14,
        horizontal: AppSpacing.s10,
      ),
      itemCount: all.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
      itemBuilder: (context, index) {
        final item = all[index];
        final isSelected = index == currentIndex;

        return AdaptiveNavTile(
          item: item,
          isSelected: isSelected,
          isCollapsed: false,
          onTap: () {
            Navigator.of(context).pop();
            onNavigationIndexChanged?.call(index);
          },
        );
      },
    );
  }
}
