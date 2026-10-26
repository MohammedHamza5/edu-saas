import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../content/presentation/widgets/secure_pdf_viewer.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';

/// PDF booklet viewer component for exam taking, supporting split-screen desktop mode
/// and full-screen mobile overlay with forensic watermark protection.
class ExamTakingPdfBooklet extends StatefulWidget {
  final ExamEntity exam;
  final bool isMobileOverlay;
  final int? currentQuestionIndex;
  final int? totalQuestions;
  final VoidCallback? onCloseMobileOverlay;

  const ExamTakingPdfBooklet({
    super.key,
    required this.exam,
    this.isMobileOverlay = false,
    this.currentQuestionIndex,
    this.totalQuestions,
    this.onCloseMobileOverlay,
  });

  /// Computes student identification watermark text for document protection
  static String resolveWatermarkText() {
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
  State<ExamTakingPdfBooklet> createState() => _ExamTakingPdfBookletState();
}

class _ExamTakingPdfBookletState extends State<ExamTakingPdfBooklet> {
  String? _cachedPdfSignedUrl;
  bool _isLoadingPdfUrl = false;
  String? _pdfLoadError;

  @override
  void initState() {
    super.initState();
    _loadSignedPdfUrl();
  }

  @override
  void didUpdateWidget(covariant ExamTakingPdfBooklet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exam.pdfStoragePath != widget.exam.pdfStoragePath) {
      _cachedPdfSignedUrl = null;
      _loadSignedPdfUrl();
    }
  }

  void _loadSignedPdfUrl() {
    if (_cachedPdfSignedUrl != null || _isLoadingPdfUrl) return;
    final path = widget.exam.pdfStoragePath;
    if (path == null || path.isEmpty) return;

    setState(() {
      _isLoadingPdfUrl = true;
      _pdfLoadError = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final url = await context.read<ExamsCubit>().getSignedPdfUrl(
              path,
              storageProvider: widget.exam.pdfStorageProvider,
            );
        if (mounted) {
          setState(() {
            _cachedPdfSignedUrl = url;
            _isLoadingPdfUrl = false;
            if (url == null || url.isEmpty) {
              _pdfLoadError = context.l10n.secureUrlErrorFallback;
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isLoadingPdfUrl = false;
            _pdfLoadError = context.l10n.secureUrlGenericError;
          });
        }
      }
    });
  }

  Widget _buildViewerContent() {
    if (_isLoadingPdfUrl) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLoadingView.compact(size: 32),
            const SizedBox(height: AppSpacing.s12),
            Text(
              context.l10n.examPdfLoading,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_pdfLoadError != null || _cachedPdfSignedUrl == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 36,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                _pdfLoadError ?? context.l10n.secureUrlGenericError,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.s12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _cachedPdfSignedUrl = null;
                    _pdfLoadError = null;
                  });
                  _loadSignedPdfUrl();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(context.l10n.retryAction),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey.shade900,
      child: buildSecurePdfViewer(
        pdfUrl: _cachedPdfSignedUrl!,
        watermarkText: ExamTakingPdfBooklet.resolveWatermarkText(),
        docTitle: widget.exam.pdfFileName ?? widget.exam.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isMobileOverlay) {
      return _buildViewerContent();
    }

    final qIndex = widget.currentQuestionIndex ?? 0;
    final totalQ = widget.totalQuestions ?? 0;

    return Positioned.fill(
      child: Container(
        color: AppColors.surface,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s10,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      widget.exam.pdfFileName ?? widget.exam.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (totalQ > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: Text(
                        context.l10n.questionProgress(qIndex + 1, totalQ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                  ],
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8,
                      ),
                    ),
                    onPressed: widget.onCloseMobileOverlay,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(
                      context.l10n.hideExamBooklet,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildViewerContent(),
            ),
          ],
        ),
      ),
    );
  }
}
