import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

/// Live, real-time student subscription countdown banner.
/// Features a 1-second live ticker, color transitions (Blue -> Amber -> Red),
/// and an automatic instantaneous in-session kickoff upon reaching zero.
class StudentSubscriptionCountdownBanner extends StatefulWidget {
  const StudentSubscriptionCountdownBanner({super.key});

  @override
  State<StudentSubscriptionCountdownBanner> createState() =>
      _StudentSubscriptionCountdownBannerState();
}

class _StudentSubscriptionCountdownBannerState
    extends State<StudentSubscriptionCountdownBanner> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _initAndStartTicker();
  }

  void _initAndStartTicker() {
    _expiresAt = _resolveExpiresAt();
    if (_expiresAt == null) return;

    _updateRemaining();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
    });
  }

  DateTime? _resolveExpiresAt() {
    try {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated &&
          authState.user.subscriptionExpiresAt != null) {
        return authState.user.subscriptionExpiresAt;
      }
    } catch (_) {}

    final cached = SupabaseService.cachedSubscriptionExpiresAt;
    if (cached != null && cached.isNotEmpty) {
      return DateTime.tryParse(cached);
    }
    return null;
  }

  void _updateRemaining() {
    if (_expiresAt == null) return;
    final now = DateTime.now();
    final diff = _expiresAt!.difference(now);

    if (diff.isNegative || diff.inSeconds <= 0) {
      _ticker?.cancel();
      _ticker = null;
      setState(() {
        _remaining = Duration.zero;
      });
      // Instant in-session automatic expulsion
      _triggerAutoExpulsion();
    } else {
      setState(() {
        _remaining = diff;
      });
    }
  }

  void _triggerAutoExpulsion() {
    AppCache.clearAll();
    if (mounted) {
      context.go(AppRoutes.subscriptionExpired);
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final l10n = context.l10n;
    final studentName =
        SupabaseService.currentUser?.userMetadata?['full_name'] as String? ??
            l10n.roleStudent;

    final message = l10n.renewWhatsAppMessage(studentName);
    final encodedMessage = Uri.encodeComponent(message);

    // Dr. Antounios official WhatsApp
    const teacherPhone = '+201289196324';
    final cleanPhone = teacherPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If student has unlimited access, no countdown banner is needed
    if (_expiresAt == null) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    // Severity coloring
    final isUrgent = days < 3; // Red emergency
    final isWarning = days >= 3 && days <= 7; // Amber warning
    final bannerColor = isUrgent
        ? const Color(0xFFEF4444)
        : (isWarning ? const Color(0xFFF59E0B) : AppColors.primary);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bannerColor.withValues(alpha: isUrgent ? 0.6 : 0.25),
          width: isUrgent ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: isUrgent ? 0.16 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Top Accent Bar
            Container(
              height: 4,
              color: bannerColor,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s14,
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: bannerColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUrgent
                          ? Icons.hourglass_bottom_rounded
                          : Icons.access_time_rounded,
                      color: bannerColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s14),

                  // Texts & Countdown Units
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isUrgent
                                  ? l10n.subscriptionUrgentBannerTitle
                                  : l10n.studentSubscriptionDurationTitle,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isUrgent
                                    ? const Color(0xFFDC2626)
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: bannerColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.subscriptionActiveUntil(
                                  DateFormat.MMMd().format(_expiresAt!),
                                ),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: bannerColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),

                        // Live Ticking Units Row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildUnitBadge(
                              value: '$days',
                              label: l10n.subscriptionLiveDays(days),
                              color: bannerColor,
                            ),
                            _buildUnitBadge(
                              value: '$hours',
                              label: l10n.subscriptionLiveHours(hours),
                              color: bannerColor,
                            ),
                            _buildUnitBadge(
                              value: '$minutes',
                              label: l10n.subscriptionLiveMinutes(minutes),
                              color: bannerColor,
                            ),
                            if (days < 2)
                              _buildUnitBadge(
                                value: '$seconds',
                                label: l10n.subscriptionLiveSeconds(seconds),
                                color: bannerColor,
                                isAccent: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // WhatsApp Renew Button
                  if (isUrgent || isWarning) ...[
                    const SizedBox(width: AppSpacing.s8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: Text(
                        l10n.subscriptionUrgentBannerAction,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _openWhatsApp(context),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitBadge({
    required String value,
    required String label,
    required Color color,
    bool isAccent = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAccent
            ? color.withValues(alpha: 0.15)
            : AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAccent
              ? color.withValues(alpha: 0.4)
              : AppColors.border.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isAccent ? color : AppColors.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label.replaceAll(value, '').trim(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isAccent ? color : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
