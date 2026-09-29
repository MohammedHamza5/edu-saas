import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class InteractiveLightboxDialog extends StatefulWidget {
  final String imageUrl;
  final String? title;

  const InteractiveLightboxDialog({
    super.key,
    required this.imageUrl,
    this.title,
  });

  static Future<void> show(BuildContext context, {required String imageUrl, String? title}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => InteractiveLightboxDialog(
        imageUrl: imageUrl,
        title: title,
      ),
    );
  }

  @override
  State<InteractiveLightboxDialog> createState() => _InteractiveLightboxDialogState();
}

class _InteractiveLightboxDialogState extends State<InteractiveLightboxDialog> {
  final TransformationController _transformationController = TransformationController();

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _resetZoom();
    } else {
      _transformationController.value = Matrix4.identity()..scale(2.5, 2.5);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Zoomable Image Viewer ──────────────────────────────────────────
          GestureDetector(
            onDoubleTap: _handleDoubleTap,
            child: Center(
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.8,
                maxScale: 6.0,
                child: CachedNetworkImage(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (ctx, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (ctx, _, __) => const Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.white70, size: 48),
                  ),
                ),
              ),
            ),
          ),

          // ── Top Bar: Title, Reset Zoom & Close ──────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                if (widget.title != null)
                  Expanded(
                    child: Text(
                      widget.title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'إعادة ضبط التكبير',
                  onPressed: _resetZoom,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
