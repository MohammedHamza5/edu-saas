import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Available tools for the in-exam scratchpad.
enum DrawingTool {
  pen,
  highlighter,
  eraser,
}

/// A single coordinate point in a drawn stroke.
class DrawingPoint extends Equatable {
  final Offset offset;

  const DrawingPoint({required this.offset});

  @override
  List<Object?> get props => [offset.dx, offset.dy];
}

/// A complete drawn continuous stroke or line segment.
class DrawingStroke extends Equatable {
  final List<DrawingPoint> points;
  final DrawingTool tool;
  final Color color;
  final double strokeWidth;
  final double opacity;

  const DrawingStroke({
    required this.points,
    required this.tool,
    required this.color,
    required this.strokeWidth,
    this.opacity = 1.0,
  });

  DrawingStroke copyWith({
    List<DrawingPoint>? points,
    DrawingTool? tool,
    Color? color,
    double? strokeWidth,
    double? opacity,
  }) {
    return DrawingStroke(
      points: points ?? this.points,
      tool: tool ?? this.tool,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  List<Object?> get props => [points, tool, color.toARGB32(), strokeWidth, opacity];
}
