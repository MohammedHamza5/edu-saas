import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

@JS('createPdfViewer')
external JSObject _createPdfViewer(
  JSString src,
  JSString viewId,
  JSString watermarkText,
  JSString docTitle,
);

Widget buildSecurePdfViewer({
  required String pdfUrl,
  String watermarkText = '',
  String docTitle = '',
}) {
  return _SecurePdfViewerWeb(
    pdfUrl: pdfUrl,
    watermarkText: watermarkText,
    docTitle: docTitle,
  );
}

class _SecurePdfViewerWeb extends StatefulWidget {
  final String pdfUrl;
  final String watermarkText;
  final String docTitle;

  const _SecurePdfViewerWeb({
    required this.pdfUrl,
    this.watermarkText = '',
    this.docTitle = '',
  });

  @override
  State<_SecurePdfViewerWeb> createState() => _SecurePdfViewerWebState();
}

class _SecurePdfViewerWebState extends State<_SecurePdfViewerWeb> {
  late final String _viewId;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewId = 'pdf_${DateTime.now().microsecondsSinceEpoch}';
    _viewType = 'secure-pdf-view-$_viewId';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      return _createPdfViewer(
        widget.pdfUrl.toJS,
        _viewId.toJS,
        widget.watermarkText.toJS,
        widget.docTitle.toJS,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
