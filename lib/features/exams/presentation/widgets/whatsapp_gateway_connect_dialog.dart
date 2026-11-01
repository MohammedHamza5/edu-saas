import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../settings/data/datasources/whatsapp_gateway_remote_datasource.dart';
import '../../../settings/domain/entities/whatsapp_gateway_status_entity.dart';

class WhatsAppGatewayConnectDialog extends StatefulWidget {
  final WhatsAppGatewayRemoteDataSource dataSource;

  const WhatsAppGatewayConnectDialog({
    super.key,
    required this.dataSource,
  });

  static Future<void> show(
    BuildContext context, {
    required WhatsAppGatewayRemoteDataSource dataSource,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => WhatsAppGatewayConnectDialog(dataSource: dataSource),
    );
  }

  @override
  State<WhatsAppGatewayConnectDialog> createState() =>
      _WhatsAppGatewayConnectDialogState();
}

class _WhatsAppGatewayConnectDialogState
    extends State<WhatsAppGatewayConnectDialog> {
  WhatsAppGatewayStatusEntity? _status;
  bool _isLoading = true;
  bool _isToggling = false;
  bool _isRefreshing = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchStatus().then((_) {
      if (mounted && (_status?.qrCode == null || _status!.qrCode!.isEmpty)) {
        _refreshQr();
      }
    });
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && (_status == null || !_status!.isConnected)) {
        _fetchStatusSilent();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    setState(() => _isLoading = true);
    final status = await widget.dataSource.getGatewayStatus();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStatusSilent() async {
    final status = await widget.dataSource.getGatewayStatus();
    if (mounted) {
      if (_status?.isConnected != status.isConnected ||
          _status?.status != status.status ||
          _status?.qrCode != status.qrCode ||
          _status?.connectedPhone != status.connectedPhone) {
        setState(() {
          _status = status;
        });
      }
    }
  }

  Future<void> _refreshQr() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await widget.dataSource.refreshQrCode();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await _fetchStatus();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _toggleAutoDispatch(bool value) async {
    setState(() => _isToggling = true);
    final updated = await widget.dataSource.setAutoDispatchEnabled(value);
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
    final isConnected = status?.isConnected ?? false;
    final screenSize = MediaQuery.sizeOf(context);
    final isWide = screenSize.width >= 660 && screenSize.height >= 460;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s20,
        AppSpacing.s8,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s8,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s8,
        AppSpacing.s20,
        AppSpacing.s16,
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Color(0xFF25D366),
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              l10n.whatsappGatewayDialogTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isWide ? 680 : 420,
          maxHeight: screenSize.height * 0.82,
        ),
        child: SingleChildScrollView(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.s32),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : isConnected
                  ? _buildConnectedContent(context, status!)
                  : _buildPairingContent(context, status, isWide),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(l10n.refresh),
          onPressed: _isLoading ? null : _fetchStatus,
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  Widget _buildPairingContent(
    BuildContext context,
    WhatsAppGatewayStatusEntity? status,
    bool isWide,
  ) {
    final l10n = context.l10n;
    final qrCode = status?.qrCode;
    final hasQr = qrCode != null && qrCode.isNotEmpty;

    final qrWidget = hasQr
        ? _buildQrCodeSection(qrCode, qrSize: isWide ? 200 : 210)
        : _buildLoadingQrSection();

    final infoWidget = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusCard(status),
        const SizedBox(height: AppSpacing.s10),
        _buildInstructionsCard(l10n),
        const SizedBox(height: AppSpacing.s10),
        _buildAutoDispatchTile(l10n, status),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          qrWidget,
          const SizedBox(width: AppSpacing.s16),
          Expanded(child: infoWidget),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusCard(status),
        const SizedBox(height: AppSpacing.s12),
        qrWidget,
        const SizedBox(height: AppSpacing.s12),
        _buildInstructionsCard(l10n),
        const SizedBox(height: AppSpacing.s12),
        _buildAutoDispatchTile(l10n, status),
      ],
    );
  }

  Widget _buildConnectedContent(
    BuildContext context,
    WhatsAppGatewayStatusEntity status,
  ) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusCard(status),
        const SizedBox(height: AppSpacing.s16),
        _buildAutoDispatchTile(l10n, status),
        const SizedBox(height: AppSpacing.s16),
        _buildMetricsRow(status),
      ],
    );
  }

  Widget _buildStatusCard(WhatsAppGatewayStatusEntity? status) {
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: badgeColor, size: 22),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
                if (isConnected &&
                    status?.connectedPhone != null &&
                    status!.connectedPhone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${context.l10n.whatsappConnectedPhoneLabel}: ${status.connectedPhone!}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
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

  Widget _buildInstructionsCard(dynamic l10n) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.whatsappPairingStepsHeader as String,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          _buildInstructionStep(
            Icons.phone_android_rounded,
            l10n.whatsappPairingStep1 as String,
          ),
          const SizedBox(height: 4),
          _buildInstructionStep(
            Icons.devices_rounded,
            l10n.whatsappPairingStep2 as String,
          ),
          const SizedBox(height: 4),
          _buildInstructionStep(
            Icons.qr_code_scanner_rounded,
            l10n.whatsappPairingStep3 as String,
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF25D366)),
        const SizedBox(width: AppSpacing.s6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAutoDispatchTile(dynamic l10n, WhatsAppGatewayStatusEntity? status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s6,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.whatsappAutoDispatchToggleTitle as String,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  l10n.whatsappAutoDispatchToggleSubtitle as String,
                  style: const TextStyle(
                    fontSize: 10,
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
    );
  }

  Widget _buildLoadingQrSection() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
          const SizedBox(height: AppSpacing.s10),
          Text(
            context.l10n.whatsappGatewayConnecting,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.s10),
          TextButton.icon(
            onPressed: _isRefreshing ? null : _refreshQr,
            icon: const Icon(Icons.refresh_rounded, size: 15),
            label: Text(
              _isRefreshing
                  ? context.l10n.whatsappGatewayRegenerating
                  : context.l10n.whatsappGatewayRegenerateAction,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeSection(String rawQrData, {required double qrSize}) {
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
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // High-contrast, pure-white frame for maximum optical readability
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: imageProvider != null
                ? Image(
                    image: imageProvider,
                    width: qrSize,
                    height: qrSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  )
                : SizedBox(
                    width: qrSize,
                    height: qrSize,
                    child: const Center(
                      child: Icon(Icons.qr_code_2_rounded,
                          size: 140, color: AppColors.textMuted),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.s8),
          // Refresh Button
          OutlinedButton.icon(
            onPressed: _isRefreshing ? null : _refreshQr,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 14),
            label: Text(
              _isRefreshing
                  ? context.l10n.whatsappGatewayRegenerating
                  : context.l10n.whatsappGatewayRegenerateAction,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s6,
              ),
              side: const BorderSide(color: Color(0xFF25D366)),
              foregroundColor: const Color(0xFF25D366),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.whatsappQrAutoRefreshNote,
            textAlign: TextAlign.center,
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
