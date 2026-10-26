import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/datasources/whatsapp_gateway_remote_datasource.dart';
import '../../domain/entities/whatsapp_gateway_status_entity.dart';
import 'settings_section_card.dart';

class WhatsAppGatewaySettingsSection extends StatefulWidget {
  final WhatsAppGatewayRemoteDataSource? dataSource;

  const WhatsAppGatewaySettingsSection({
    super.key,
    this.dataSource,
  });

  @override
  State<WhatsAppGatewaySettingsSection> createState() =>
      _WhatsAppGatewaySettingsSectionState();
}

class _WhatsAppGatewaySettingsSectionState
    extends State<WhatsAppGatewaySettingsSection> {
  late final WhatsAppGatewayRemoteDataSource _dataSource;
  WhatsAppGatewayStatusEntity? _status;
  bool _isLoading = true;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ?? WhatsAppGatewayRemoteDataSourceImpl();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoading = true);
    final status = await _dataSource.getGatewayStatus();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAutoDispatch(bool value) async {
    setState(() => _isToggling = true);
    final updated = await _dataSource.setAutoDispatchEnabled(value);
    if (mounted) {
      setState(() {
        _isToggling = false;
        if (_status != null) {
          _status = WhatsAppGatewayStatusEntity(
            status: _status!.status,
            connectedPhone: _status!.connectedPhone,
            connectedName: _status!.connectedName,
            qrCode: _status!.qrCode,
            autoDispatchEnabled: updated,
            lastHeartbeatAt: _status!.lastHeartbeatAt,
            pendingCount: _status!.pendingCount,
            sentTodayCount: _status!.sentTodayCount,
            failedCount: _status!.failedCount,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = _status;

    return SettingsSectionCard(
      title: l10n.whatsappGatewayDialogTitle,
      icon: Icons.chat_bubble_outline_rounded,
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Header Badge
                _buildStatusBanner(status),

                const SizedBox(height: AppSpacing.s16),

                // Auto-Dispatch Toggle Tile
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.whatsappAutoDispatchToggleTitle,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.whatsappAutoDispatchToggleSubtitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: status?.autoDispatchEnabled ?? true,
                        onChanged: _isToggling ? null : _toggleAutoDispatch,
                        activeThumbColor: const Color(0xFF25D366),
                      ),
                    ],
                  ),
                ),

                // QR Code Block (if pairing requested / ready)
                if (status != null && status.isQrReady) ...[
                  const SizedBox(height: AppSpacing.s16),
                  _buildQrCodeBox(status.qrCode!),
                ],

                // Metrics Row (if connected)
                if (status != null && status.isConnected) ...[
                  const SizedBox(height: AppSpacing.s16),
                  _buildMetricsRow(status),
                ],

                const SizedBox(height: AppSpacing.s16),

                // Explanatory Note & Refresh Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        '💡 يتم ربط الهاتف مرة واحدة فقط للمدرس، ويعمل مع واتساب العادي أو الأعمال تلقائياً.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(l10n.refresh),
                      onPressed: _isLoading ? null : _fetchStatus,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildStatusBanner(WhatsAppGatewayStatusEntity? status) {
    final isConnected = status?.isConnected ?? false;
    final isQrReady = status?.isQrReady ?? false;

    Color badgeColor;
    String statusText;
    IconData statusIcon;

    if (isConnected) {
      badgeColor = const Color(0xFF25D366);
      statusText = context.l10n.whatsappGatewayConnectedStatus;
      statusIcon = Icons.check_circle_rounded;
    } else if (isQrReady) {
      badgeColor = AppColors.warning;
      statusText = context.l10n.whatsappGatewayQrReadyStatus;
      statusIcon = Icons.qr_code_scanner_rounded;
    } else {
      badgeColor = AppColors.error;
      statusText = context.l10n.whatsappGatewayDisconnectedStatus;
      statusIcon = Icons.error_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: badgeColor, size: 28),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
                if (status?.connectedPhone != null &&
                    status!.connectedPhone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${context.l10n.whatsappConnectedPhoneLabel}: ${status.connectedPhone!}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (!isConnected && !isQrReady) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '⚠️ الجلسة غير متصلة أو انتهت صلاحيتها. يرجى إعادة مسح الرمز لاستئناف الإرسال التلقائي.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeBox(String rawQrData) {
    ImageProvider? imageProvider;
    try {
      if (rawQrData.contains('base64,')) {
        final base64Str = rawQrData.split('base64,').last.trim();
        final bytes = base64Decode(base64Str);
        imageProvider = MemoryImage(bytes);
      }
    } catch (_) {
      imageProvider = null;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            context.l10n.whatsappScanQrInstruction,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (imageProvider != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: Image(
                image: imageProvider,
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            )
          else
            const Icon(Icons.qr_code_2_rounded, size: 160, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.s8),
          Text(
            context.l10n.whatsappQrAutoRefreshNote,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(WhatsAppGatewayStatusEntity status) {
    final l10n = context.l10n;
    return Row(
      children: [
        _buildMetricItem(
          label: l10n.whatsappSentTodayMetric,
          value: '${status.sentTodayCount}',
          color: const Color(0xFF25D366),
        ),
        const SizedBox(width: AppSpacing.s8),
        _buildMetricItem(
          label: l10n.whatsappPendingQueueMetric,
          value: '${status.pendingCount}',
          color: AppColors.warning,
        ),
        const SizedBox(width: AppSpacing.s8),
        _buildMetricItem(
          label: l10n.whatsappFailedMetric,
          value: '${status.failedCount}',
          color: AppColors.error,
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
