import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../errors/error_mapper.dart';
import '../errors/failures.dart';
import '../localization/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

/// 🚨 AppErrorView — Modern Mathematical Academic Error Presentation Widget.
///
/// Converts any error, exception, or failure into a clear, dignified, and actionable
/// experience for students, teachers, and parents.
///
/// Features:
/// - Categorized visual indicators (Network, Session, Permissions, Exams, Server)
/// - Plain-language title and human-friendly explanation
/// - Actionable guidance box ("What you can do")
/// - Primary (Retry) and optional secondary action buttons
/// - One-tap copy of diagnostic error code for tech support / teacher
/// - Compact mode for in-card or dialog embedding
class AppErrorView extends StatelessWidget {
  /// The error to display. Can be a [Failure], [Exception], [UserFriendlyError], or [String].
  final dynamic error;

  /// Optional manual override for error message (backward compatibility).
  final String? message;

  /// Optional manual override for error title.
  final String? title;

  /// Callback executed when the user taps "Retry".
  final VoidCallback? onRetry;

  /// Label for retry button (defaults to localized "Retry").
  final String? retryLabel;

  /// Optional secondary action callback (e.g., Go Back or Login).
  final VoidCallback? onSecondaryAction;

  /// Optional label for secondary action button.
  final String? secondaryActionLabel;

  /// Whether to render in condensed/compact layout (ideal for cards, dialogs, player overlays).
  final bool isCompact;

  /// Whether to display the technical error code & copy button for tech support.
  final bool showSupportCode;

  /// Optional custom padding.
  final EdgeInsetsGeometry? padding;

  const AppErrorView({
    super.key,
    this.error,
    this.message,
    this.title,
    this.onRetry,
    this.retryLabel,
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.isCompact = false,
    this.showSupportCode = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final effectiveError = ErrorMapper.resolve(
      error ?? message ?? (l10n != null ? l10n.errorOccurred : 'An unexpected error occurred'),
    );

    final displayTitle = title ?? effectiveError.title(context);
    final displayMessage = message ?? effectiveError.message(context);
    final displayHint = effectiveError.hint(context);

    if (isCompact) {
      return _buildCompactView(context, effectiveError, displayTitle, displayMessage, l10n);
    }

    return _buildFullView(context, effectiveError, displayTitle, displayMessage, displayHint, l10n);
  }

  Widget _buildFullView(
    BuildContext context,
    UserFriendlyError resolvedError,
    String displayTitle,
    String displayMessage,
    String? displayHint,
    AppLocalizations? l10n,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Harmonious tinting for the icon based on error severity
    final badgeColor = switch (resolvedError.type) {
      FailureType.network => AppColors.primary,
      FailureType.permission || FailureType.sessionExpired => const Color(0xFFD97706), // Amber
      FailureType.examExpired || FailureType.examSubmitted => const Color(0xFF2563EB), // Blue
      FailureType.videoProcessing => const Color(0xFF0284C7), // Sky
      FailureType.validation => const Color(0xFFE11D48), // Rose
      _ => AppColors.error,
    };

    return Center(
      child: SingleChildScrollView(
        padding: padding ?? const EdgeInsets.all(AppSpacing.s24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── 1. Thematic Academic Icon Container ───────────────────────
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    resolvedError.icon,
                    color: badgeColor,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),

              // ── 2. Error Title ───────────────────────────────────────────
              Text(
                displayTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),

              // ── 3. Friendly Error Description ─────────────────────────────
              Text(
                displayMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              // ── 4. Actionable Guidance Box ("ما يمكنك فعله") ───────────────
              if (displayHint != null && displayHint.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceVariant : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(
                      color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: badgeColor,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n != null ? l10n.actionTip : 'What you can do:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayHint,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── 5. Action Buttons ─────────────────────────────────────────
              const SizedBox(height: AppSpacing.s24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.s12,
                runSpacing: AppSpacing.s8,
                children: [
                  if (onRetry != null && resolvedError.canRetry)
                    AppButton(
                      text: retryLabel ?? (l10n != null ? l10n.retry : 'Retry'),
                      onPressed: onRetry,
                      icon: Icons.refresh_rounded,
                      width: onSecondaryAction != null ? 140 : 180,
                    ),
                  if (onSecondaryAction != null)
                    AppButton(
                      text: secondaryActionLabel ??
                          (resolvedError.isSessionExpired
                              ? (l10n != null ? l10n.signInAgain : 'Sign In Again')
                              : (l10n != null ? l10n.goBack : 'Go Back')),
                      onPressed: onSecondaryAction,
                      variant: AppButtonVariant.outlined,
                      width: onRetry != null ? 140 : 180,
                    ),
                ],
              ),

              // ── 6. Tech Support Code & Copy Diagnostic Button ─────────────
              if (showSupportCode) ...[
                const SizedBox(height: AppSpacing.s24),
                _buildSupportCodeBadge(context, resolvedError, l10n, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactView(
    BuildContext context,
    UserFriendlyError resolvedError,
    String displayTitle,
    String displayMessage,
    AppLocalizations? l10n,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariant : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: isDark ? AppColors.border : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            resolvedError.icon,
            color: AppColors.error,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  displayMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onRetry != null && resolvedError.canRetry) ...[
            const SizedBox(width: AppSpacing.s8),
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: retryLabel ?? (l10n != null ? l10n.retry : 'Retry'),
              color: AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportCodeBadge(
    BuildContext context,
    UserFriendlyError resolvedError,
    AppLocalizations? l10n,
    bool isDark,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      onTap: () {
        Clipboard.setData(ClipboardData(text: resolvedError.toDiagnosticSummary()));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n != null
                  ? l10n.errorDetailsCopied
                  : 'Error details copied to clipboard successfully',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Icon(
              Icons.copy_rounded,
              size: 13,
              color: isDark ? Colors.white54 : AppColors.textSecondary,
            ),
            Text(
              l10n != null
                  ? l10n.errorCodeLabel(resolvedError.code)
                  : 'Error Code: ${resolvedError.code}',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : AppColors.textSecondary,
              ),
            ),
            Text(
              '• ${l10n != null ? l10n.copyErrorDetails : "Copy"}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.primaryLight : AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
