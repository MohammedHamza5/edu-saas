import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../extensions/localized_context_extension.dart';
import '../theme/app_colors.dart';
import 'app_logger.dart';

abstract final class PdfLauncherHelper {
  /// Opens a signed PDF URL in a high-performance external browser window/tab.
  ///
  /// On iPad Safari, this leverages Apple's native CoreGraphics engine:
  /// - 120Hz ProMotion silky-smooth scrolling
  /// - Instant HTTP Range page streaming (no full-file wait)
  /// - Apple Pencil annotation & equation markup
  /// - Split View / Slide Over side-by-side with lecture videos
  /// - Zero canvas memory overhead or iOS Safari crashes
  static Future<bool> launchPdfUrl(
    String url, {
    BuildContext? context,
  }) async {
    if (url.trim().isEmpty) return false;

    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );

      if (!launched && context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.secureUrlErrorFallback),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return launched;
    } catch (e, st) {
      AppLogger.e(
        'PdfLauncherHelper',
        'Failed to launch PDF URL: $url',
        error: e,
        stackTrace: st,
      );
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.secureUrlGenericError),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return false;
    }
  }
}
