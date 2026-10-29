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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEFEAE2), // WhatsApp Classic Chat Background
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // WhatsApp Top App Bar Mock
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s10,
            ),
            color: const Color(0xFF075E54), // WhatsApp Dark Green
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF128C7E),
                  child: Icon(Icons.person_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.s10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'د. أنطونيوس أشرف (منصة EduSaaS)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'متصل الآن 🟢',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFD4E7E5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 12, color: Colors.white),
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        l10n.whatsappStudioLivePreviewTitle,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Simulation Tier Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s6,
            ),
            color: Colors.white,
            child: Row(
              children: [
                Text(
                  l10n.whatsappStudioSimulatorTestTier,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTierChip('🌟 96%', 96.0),
                        const SizedBox(width: AppSpacing.s4),
                        _buildTierChip('👏 82%', 82.0),
                        const SizedBox(width: AppSpacing.s4),
                        _buildTierChip('👍 68%', 68.0),
                        const SizedBox(width: AppSpacing.s4),
                        _buildTierChip('💡 45%', 45.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chat Bubble Canvas
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7FFDB), // WhatsApp Sent Bubble Green
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppSpacing.radiusMedium),
                    topRight: Radius.circular(AppSpacing.radiusMedium),
                    bottomRight: Radius.circular(AppSpacing.radiusMedium),
                    bottomLeft: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      text,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF111B21),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '12:30 م',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF667781),
                          ),
                        ),
                        SizedBox(width: AppSpacing.s4),
                        Icon(
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
        ],
      ),
    );
  }

  Widget _buildTierChip(String label, double pct) {
    final isSelected = _simulatedPercentage == pct;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      labelStyle: TextStyle(
        fontSize: 10,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      selectedColor: const Color(0xFF075E54),
      backgroundColor: const Color(0xFFF1F5F9),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _simulatedPercentage = pct),
    );
  }
}
