import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/forensic_watermark_overlay.dart';
import '../../domain/entities/content_entity.dart';
import 'material_viewer_content_body.dart';
import 'material_viewer_header.dart';
import 'material_viewer_metadata_card.dart';
import 'material_viewer_security_notice.dart';
import 'video_pointer_events_helper.dart';

/// An academic, highly polished modal sheet or dialog to view and download
/// educational materials, notes, and attachments with secure signed URLs.
class MaterialViewerSheet extends StatefulWidget {
  final ContentEntity content;
  final Future<String?> Function(String storagePath) onGetSignedUrl;

  const MaterialViewerSheet({
    super.key,
    required this.content,
    required this.onGetSignedUrl,
  });

  /// Shows as a bottom sheet on mobile and as an AlertDialog on tablet/desktop.
  static Future<void> show(
    BuildContext context, {
    required ContentEntity content,
    required Future<String?> Function(String storagePath) onGetSignedUrl,
  }) async {
    setVideoPlayerPointerEvents(false);
    try {
      final width = MediaQuery.of(context).size.width;
      final height = MediaQuery.of(context).size.height;
      final isPdf = content.type == ContentType.pdf;
      if (width >= 600) {
        final maxAvailableWidth = (width - 32.0).clamp(320.0, width);
        final dialogWidth = isPdf
            ? (width > 1200 ? 1100.0 : (width * 0.94).clamp(320.0, maxAvailableWidth))
            : math.min(520.0, maxAvailableWidth);
        final maxAvailableHeight = (height - 40.0).clamp(280.0, height);
        final double dialogMaxHeight = isPdf
            ? (height * 0.94).clamp(280.0, math.min<double>(960.0, maxAvailableHeight))
            : math.min<double>(640.0, maxAvailableHeight);
        await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: dialogWidth,
                maxWidth: dialogWidth,
                minHeight: isPdf ? dialogMaxHeight : 0,
                maxHeight: dialogMaxHeight,
              ),
              child: MaterialViewerSheet(
                content: content,
                onGetSignedUrl: onGetSignedUrl,
              ),
            ),
          ),
        );
      } else {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: isPdf ? MediaQuery.of(ctx).size.height * 0.92 : 0,
              maxHeight: MediaQuery.of(ctx).size.height * 0.92,
            ),
            child: MaterialViewerSheet(
              content: content,
              onGetSignedUrl: onGetSignedUrl,
            ),
          ),
        );
      }
    } finally {
      setVideoPlayerPointerEvents(true);
    }
  }

  @override
  State<MaterialViewerSheet> createState() => _MaterialViewerSheetState();
}

