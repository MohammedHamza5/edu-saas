import 'package:flutter/material.dart';
import 'desmos_embed_view_stub.dart'
    if (dart.library.js_interop) 'desmos_embed_view_web.dart';

enum DesmosCalculatorMode {
  graphing,
  scientific,
}

Widget buildDesmosCalculatorEmbed({
  required DesmosCalculatorMode mode,
  Key? key,
}) {
  return buildPlatformDesmosEmbed(mode: mode, key: key);
}
