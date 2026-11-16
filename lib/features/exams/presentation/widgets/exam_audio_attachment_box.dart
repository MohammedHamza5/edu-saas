import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/services/exam_audio_upload_service.dart';
import '../../data/services/voice_recording_service.dart';
import 'question_audio_player.dart';

/// Question audio explanation attachment box supporting WhatsApp-style live recording,
/// local preview before upload, file picking, and cloud storage upload.
class ExamAudioAttachmentBox extends StatefulWidget {
  final String? initialAudioUrl;
  final int? initialDurationSeconds;
  final ValueChanged<({String? audioUrl, int? durationSeconds})> onChanged;
  final ValueChanged<bool>? onUploadingChanged;

  const ExamAudioAttachmentBox({
    super.key,
    this.initialAudioUrl,
    this.initialDurationSeconds,
    required this.onChanged,
    this.onUploadingChanged,
  });

  @override
  State<ExamAudioAttachmentBox> createState() => _ExamAudioAttachmentBoxState();
}

class _ExamAudioAttachmentBoxState extends State<ExamAudioAttachmentBox>
    with SingleTickerProviderStateMixin {
  String? _audioUrl;
  int? _durationSeconds;
  bool _isUploading = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  VoiceRecordingResult? _recordedPreview;

  final _uploadService = ExamAudioUploadService();
  final _recordingService = VoiceRecordingService();

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  StreamSubscription<int>? _durationSub;

  @override
  void initState() {
    super.initState();
    _audioUrl = widget.initialAudioUrl;
    _durationSeconds = widget.initialDurationSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _durationSub = _recordingService.durationStream.listen((sec) {
      if (!mounted) return;
      setState(() => _recordingSeconds = sec);
    });
  }

  @override
  void didUpdateWidget(covariant ExamAudioAttachmentBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialAudioUrl != oldWidget.initialAudioUrl) {
      _audioUrl = widget.initialAudioUrl;
    }
    if (widget.initialDurationSeconds != oldWidget.initialDurationSeconds) {
      _durationSeconds = widget.initialDurationSeconds;
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _pulseController.dispose();
    _recordingService.dispose();
    super.dispose();
  }

  void _setUploading(bool value) {
    if (!mounted) return;
    setState(() => _isUploading = value);
    widget.onUploadingChanged?.call(value);
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    final l10n = context.l10n;
    try {
      final permitted = await _recordingService.hasPermission();
      if (!permitted) {
        if (mounted) {
          AppFeedback.showError(context, l10n.micPermissionDenied);
        }
        return;
      }

      await _recordingService.start();
      _pulseController.repeat(reverse: true);
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _recordedPreview = null;
        _audioUrl = null;
        _isUploading = false;
      });
      widget.onUploadingChanged?.call(false);
    } catch (e, stack) {
      AppLogger.e('ExamAudioAttachmentBox', 'Failed to start recording', error: e, stackTrace: stack);
      if (mounted) {
        AppFeedback.showError(context, l10n.audioError);
      }
    }
  }

  Future<void> _stopRecordingAndPreview() async {
    final l10n = context.l10n;
    try {
      final result = await _recordingService.stop();
      _pulseController.stop();
      if (result == null || result.bytes.isEmpty) {
        setState(() => _isRecording = false);
        return;
      }

      setState(() {
        _isRecording = false;
        _recordedPreview = result;
        _durationSeconds = result.durationSeconds;
        _isUploading = true;
      });
      _setUploading(true);
      unawaited(_uploadRecordingInBackground(result));

    } catch (e, stack) {
      _pulseController.stop();
      AppLogger.e('ExamAudioAttachmentBox', 'Failed to stop recording', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isUploading = false;
        });
        _setUploading(false);
        AppFeedback.showError(context, l10n.audioError);
      }
    }
  }

  Future<void> _uploadRecordingInBackground(VoiceRecordingResult result) async {
    try {
      final mimeType = result.fileName.endsWith('.webm') ? 'audio/webm' : 'audio/mp4';
      final uploadedUrl = await _uploadService.uploadAudio(
        bytes: result.bytes,
        fileName: result.fileName,
        mimeType: mimeType,
      );

      if (!mounted) return;

      // If user discarded or removed audio while uploading, do not restore
      if (_recordedPreview == null && _audioUrl == null) {
        _setUploading(false);
        return;
      }

      setState(() {
        _audioUrl = uploadedUrl;
        _durationSeconds = result.durationSeconds;
        _isUploading = false;
      });
      _setUploading(false);

      widget.onChanged((
        audioUrl: _audioUrl,
        durationSeconds: _durationSeconds,
      ));
    } catch (e, stack) {
      AppLogger.e('ExamAudioAttachmentBox', 'Failed to upload voice recording in background', error: e, stackTrace: stack);
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        _setUploading(false);
        AppFeedback.showError(context, context.l10n.audioError);
      }
    }
  }

  Future<void> _cancelRecording() async {
    await _recordingService.cancel();
    _pulseController.stop();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  Future<void> _reRecord() async {
    setState(() {
      _audioUrl = null;
      _durationSeconds = null;
      _recordedPreview = null;
      _isUploading = false;
    });
    _setUploading(false);
    widget.onChanged((
      audioUrl: null,
      durationSeconds: null,
    ));
    await _startRecording();
  }

  Future<void> _pickAndUploadAudio() async {
    final l10n = context.l10n;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m4a', 'mp3', 'aac', 'wav', 'ogg', 'webm'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) return;

      if (bytes.lengthInBytes > 20 * 1024 * 1024) {
        if (mounted) {
          AppFeedback.showError(context, l10n.audioFileTooLarge);
        }
        return;
      }

      _setUploading(true);

      final mimeType = _getMimeType(file.extension ?? '');
      final uploadedUrl = await _uploadService.uploadAudio(
        bytes: bytes,
        fileName: file.name,
        mimeType: mimeType,
      );

      if (!mounted) return;

      setState(() {
        _audioUrl = uploadedUrl;
      });
      _setUploading(false);

      widget.onChanged((
        audioUrl: _audioUrl,
        durationSeconds: _durationSeconds,
      ));
    } catch (e, stack) {
      AppLogger.e(
        'ExamAudioAttachmentBox',
        'Failed to upload audio',
        error: e,
        stackTrace: stack,
      );
      if (mounted) {
        _setUploading(false);
        AppFeedback.showError(context, l10n.audioError);
      }
    }
  }

  void _removeAudio() {
    setState(() {
      _audioUrl = null;
      _durationSeconds = null;
      _recordedPreview = null;
      _isUploading = false;
    });
    _setUploading(false);
    widget.onChanged((
      audioUrl: null,
      durationSeconds: null,
    ));
  }

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'webm':
        return 'audio/webm';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
      default:
        return 'audio/mp4';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasAudio = (_audioUrl != null && _audioUrl!.trim().isNotEmpty) || _recordedPreview != null;

    // 1. Uploading state (only when uploading a picked file without any audio/preview ready)
    if (_isUploading && !hasAudio) {
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.s8),
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.s12),
            Text(
              l10n.uploadingAudio,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // 2. Active recording state (WhatsApp live bar)
    if (_isRecording) {
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.s8),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            // Pulsing recording indicator
            FadeTransition(
              opacity: _pulseAnimation,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            // Recording timer
            Text(
              _formatDuration(_recordingSeconds),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Text(
                l10n.recordingVoice,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.error.withValues(alpha: 0.8),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Cancel button
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
              tooltip: l10n.cancelRecording,
              onPressed: _cancelRecording,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.s4),
            // Stop and preview button (WhatsApp-style instant transition)
            FilledButton.icon(
              onPressed: _stopRecordingAndPreview,
              icon: const Icon(Icons.stop_rounded, size: 16),
              label: Text(l10n.stopAndPreview),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              ),
            ),
          ],
        ),
      );
    }

    // 3. Audio present (Instant playback from local memory or cloud CDN + non-blocking background sync)
    if (hasAudio) {
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.s8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QuestionAudioPlayer(
              audioUrl: _audioUrl ?? _recordedPreview?.previewPathOrUrl,
              initialDurationSeconds: _durationSeconds ?? _recordedPreview?.durationSeconds,
              localBytes: _recordedPreview?.bytes,
              isUploading: _isUploading,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _reRecord,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(l10n.reRecord),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                TextButton.icon(
                  onPressed: _pickAndUploadAudio,
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: Text(l10n.uploadAudioFile),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                TextButton.icon(
                  onPressed: _removeAudio,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: Text(l10n.removeAudio),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 5. Idle state: WhatsApp voice record + File upload buttons
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s8),
      child: Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          // Direct live record button
          FilledButton.icon(
            onPressed: _startRecording,
            icon: const Icon(Icons.mic_rounded, size: 18),
            label: Text(l10n.recordVoice),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
            ),
          ),
          // Upload file button
          OutlinedButton.icon(
            onPressed: _pickAndUploadAudio,
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: Text(l10n.uploadAudioFile),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
