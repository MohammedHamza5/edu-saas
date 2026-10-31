import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/entities/whatsapp_dispatch_config_entity.dart';

class WhatsAppLiveBubblePreview extends StatefulWidget {
  final WhatsAppDispatchConfigEntity config;

  const WhatsAppLiveBubblePreview({
    super.key,
    required this.config,
  });

  @override
  State<WhatsAppLiveBubblePreview> createState() =>
      _WhatsAppLiveBubblePreviewState();
}

class _WhatsAppLiveBubblePreviewState extends State<WhatsAppLiveBubblePreview> {
  double _simulatedPercentage = 96.0;
  bool _isDarkMode = true; // Default to Dark Mode to match platform theme

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = widget.config.renderLivePreview(
      studentName: 'عمر أحمد',
      examTitle: 'الاحتمالات والتوافيق (Advanced)',
      score: (_simulatedPercentage * 0.5).round(),
      maxScore: 50,
      percentage: _simulatedPercentage,
      groupName: 'SAT Basics & Algebra Bootcamp',
      teacherName: 'د. أنطونيوس أشرف',
    );

    // Official WhatsApp Colors
    final bgColor =
        _isDarkMode ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2);
    final headerColor =
        _isDarkMode ? const Color(0xFF1F2C34) : const Color(0xFF008069);
    final bubbleColor =
        _isDarkMode ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3);
    final textColor =
        _isDarkMode ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
    final timeColor =
        _isDarkMode ? const Color(0xFF8696A0) : const Color(0xFF667781);
    final tierBarColor =
        _isDarkMode ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final tierBorderColor =
        _isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: _isDarkMode
              ? const Color(0xFF1F2C34)
              : const Color(0xFFD1D7DB),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. WhatsApp Top App Bar Mock
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            color: headerColor,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF128C7E),
                  child: Icon(
                    Icons.person_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'د. أنطونيوس أشرف',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'متصل الآن 🟢',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _isDarkMode
                              ? const Color(0xFF8696A0)
                              : const Color(0xFFD4E7E5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Theme Mode Switch (Dark / Light)
                IconButton(
                  tooltip: _isDarkMode
                      ? 'التبديل إلى وضع واتساب الفاتح ☀️'
                      : 'التبديل إلى وضع واتساب الداكن 🌙',
                  icon: Icon(
                    _isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                  onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
                ),
              ],
            ),
          ),

          // 2. Simulation Tier Selector Bar (Enlarged Cards)
          Container(
            padding: const EdgeInsets.all(AppSpacing.s14),
            decoration: BoxDecoration(
              color: tierBarColor,
              border: Border(
                bottom: BorderSide(color: tierBorderColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: _isDarkMode
                          ? Colors.white70
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      l10n.whatsappStudioSimulatorTestTier,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _isDarkMode
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s10),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    _buildTierButton(
                      label: 'ممتاز',
                      percentageStr: '96%',
                      pct: 96.0,
                      icon: Icons.star_rounded,
                      accentColor: const Color(0xFF10B981),
                    ),
                    _buildTierButton(
                      label: 'جيد جداً',
                      percentageStr: '82%',
                      pct: 82.0,
                      icon: Icons.thumb_up_alt_rounded,
                      accentColor: const Color(0xFF3B82F6),
                    ),
                    _buildTierButton(
                      label: 'أداء مقبول',
                      percentageStr: '68%',
                      pct: 68.0,
                      icon: Icons.check_circle_outline_rounded,
                      accentColor: const Color(0xFFF59E0B),
                    ),
                    _buildTierButton(
                      label: 'يحتاج متابعة',
                      percentageStr: '45%',
                      pct: 45.0,
                      icon: Icons.lightbulb_outline_rounded,
                      accentColor: const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Chat Canvas & Message Bubble (Enlarged and Spacious)
          Container(
            color: bgColor,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s20,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s14,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppSpacing.radiusMedium),
                    topRight: Radius.circular(AppSpacing.radiusMedium),
                    bottomRight: Radius.circular(AppSpacing.radiusMedium),
                    bottomLeft: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _isDarkMode ? 0.35 : 0.1,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Render message with WhatsApp *bold* formatting support
                      _buildFormattedText(text, textColor),
                      const SizedBox(height: AppSpacing.s8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '10:25 م',
                            style: TextStyle(
                              fontSize: 11,
                              color: timeColor,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s6),
                          const Icon(
                            Icons.done_all_rounded,
                            size: 16,
                            color: Color(0xFF53BDEB), // Double Blue Ticks
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Parses WhatsApp markdown (*bold*) into rich styled text spans
  Widget _buildFormattedText(String content, Color baseTextColor) {
    final spans = <TextSpan>[];
    final parts = content.split('*');

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;

      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: part,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.6,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: baseTextColor,
          ),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.start,
    );
  }

  /// Enlarged, touch-friendly interactive simulation card
  Widget _buildTierButton({
    required String label,
    required String percentageStr,
    required double pct,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _simulatedPercentage == pct;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _simulatedPercentage = pct),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall + 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (_isDarkMode
                    ? accentColor.withValues(alpha: 0.22)
                    : accentColor.withValues(alpha: 0.14))
                : (_isDarkMode
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall + 2),
            border: Border.all(
              color: isSelected
                  ? accentColor
                  : (_isDarkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1)),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? accentColor
                    : (_isDarkMode ? Colors.white60 : AppColors.textSecondary),
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? (_isDarkMode ? Colors.white : accentColor)
                      : (_isDarkMode
                          ? Colors.white70
                          : AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.s6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor
                      : (_isDarkMode
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  percentageStr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (_isDarkMode ? Colors.white70 : AppColors.textMuted),
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
