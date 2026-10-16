import 'package:flutter/material.dart';
import 'desmos_embed_view.dart';

Widget buildPlatformDesmosEmbed({
  required DesmosCalculatorMode mode,
  Key? key,
}) {
  return const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calculate_rounded, size: 48, color: Colors.grey),
        SizedBox(height: 12),
        Text(
          'Desmos Calculator is optimized for Web exam sessions.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    ),
  );
}
