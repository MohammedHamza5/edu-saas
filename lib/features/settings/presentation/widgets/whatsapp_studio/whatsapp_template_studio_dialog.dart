import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/app_feedback.dart';
import '../../../data/datasources/whatsapp_gateway_remote_datasource.dart';
import '../../../domain/entities/whatsapp_dispatch_config_entity.dart';
import 'whatsapp_evaluation_tiers_section.dart';
import 'whatsapp_live_bubble_preview.dart';
import 'whatsapp_recipient_policy_section.dart';
import 'whatsapp_template_fields_section.dart';

class WhatsAppTemplateStudioDialog extends StatefulWidget {
  final WhatsAppGatewayRemoteDataSource dataSource;

  const WhatsAppTemplateStudioDialog({
    super.key,
    required this.dataSource,
  });

  static Future<bool?> show(
    BuildContext context, {
    required WhatsAppGatewayRemoteDataSource dataSource,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WhatsAppTemplateStudioDialog(dataSource: dataSource),
      ),
    );
  }

  @override
  State<WhatsAppTemplateStudioDialog> createState() =>
      _WhatsAppTemplateStudioDialogState();
}

class _WhatsAppTemplateStudioDialogState
    extends State<WhatsAppTemplateStudioDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final TextEditingController _headerController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _footerController = TextEditingController();
  final TextEditingController _excellentController = TextEditingController();
  final TextEditingController _goodController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _needsImprovementController =
      TextEditingController();

  WhatsAppRecipientTarget _recipientTarget = WhatsAppRecipientTarget.parentOnly;
  WhatsAppDispatchTiming _dispatchTiming = WhatsAppDispatchTiming.instant;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _showMobilePreview = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerController.dispose();
    _bodyController.dispose();
    _footerController.dispose();
    _excellentController.dispose();
    _goodController.dispose();
    _passController.dispose();
    _needsImprovementController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final config = await widget.dataSource.getDispatchConfig();
    if (!mounted) return;

    _applyConfigToControllers(config);
    setState(() => _isLoading = false);
  }

  void _applyConfigToControllers(WhatsAppDispatchConfigEntity config) {
    _headerController.text = config.headerTemplate;
    _bodyController.text = config.bodyTemplate;
    _footerController.text = config.footerTemplate;
    _excellentController.text = config.tierExcellentText;
    _goodController.text = config.tierGoodText;
    _passController.text = config.tierPassText;
    _needsImprovementController.text = config.tierNeedsImprovementText;
    _recipientTarget = config.recipientTarget;
    _dispatchTiming = config.dispatchTiming;
  }

  WhatsAppDispatchConfigEntity _buildCurrentConfig() {
    return WhatsAppDispatchConfigEntity(
      recipientTarget: _recipientTarget,
      dispatchTiming: _dispatchTiming,
      headerTemplate: _headerController.text.trim(),
      bodyTemplate: _bodyController.text.trim(),
      footerTemplate: _footerController.text.trim(),
      tierExcellentText: _excellentController.text.trim(),
      tierGoodText: _goodController.text.trim(),
      tierPassText: _passController.text.trim(),
      tierNeedsImprovementText: _needsImprovementController.text.trim(),
    );
  }

  void _insertTag(String tag) {
    final controller = _bodyController;
    final text = controller.text;
    final selection = controller.selection;

    if (selection.isValid && selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, tag);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + tag.length),
      );
    } else {
      controller.text = '$text $tag';
    }
    setState(() {});
  }

  Future<void> _resetToSmartDefaults() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.whatsappStudioResetDefaults),
        content: Text(l10n.whatsappStudioResetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.whatsappStudioResetDefaults),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _applyConfigToControllers(
        WhatsAppDispatchConfigEntity.defaultConfiguration,
      );
      setState(() {});
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _isSaving = true);
    final config = _buildCurrentConfig();
    final success = await widget.dataSource.saveDispatchConfig(config);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      AppFeedback.showSuccess(
        context,
        context.l10n.whatsappStudioSaveSuccess,
      );
      Navigator.pop(context, true);
    } else {
      AppFeedback.showError(
        context,
        'تعذر حفظ إعدادات الاستوديو، يرجى المحاولة لاحقاً',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 960;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF25D366),
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.whatsappStudioTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  l10n.whatsappStudioSubtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _resetToSmartDefaults,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text(l10n.whatsappStudioResetDefaults),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.s16),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveConfig,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 16),
              label: Text(l10n.whatsappStudioSaveAction),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF25D366),
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: const Color(0xFF25D366),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          tabs: [
            Tab(
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              text: l10n.whatsappStudioTabTemplates,
            ),
            Tab(
              icon: const Icon(Icons.military_tech_outlined, size: 18),
              text: l10n.whatsappStudioTabTiers,
            ),
            Tab(
              icon: const Icon(Icons.tune_rounded, size: 18),
              text: l10n.whatsappStudioTabPolicies,
            ),
          ],
        ),
      ),
      floatingActionButton: isWide
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  setState(() => _showMobilePreview = !_showMobilePreview),
              icon: Icon(
                _showMobilePreview
                    ? Icons.edit_note_rounded
                    : Icons.phone_android_rounded,
              ),
              label: Text(
                _showMobilePreview ? 'العودة للمحرر' : 'معاينة واتساب 📱',
              ),
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Editor Panel (48%)
                    Expanded(
                      flex: 10,
                      child: _buildTabContent(),
                    ),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    // Right Live Preview Simulator Panel (52% - Spacious & Prominent)
                    Expanded(
                      flex: 11,
                      child: Container(
                        color: AppColors.surface,
                        padding: const EdgeInsets.all(AppSpacing.s20),
                        child: Center(
                          child: SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 680),
                              child: WhatsAppLiveBubblePreview(
                                config: _buildCurrentConfig(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : _showMobilePreview
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: WhatsAppLiveBubblePreview(
                              config: _buildCurrentConfig(),
                            ),
                          ),
                        ),
                      ),
                    )
                  : _buildTabContent(),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        WhatsAppTemplateFieldsSection(
          headerController: _headerController,
          bodyController: _bodyController,
          footerController: _footerController,
          onChanged: () => setState(() {}),
          onTagSelected: _insertTag,
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: WhatsAppEvaluationTiersSection(
            excellentController: _excellentController,
            goodController: _goodController,
            passController: _passController,
            needsImprovementController: _needsImprovementController,
            onChanged: () => setState(() {}),
          ),
        ),
        WhatsAppRecipientPolicySection(
          recipientTarget: _recipientTarget,
          dispatchTiming: _dispatchTiming,
          onTargetChanged: (t) => setState(() => _recipientTarget = t),
          onTimingChanged: (t) => setState(() => _dispatchTiming = t),
        ),
      ],
    );
  }
}
