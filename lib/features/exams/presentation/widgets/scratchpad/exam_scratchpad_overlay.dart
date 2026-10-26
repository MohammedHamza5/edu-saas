import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:edu_saas/features/exams/domain/entities/scratchpad_entity.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_state.dart';
import 'scratchpad_painter.dart';
import 'scratchpad_toolbar.dart';

/// Full interactive canvas overlay allowing students to scratch and solve equations.
class ExamScratchpadOverlay extends StatefulWidget {
  const ExamScratchpadOverlay({super.key});

  @override
  State<ExamScratchpadOverlay> createState() => _ExamScratchpadOverlayState();
}

class _ExamScratchpadOverlayState extends State<ExamScratchpadOverlay> {
  DrawingStroke? _currentStroke;

  double _getStrokeWidth(DrawingTool tool) {
    switch (tool) {
      case DrawingTool.pen:
        return 2.5;
      case DrawingTool.highlighter:
        return 16.0;
      case DrawingTool.eraser:
        return 22.0;
    }
  }

  void _onPanStart(DragStartDetails details, ExamTakingState state) {
    final point = DrawingPoint(offset: details.localPosition);
    setState(() {
      _currentStroke = DrawingStroke(
        points: [point],
        tool: state.activeDrawingTool,
        color: state.activeDrawingColor,
        strokeWidth: _getStrokeWidth(state.activeDrawingTool),
        opacity: state.activeDrawingTool == DrawingTool.highlighter ? 0.38 : 1.0,
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke == null) return;
    final point = DrawingPoint(offset: details.localPosition);
    setState(() {
      _currentStroke = _currentStroke!.copyWith(
        points: [..._currentStroke!.points, point],
      );
    });
  }

  void _onPanEnd(DragEndDetails details, BuildContext context) {
    if (_currentStroke != null) {
      context.read<ExamsCubit>().addStrokeToCurrentQuestion(_currentStroke!);
      setState(() {
        _currentStroke = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExamsCubit, ExamsState>(
      builder: (context, state) {
        if (state is! ExamTakingState || !state.isScratchpadOpen) {
          return const SizedBox.shrink();
        }

        final strokes = state.currentQuestionStrokes;
        final cubit = context.read<ExamsCubit>();

        return Positioned.fill(
          child: Stack(
            children: [
              // Canvas area
              Container(
                color: state.isScratchpadGridBackground
                    ? const Color(0xFFF8FAFC)
                    : Colors.white.withValues(alpha: 0.12),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (d) => _onPanStart(d, state),
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: (d) => _onPanEnd(d, context),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: ScratchpadPainter(
                        strokes: strokes,
                        currentStroke: _currentStroke,
                        isGridBackground: state.isScratchpadGridBackground,
                      ),
                    ),
                  ),
                ),
              ),

              // Floating top toolbar
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
                    child: ScratchpadToolbar(
                      activeTool: state.activeDrawingTool,
                      activeColor: state.activeDrawingColor,
                      isGridBackground: state.isScratchpadGridBackground,
                      canUndo: strokes.isNotEmpty,
                      onToolChanged: cubit.setDrawingTool,
                      onColorChanged: cubit.setDrawingColor,
                      onToggleBackground: cubit.toggleScratchpadBackground,
                      onUndo: cubit.undoLastStroke,
                      onClear: cubit.clearCurrentQuestionScratchpad,
                      onClose: cubit.toggleScratchpad,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
