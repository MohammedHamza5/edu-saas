import 'package:flutter/material.dart';
import '../desmos_embed_view.dart';
import 'exam_dock_state.dart';
import 'exam_utility_dock.dart';

/// Container that hosts the [ExamUtilityDock], supporting seamless transitions
/// between docked side pane, movable floating window, and hidden (offstage) state
/// without ever unmounting or resetting the Desmos Web DOM iframe.
class ExamAdaptiveToolsPane extends StatefulWidget {
  final ExamDockMode dockMode;
  final ExamDockTab activeTab;
  final DesmosCalculatorMode desmosMode;
  final ValueChanged<ExamDockMode> onDockModeChanged;
  final ValueChanged<ExamDockTab> onTabChanged;
  final ValueChanged<DesmosCalculatorMode> onDesmosModeChanged;
  final double dockWidth;
  final bool isDesktop;
  final Size parentSize;

  const ExamAdaptiveToolsPane({
    super.key,
    required this.dockMode,
    required this.activeTab,
    required this.desmosMode,
    required this.onDockModeChanged,
    required this.onTabChanged,
    required this.onDesmosModeChanged,
    required this.dockWidth,
    required this.isDesktop,
    required this.parentSize,
  });

  @override
  State<ExamAdaptiveToolsPane> createState() => _ExamAdaptiveToolsPaneState();
}

class _ExamAdaptiveToolsPaneState extends State<ExamAdaptiveToolsPane> {
  Offset? _floatPosition;
  bool _isMaximized = false;

  @override
  Widget build(BuildContext context) {
    if (widget.dockMode.isDocked && widget.isDesktop) {
      return Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: widget.dockWidth,
        child: ExamUtilityDock(
          activeTab: widget.activeTab,
          onTabChanged: widget.onTabChanged,
          desmosMode: widget.desmosMode,
          onDesmosModeChanged: widget.onDesmosModeChanged,
          onCollapse: () => widget.onDockModeChanged(ExamDockMode.hidden),
          onDetachToFloat: () => widget.onDockModeChanged(ExamDockMode.floating),
          isDetachSupported: widget.isDesktop,
          isFloating: false,
        ),
      );
    }

    if (widget.dockMode.isFloating) {
      final defaultW = (widget.parentSize.width * 0.44).clamp(360.0, 520.0);
      final defaultH = (widget.parentSize.height * 0.60).clamp(400.0, 620.0);
      final defaultX = widget.parentSize.width - defaultW - 20.0;
      final defaultY = (widget.parentSize.height - defaultH - 50.0).clamp(10.0, double.infinity);

      final effectivePos = _floatPosition ?? Offset(defaultX, defaultY);
      final maxPosX = (widget.parentSize.width - 120.0).clamp(0.0, double.infinity);
      final maxPosY = (widget.parentSize.height - 80.0).clamp(0.0, double.infinity);

      return Positioned(
        left: _isMaximized ? 12 : effectivePos.dx.clamp(0.0, maxPosX),
        top: _isMaximized ? 12 : effectivePos.dy.clamp(0.0, maxPosY),
        width: _isMaximized ? (widget.parentSize.width - 24) : defaultW,
        height: _isMaximized ? (widget.parentSize.height - 24) : defaultH,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Colors.transparent,
          child: ExamUtilityDock(
            activeTab: widget.activeTab,
            onTabChanged: widget.onTabChanged,
            desmosMode: widget.desmosMode,
            onDesmosModeChanged: widget.onDesmosModeChanged,
            onCollapse: () => widget.onDockModeChanged(ExamDockMode.hidden),
            onDetachToFloat: () {},
            isDetachSupported: false,
            isFloating: true,
            isMaximized: _isMaximized,
            onToggleMaximize: () => setState(() => _isMaximized = !_isMaximized),
            onReDock: widget.isDesktop ? () => widget.onDockModeChanged(ExamDockMode.docked) : null,
            onDragUpdate: (details) {
              setState(() {
                final cur = _floatPosition ?? Offset(defaultX, defaultY);
                _floatPosition = Offset(cur.dx + details.delta.dx, cur.dy + details.delta.dy);
              });
            },
          ),
        ),
      );
    }

    // Hidden State: Keep DOM mounted Offstage with 0 visual footprint
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 0,
      child: Offstage(
        offstage: true,
        child: SizedBox(
          width: widget.dockWidth,
          child: ExamUtilityDock(
            activeTab: widget.activeTab,
            onTabChanged: widget.onTabChanged,
            desmosMode: widget.desmosMode,
            onDesmosModeChanged: widget.onDesmosModeChanged,
            onCollapse: () => widget.onDockModeChanged(ExamDockMode.hidden),
            onDetachToFloat: () => widget.onDockModeChanged(ExamDockMode.floating),
            isDetachSupported: widget.isDesktop,
            isFloating: false,
          ),
        ),
      ),
    );
  }
}
