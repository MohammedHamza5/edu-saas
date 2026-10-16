import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'desmos_embed_view.dart';

@JS('createDesmosCalculator')
external JSObject _createDesmosCalculator(
  JSString src,
  JSString viewId,
);

Widget buildPlatformDesmosEmbed({
  required DesmosCalculatorMode mode,
  Key? key,
}) {
  return _DesmosEmbedWeb(key: key, mode: mode);
}

class _DesmosEmbedWeb extends StatefulWidget {
  final DesmosCalculatorMode mode;

  const _DesmosEmbedWeb({super.key, required this.mode});

  @override
  State<_DesmosEmbedWeb> createState() => _DesmosEmbedWebState();
}

class _DesmosEmbedWebState extends State<_DesmosEmbedWeb> {
  late final String _viewId;
  late final String _viewType;

  String _getUrlForMode(DesmosCalculatorMode mode) {
    switch (mode) {
      case DesmosCalculatorMode.graphing:
        return 'https://www.desmos.com/testing/collegeboard/graphing';
      case DesmosCalculatorMode.scientific:
        return 'https://www.desmos.com/testing/collegeboard/scientific';
    }
  }

  @override
  void initState() {
    super.initState();
    _viewId = 'desmos_${widget.mode.name}';
    _viewType = 'desmos-view-${widget.mode.name}';

    final url = _getUrlForMode(widget.mode);
    try {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
        return _createDesmosCalculator(url.toJS, _viewId.toJS);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
