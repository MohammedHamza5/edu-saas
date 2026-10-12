import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'interactive_lightbox_dialog.dart';

/// Production-grade resilient image viewer for exam questions and diagrams.
/// Handles Web and mobile environments gracefully with:
/// 1. Automatic retry mechanism on transient network errors.
/// 2. Timeout watchdog to eliminate infinite loading spinners.
/// 3. Clear academic error state with an interactive retry button.
/// 4. Zero unhandled broken icons.
class ExamImageViewer extends StatefulWidget {
  final String imageUrl;
  final Map<String, dynamic>? imageMeta;
  final String? caption;

  const ExamImageViewer({
    super.key,
    required this.imageUrl,
    this.imageMeta,
    this.caption,
  });

  @override
  State<ExamImageViewer> createState() => _ExamImageViewerState();
}

class _ExamImageViewerState extends State<ExamImageViewer> {
  static const int _maxAutoRetries = 2;
  static const Duration _watchdogTimeout = Duration(seconds: 35);

  int _retryCount = 0;
  int _cacheBustKey = 0;
  bool _isLoading = true;
  bool _hasError = false;
  Timer? _watchdogTimer;

  @override
  void initState() {
    super.initState();
    _startWatchdog();
  }

  @override
  void didUpdateWidget(covariant ExamImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _retryCount = 0;
      _cacheBustKey = 0;
      _isLoading = true;
      _hasError = false;
      _startWatchdog();
    }
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    super.dispose();
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(_watchdogTimeout, () {
      if (mounted && _isLoading && !_hasError) {
        _handleFailure(isTimeout: true);
      }
    });
  }

  void _handleFailure({bool isTimeout = false}) {
    _watchdogTimer?.cancel();
    if (_retryCount < _maxAutoRetries) {
      _retryCount++;
      // Keep existing URL on auto-retry to leverage browser HTTP caching and avoid breaking signed URLs
      _isLoading = true;
      _hasError = false;
      if (mounted) {
        setState(() {});
      }
      _startWatchdog();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _onImageLoaded() {
    _watchdogTimer?.cancel();
    if (mounted && (_isLoading || _hasError)) {
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    }
  }

  void _manualRetry() {
    _watchdogTimer?.cancel();
    setState(() {
      _retryCount = 0;
      _cacheBustKey = DateTime.now().millisecondsSinceEpoch;
      _isLoading = true;
      _hasError = false;
    });
    _startWatchdog();
  }

  String get _effectiveUrl {
    final base = widget.imageUrl.trim();
    if (_cacheBustKey == 0) return base;
    final separator = base.contains('?') ? '&' : '?';
    return '$base${separator}_rb=$_cacheBustKey';
  }

  Widget _buildLoadingPlaceholder(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          if (_retryCount > 0) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              '${context.l10n.loading} ($_retryCount/$_maxAutoRetries)',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 130),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.35),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.broken_image_rounded,
              color: AppColors.textMuted,
              size: 32,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              context.l10n.failedToLoadImage,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s12),
            OutlinedButton.icon(
              onPressed: _manualRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(context.l10n.retry),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                side: const BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(BuildContext context, String url) {
    if (_hasError) {
      return _buildErrorCard(context);
    }

    if (kIsWeb) {
      return Image.network(
        url,
        key: ValueKey(url),
        fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _isLoading) _onImageLoaded();
            });
            return child;
          }
          return _buildLoadingPlaceholder(context);
        },
        errorBuilder: (ctx, error, stackTrace) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasError) _handleFailure();
          });
          return _hasError
              ? _buildErrorCard(context)
              : _buildLoadingPlaceholder(context);
        },
      );
    }

    return CachedNetworkImage(
      key: ValueKey(url),
      imageUrl: url,
      memCacheWidth: 1000,
      memCacheHeight: 1000,
      maxWidthDiskCache: 1400,
      fit: BoxFit.contain,
      imageBuilder: (ctx, imageProvider) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isLoading) _onImageLoaded();
        });
        return Image(image: imageProvider, fit: BoxFit.contain);
      },
      placeholder: (ctx, _) => _buildLoadingPlaceholder(context),
      errorWidget: (ctx, _, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasError) _handleFailure();
        });
        return _hasError
            ? _buildErrorCard(context)
            : _buildLoadingPlaceholder(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final widthPercent = (widget.imageMeta?['width_percent'] as num?)?.toInt() ?? 50;
    final enableZoom = widget.imageMeta?['enable_zoom'] as bool? ?? true;
    final url = _effectiveUrl;

    const Alignment align = Alignment.center;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final screenW = constraints.maxWidth;
          final effectivePercent = screenW < 500 ? 100 : widthPercent;
          final targetWidth = screenW * (effectivePercent / 100);

          return Align(
            alignment: align,
            child: SizedBox(
              width: targetWidth,
              child: InkWell(
                onTap: (enableZoom && !_hasError && !_isLoading)
                    ? () => InteractiveLightboxDialog.show(
                          context,
                          imageUrl: widget.imageUrl,
                          title: widget.caption,
                        )
                    : null,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                        ),
                        child: _buildImageWidget(context, url),
                      ),
                    ),
                    if (enableZoom && !_hasError && !_isLoading)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
