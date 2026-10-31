import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/whatsapp_report_generator.dart';

class ExamWhatsAppModalFooter extends StatelessWidget {
  final String messageText;
  final String selectedTargetPhone;
  final VoidCallback onSent;
  final VoidCallback? onNext;
  final String? nextStudentName;

  const ExamWhatsAppModalFooter({
    super.key,
    required this.messageText,
    required this.selectedTargetPhone,
    required this.onSent,
    this.onNext,
    this.nextStudentName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasPhone = selectedTargetPhone.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Copy Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(l10n.copyActionShort),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: messageText));
                    onSent();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.messageCopiedToast),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                ),
                const SizedBox(width: AppSpacing.s8),

                // Launch WhatsApp Button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      l10n.sendViaWhatsAppNowAction,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: !hasPhone
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.missingPhoneWarningToast,
                                ),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                        : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final launched =
                                await WhatsAppReportGenerator.launchWhatsApp(
                              phone: selectedTargetPhone,
                              message: messageText,
                            );
                            onSent();
                            if (!launched && context.mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.whatsAppLaunchFailedToast,
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                  ),
                ),
              ],
            ),

            // Next student runner button (if in queue)
            if (onNext != null && nextStudentName != null) ...[
              const SizedBox(height: AppSpacing.s8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(
                    l10n.nextStudentInQueueAction(nextStudentName!),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onNext!();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
