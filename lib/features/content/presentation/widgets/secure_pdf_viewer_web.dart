import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

@JS('createPdfViewer')
external JSObject _createPdfViewer(JSString src, JSString viewId);

Widget buildSecurePdfViewer({required String pdfUrl}) {
  return _SecurePdfViewerWeb(pdfUrl: pdfUrl);
}

class _SecurePdfViewerWeb extends StatefulWidget {
  final String pdfUrl;

  const _SecurePdfViewerWeb({required this.pdfUrl});

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
      return _createPdfViewer(widget.pdfUrl.toJS, _viewId.toJS);
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
