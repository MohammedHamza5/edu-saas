import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config/tenant_registry.dart';
import '../theme/tenant_branding.dart';
import '../theme/tenant_theme_cubit.dart';

/// The platform's prestige Mathematical Academic logo mark.
///
/// Features the signature geometric emblem (Sigma ∑ & coordinate curves)
/// inside a luxury squircle badge with ambient glow.
/// Automatically adapts to the active teacher / tenant's visual branding.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showName;
  final String? platformName;
  final String? subtitle;
  final Color? nameColor;
  final Color? primaryColor;
  final Color? secondaryColor;
  final String? symbol;
  final bool withGlow;
  final bool useAsset;
  final bool isHorizontal;

  const AppLogo({
    super.key,
    this.size = 64,
    this.showName = false,
    this.platformName,
    this.subtitle,
    this.nameColor,
    this.primaryColor,
    this.secondaryColor,
    this.symbol,
    this.withGlow = true,
    this.useAsset = true,
    this.isHorizontal = false,
  });

  /// Hero emblem for Login, Splash, and Landing headers
  const AppLogo.hero({
    super.key,
    this.size = 80,
    this.showName = false,
    this.platformName,
    this.subtitle,
    this.nameColor,
    this.primaryColor,
    this.secondaryColor,
    this.symbol,
    this.withGlow = true,
    this.useAsset = true,
  }) : isHorizontal = false;

  /// Compact horizontal layout for AppBars, Sidebar headers, and Drawers
  const AppLogo.compact({
    super.key,
    this.size = 42,
    this.showName = true,
    this.platformName,
    this.subtitle,
    this.nameColor,
    this.primaryColor,
    this.secondaryColor,
    this.symbol,
    this.withGlow = false,
    this.useAsset = true,
  }) : isHorizontal = true;

  /// Minimal icon-only badge for list tiles and metric cards
  const AppLogo.badge({
    super.key,
    this.size = 32,
    this.primaryColor,
    this.secondaryColor,
    this.symbol,
    this.withGlow = false,
    this.useAsset = true,
  })  : showName = false,
        platformName = null,
        subtitle = null,
        nameColor = null,
        isHorizontal = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Resolve tenant branding if available
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    final effectivePrimary = primaryColor ?? colorScheme.primary;
    final effectiveSecondary = secondaryColor ?? branding.primaryLight;
    final effectiveSymbol = symbol ?? branding.signatureSymbol;
    final effectiveName = platformName ?? branding.localizedBrandName(context);
    final effectiveNameColor = nameColor ?? (theme.brightness == Brightness.dark ? Colors.white : effectivePrimary);

    final emblem = _buildEmblem(
      effectivePrimary: effectivePrimary,
      effectiveSecondary: effectiveSecondary,
      effectiveSymbol: effectiveSymbol,
      branding: branding,
    );

    if (!showName) {
      return emblem;
    }

    if (isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          emblem,
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  effectiveName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: effectiveNameColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
                          effectivePrimary.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        emblem,
        SizedBox(height: size * 0.16),
        Text(
          effectiveName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: effectiveNameColor,
            fontSize: size * 0.26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: effectivePrimary.withValues(alpha: 0.75),
              fontSize: size * 0.16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmblem({
    required Color effectivePrimary,
    required Color effectiveSecondary,
    required String effectiveSymbol,
    required TenantBranding branding,
  }) {
    final borderRadius = BorderRadius.circular(size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: withGlow
            ? [
                BoxShadow(
                  color: effectivePrimary.withValues(alpha: 0.40),
                  blurRadius: size * 0.38,
                  offset: Offset(0, size * 0.08),
                  spreadRadius: -1,
                ),
                BoxShadow(
                  color: effectiveSecondary.withValues(alpha: 0.20),
                  blurRadius: size * 0.65,
                  offset: Offset(0, size * 0.14),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: useAsset
            ? Image.asset(
                branding.logoAsset ?? 'assets/images/brand_logo.png',
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildVectorFallback(
                  effectivePrimary: effectivePrimary,
                  effectiveSecondary: effectiveSecondary,
                  effectiveSymbol: effectiveSymbol,
                ),
              )
            : _buildVectorFallback(
                effectivePrimary: effectivePrimary,
                effectiveSecondary: effectiveSecondary,
                effectiveSymbol: effectiveSymbol,
              ),
      ),
    );
  }

  Widget _buildVectorFallback({
    required Color effectivePrimary,
    required Color effectiveSecondary,
    required String effectiveSymbol,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [effectivePrimary, effectiveSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Text(
          effectiveSymbol,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.52,
            fontWeight: FontWeight.w900,
            fontFamily: 'serif',
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
