import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import 'exam_taking_overlays.dart';

/// Custom AppBar for the Exam Taking experience containing the Bluebook test tools:
/// PDF Booklet toggle, Scratchpad, Formula Sheet, Desmos Calculator, Timer, Vault, and Review Grid.
class ExamTakingAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool hasAttachedPdf;
  final bool isPdfActive;
  final VoidCallback onTogglePdf;
  final bool isScratchpadOpen;
  final VoidCallback onToggleScratchpad;
  final bool isFormulaActive;
  final VoidCallback onToggleFormula;
  final bool isCalculatorActive;
  final VoidCallback onToggleCalculator;
  final bool isQuestionSaved;
  final bool isSubmitting;
  final VoidCallback onToggleVault;
  final VoidCallback onOpenReviewGrid;

  const ExamTakingAppBar({
    super.key,
    required this.title,
    required this.hasAttachedPdf,
    required this.isPdfActive,
    required this.onTogglePdf,
    required this.isScratchpadOpen,
    required this.onToggleScratchpad,
    required this.isFormulaActive,
    required this.onToggleFormula,
    required this.isCalculatorActive,
    required this.onToggleCalculator,
    required this.isQuestionSaved,
    required this.isSubmitting,
    required this.onToggleVault,
    required this.onOpenReviewGrid,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: false,
      actions: [
        if (hasAttachedPdf)
          IconButton(
            icon: Icon(
              Icons.picture_as_pdf_rounded,
              color: isPdfActive ? AppColors.primary : null,
            ),
            tooltip: context.l10n.viewExamBooklet,
            onPressed: onTogglePdf,
          ),
        // Digital Scratchpad Canvas Toggle
        IconButton(
          icon: Icon(
            Icons.edit_outlined,
            color: isScratchpadOpen ? AppColors.primary : null,
          ),
          tooltip: context.l10n.scratchpadTooltip,
          onPressed: onToggleScratchpad,
        ),
        // SAT Reference Formulas Sheet & Desmos Hacks
        IconButton(
          icon: Icon(
            Icons.menu_book_rounded,
            color: isFormulaActive ? AppColors.primaryLight : null,
          ),
          tooltip: context.l10n.formulaSheetTooltip,
          onPressed: onToggleFormula,
        ),
        // Official SAT Desmos Calculator (Docked / Floating)
        IconButton(
          icon: Icon(
            Icons.calculate_rounded,
            color: isCalculatorActive ? AppColors.primaryLight : null,
          ),
          tooltip: context.l10n.calculatorTooltip,
          onPressed: onToggleCalculator,
        ),
        // Timer / Untimed badge
        const ExamTimerBadge(),
        // Bookmark question to vault
        IconButton(
          icon: Icon(
            isQuestionSaved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: isQuestionSaved ? AppColors.warning : null,
          ),
          tooltip: isQuestionSaved
              ? context.l10n.removeFromVault
              : context.l10n.saveToVault,
          onPressed: isSubmitting ? null : onToggleVault,
        ),
        // Bluebook Review Grid
        IconButton(
          icon: const Icon(Icons.grid_view_rounded),
          tooltip: context.l10n.bluebookReviewGrid,
          onPressed: isSubmitting ? null : onOpenReviewGrid,
        ),
      ],
    );
  }
}