class _MaterialViewerSheetState extends State<MaterialViewerSheet> {
  static final Map<String, String> _signedUrlCache = {};
  bool _isLoadingUrl = false;
  String? _signedUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    registerCloseModalListener(() {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
    _fetchUrl();
  }

  @override
  void dispose() {
    unregisterCloseModalListener();
    super.dispose();
  }

  Future<void> _fetchUrl() async {
    if (widget.content.file?.signedUrl != null &&
        widget.content.file!.signedUrl!.isNotEmpty) {
      setState(() {
        _signedUrl = widget.content.file!.signedUrl;
        _isLoadingUrl = false;
      });
      return;
    }

    final storagePath = widget.content.file?.storagePath ?? '';
    if (storagePath.isNotEmpty && _signedUrlCache.containsKey(storagePath)) {
      setState(() {
        _signedUrl = _signedUrlCache[storagePath];
        _isLoadingUrl = false;
      });
      return;
    }

    setState(() {
      _isLoadingUrl = true;
      _errorMessage = null;
    });

    try {
      final url = await widget.onGetSignedUrl(storagePath);
      if (mounted) {
        if (url != null && url.isNotEmpty && storagePath.isNotEmpty) {
          _signedUrlCache[storagePath] = url;
        }
        setState(() {
          _isLoadingUrl = false;
          _signedUrl = url;
          if (url == null || url.isEmpty) {
            _errorMessage = context.l10n.secureUrlErrorFallback;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUrl = false;
          _errorMessage = context.l10n.secureUrlGenericError;
        });
      }
    }
  }

  Future<void> _copyUrl() async {
    if (_signedUrl == null) return;
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: _signedUrl!));
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.success,
        content: Text(l10n.secureUrlCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _resolveWatermarkText() {
    final user = SupabaseService.currentUser;
    final metadata = user?.userMetadata;
    final name = (metadata?['full_name'] as String?) ??
        user?.email?.split('@').first ??
        '';
    final phone = (metadata?['phone'] as String?) ?? user?.phone ?? '';
    final id = user != null && user.id.isNotEmpty
        ? user.id.substring(0, math.min(8, user.id.length))
        : '';
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (phone.isNotEmpty) parts.add(phone);
    if (id.isNotEmpty) parts.add('ID: $id');
    return parts.isEmpty ? 'EduSaaS Protected' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = widget.content.file;
    final isPdf = widget.content.type == ContentType.pdf;
    final isImage = widget.content.type == ContentType.image;

    final color = switch (widget.content.type) {
      ContentType.pdf => const Color(0xFFEA580C),
      ContentType.video => AppColors.primary,
      ContentType.image => Colors.purple,
      ContentType.assignment => AppColors.warning,
      ContentType.exam => AppColors.success,
    };

    final icon = switch (widget.content.type) {
      ContentType.pdf => Icons.picture_as_pdf_rounded,
      ContentType.video => Icons.play_circle_fill_rounded,
      ContentType.image => Icons.image_rounded,
      ContentType.assignment => Icons.assignment_rounded,
      ContentType.exam => Icons.quiz_rounded,
    };

    final isTeacher = SupabaseService.currentUserRole == 'teacher';
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return ForensicWatermarkOverlay(
      enabled: !isPdf,
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: isDesktop
              ? BorderRadius.circular(AppSpacing.radiusLarge)
              : const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusLarge),
                ),
        ),
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: _ScrollIf(
          scroll: !isPdf,
          child: Column(
            mainAxisSize: isPdf ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isDesktop)
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

              // 1. Header
              MaterialViewerHeader(
                content: widget.content,
                color: color,
                icon: icon,
                isPdf: isPdf,
                isTeacher: isTeacher,
                signedUrl: _signedUrl,
                onCopyUrl: _copyUrl,
                onClose: () => Navigator.of(context).pop(),
              ),

              // 2. Metadata Cards (Description + File details)
              MaterialViewerMetadataCard(
                description: widget.content.description,
                file: file,
                color: color,
                isPdf: isPdf,
                isImage: isImage,
              ),

              const SizedBox(height: AppSpacing.s16),

              // 3. Content Body (Loading / Error / Image / PDF / Actions)
              MaterialViewerContentBody(
                isLoadingUrl: _isLoadingUrl,
                errorMessage: _errorMessage,
                signedUrl: _signedUrl,
                isDesktop: isDesktop,
                isPdf: isPdf,
                isImage: isImage,
                isTeacher: isTeacher,
                docTitle: widget.content.title,
                watermarkText: _resolveWatermarkText(),
                onRetry: _fetchUrl,
                onCopyUrl: _copyUrl,
              ),

              const SizedBox(height: AppSpacing.s12),

              // 4. Academic security notice
              MaterialViewerSecurityNotice(isTeacher: isTeacher),
            ],
        ),
      ),
    ),
  );
  }
}

/// Wraps [child] in a [SingleChildScrollView] only when [scroll] is true.
/// PDFs render inside a native iframe that must not be nested in a scroll view.
class _ScrollIf extends StatelessWidget {
  final bool scroll;
  final Widget child;

  const _ScrollIf({required this.scroll, required this.child});

  @override
  Widget build(BuildContext context) {
    return scroll ? SingleChildScrollView(child: child) : child;
  }
}
