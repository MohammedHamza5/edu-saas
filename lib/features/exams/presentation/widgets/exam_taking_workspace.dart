import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/exams_state.dart';
import 'desmos_embed_view.dart';
import 'dock/exam_adaptive_tools_pane.dart';
import 'dock/exam_dock_state.dart';
import 'exam_taking_pdf_booklet.dart';
import 'exam_taking_questions_view.dart';

/// Workspace viewport for the active exam taking session.
/// Coordinates the responsive questions view, split PDF pane (desktop),
/// mobile PDF overlay, and collapsible/draggable adaptive math tools dock.
class ExamTakingWorkspace extends StatelessWidget {
  final ExamTakingState state;
  final ExamDockMode dockMode;
  final ExamDockTab dockTab;
  final DesmosCalculatorMode desmosMode;
  final bool hasOpenedToolsEver;
  final bool showDesktopPdfPane;
  final bool showMobilePdfOverlay;
  final double? customDockWidth;
  final bool isDraggingDockSplitter;

  // Viewport / Dock callbacks
  final ValueChanged<ExamDockMode> onDockModeChanged;
  final ValueChanged<ExamDockTab> onDockTabChanged;
  final ValueChanged<DesmosCalculatorMode> onDesmosModeChanged;
  final ValueChanged<bool> onToggleDesktopPdfPane;
  final VoidCallback onCloseMobilePdfOverlay;
  final VoidCallback onOpenPdfBooklet;
  final ValueChanged<double> onCustomDockWidthChanged;
  final ValueChanged<bool> onDraggingDockSplitterChanged;

  // Question action callbacks
  final VoidCallback onToggleFlagGuess;
  final VoidCallback onToggleVault;
  final ValueChanged<String> onSelectOption;
  final ValueChanged<String> onToggleEliminateOption;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onReviewGrid;
  final VoidCallback onSubmit;

  const ExamTakingWorkspace({
    super.key,
    required this.state,
    required this.dockMode,
    required this.dockTab,
    required this.desmosMode,
    required this.hasOpenedToolsEver,
    required this.showDesktopPdfPane,
    required this.showMobilePdfOverlay,
    required this.customDockWidth,
    required this.isDraggingDockSplitter,
    required this.onDockModeChanged,
    required this.onDockTabChanged,
    required this.onDesmosModeChanged,
    required this.onToggleDesktopPdfPane,
    required this.onCloseMobilePdfOverlay,
    required this.onOpenPdfBooklet,
    required this.onCustomDockWidthChanged,
    required this.onDraggingDockSplitterChanged,
    required this.onToggleFlagGuess,
    required this.onToggleVault,
    required this.onSelectOption,
    required this.onToggleEliminateOption,
    required this.onPrevious,
    required this.onNext,
    required this.onReviewGrid,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final qIndex = state.currentQuestionIndex;
    final question = state.currentQuestion;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final defaultDockWidth =
            (constraints.maxWidth * 0.38).clamp(380.0, 560.0);
        const minDockWidth = 320.0;
        final maxDockWidth = constraints.maxWidth * 0.65;
        final dockWidth = (customDockWidth ?? defaultDockWidth)
            .clamp(minDockWidth, maxDockWidth);
        final isDocked = isDesktop && dockMode.isDocked;
        final rightPadding = isDocked ? dockWidth : 0.0;

        Widget questionsView = ExamTakingQuestionsView(
          state: state,
          questionIndex: qIndex,
          question: question,
          isDesktop: isDesktop,
          showDesktopPdfPane: showDesktopPdfPane,
          onOpenPdfBooklet: onOpenPdfBooklet,
          onToggleFlagGuess: onToggleFlagGuess,
          onToggleVault: onToggleVault,
          onSelectOption: onSelectOption,
          onToggleEliminateOption: onToggleEliminateOption,
          onPrevious: onPrevious,
          onNext: onNext,
          onReviewGrid: onReviewGrid,
          onSubmit: onSubmit,
        );

        Widget mainContent;
        if (isDesktop && state.exam.hasAttachedPdf && showDesktopPdfPane) {
          mainContent = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 52,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                        vertical: AppSpacing.s8,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              state.exam.pdfFileName ?? state.exam.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_fullscreen_rounded,
                              size: 18,
                            ),
                            tooltip: context.l10n.hideExamBooklet,
                            onPressed: () => onToggleDesktopPdfPane(false),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ExamTakingPdfBooklet(
                        exam: state.exam,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, color: AppColors.border),
              Expanded(
                flex: 48,
                child: questionsView,
              ),
            ],
          );
        } else {
          mainContent = Stack(
            fit: StackFit.expand,
            children: [
              questionsView,
              if (!isDesktop &&
                  state.exam.hasAttachedPdf &&
                  showMobilePdfOverlay)
                ExamTakingPdfBooklet(
                  exam: state.exam,
                  isMobileOverlay: true,
                  currentQuestionIndex: qIndex,
                  totalQuestions: state.totalQuestions,
                  onCloseMobileOverlay: onCloseMobilePdfOverlay,
                ),
            ],
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: rightPadding,
              child: mainContent,
            ),
            if (hasOpenedToolsEver)
              ExamAdaptiveToolsPane(
                dockMode: dockMode,
                activeTab: dockTab,
                desmosMode: desmosMode,
                onDockModeChanged: onDockModeChanged,
                onTabChanged: onDockTabChanged,
                onDesmosModeChanged: onDesmosModeChanged,
                dockWidth: dockWidth,
                isDesktop: isDesktop,
                parentSize: Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                ),
              ),
            if (isDocked)
              Positioned(
                right: dockWidth - 6,
                top: 0,
                bottom: 0,
                width: 12,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: (_) =>
                        onDraggingDockSplitterChanged(true),
                    onHorizontalDragEnd: (_) =>
                        onDraggingDockSplitterChanged(false),
                    onHorizontalDragCancel: () =>
                        onDraggingDockSplitterChanged(false),
                    onHorizontalDragUpdate: (details) {
                      final cur = customDockWidth ?? defaultDockWidth;
                      final updated = (cur - details.delta.dx)
                          .clamp(minDockWidth, maxDockWidth);
                      onCustomDockWidthChanged(updated);
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: isDraggingDockSplitter ? 4 : 2,
                          decoration: BoxDecoration(
                            color: isDraggingDockSplitter
                                ? AppColors.primary
                                : AppColors.border.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
