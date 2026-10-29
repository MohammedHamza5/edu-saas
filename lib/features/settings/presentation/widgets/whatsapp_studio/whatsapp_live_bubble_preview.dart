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
            blurRadius: 16,
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
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s10,
            ),
            color: headerColor,
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFF128C7E),
                  child: Icon(Icons.person_rounded,
                      size: 20, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'د. أنطونيوس أشرف',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'متصل الآن 🟢',
                        style: TextStyle(
                          fontSize: 10,
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
                    size: 19,
                  ),
                  onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
                ),
              ],
            ),
          ),

          // 2. Simulation Tier Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: tierBarColor,
              border: Border(
                bottom: BorderSide(color: tierBorderColor),
              ),
            ),
            child: Row(
              children: [
                Text(
                  l10n.whatsappStudioSimulatorTestTier,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTierChip('🌟 ممتاز 96%', 96.0),
                        const SizedBox(width: AppSpacing.s4),
                        _buildTierChip('👏 جيد 82%', 82.0),
                        const SizedBox(width: AppSpacing.s4),
                        _buildTierChip('👍 مقبول 68%', 68.0),
                        const SizedBox(width: AppSpacing.s4),
                        _buildTierChip('💡 متابعة 45%', 45.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Chat Canvas & Message Bubble
          Container(
            color: bgColor,
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppSpacing.radiusMedium),
                    topRight: Radius.circular(AppSpacing.radiusMedium),
                    bottomRight: Radius.circular(AppSpacing.radiusMedium),
                    bottomLeft: Radius.circular(3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _isDarkMode ? 0.3 : 0.08,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
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
                      const SizedBox(height: AppSpacing.s6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '10:25 م',
                            style: TextStyle(
                              fontSize: 10,
                              color: timeColor,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          const Icon(
                            Icons.done_all_rounded,
                            size: 14,
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
            fontSize: 13,
            height: 1.55,
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

  Widget _buildTierChip(String label, double pct) {
    final isSelected = _simulatedPercentage == pct;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? Colors.white
            : (_isDarkMode ? Colors.white70 : AppColors.textPrimary),
      ),
      selectedColor: const Color(0xFF25D366),
      backgroundColor: _isDarkMode
          ? const Color(0xFF1E293B)
          : const Color(0xFFE2E8F0),
      side: BorderSide(
        color: isSelected
            ? const Color(0xFF25D366)
            : (_isDarkMode ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _simulatedPercentage = pct),
    );
  }
}
