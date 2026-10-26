import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'formula_reference_cards.dart';

/// Modal dialog/sheet providing official SAT Reference Sheet and Desmos Hacks.
class ExamFormulaSheetModal extends StatelessWidget {
  const ExamFormulaSheetModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ExamFormulaSheetModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLarge)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      l10n.formulaSheetTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            TabBar(
              labelColor: AppColors.primary,
              indicatorColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: [
                Tab(icon: const Icon(Icons.square_foot_outlined), text: l10n.formulaGeometryTab),
                Tab(icon: const Icon(Icons.calculate_outlined), text: l10n.formulaDesmosTab),
              ],
            ),

            Expanded(
              child: TabBarView(
                children: [
                  _buildSatGeometryTab(context),
                  _buildDesmosHacksTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSatGeometryTab(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        const FormulaCard(
          title: 'Circles (الدائرة)',
          formulas: ['A = π r²', 'C = 2 π r'],
          icon: Icons.circle_outlined,
        ),
        const FormulaCard(
          title: 'Triangles & Rectangles (المثلثات والمستطيلات)',
          formulas: ['A = ℓ w', 'A = ½ b h', 'c² = a² + b² (Pythagorean)'],
          icon: Icons.change_history_outlined,
        ),
        const FormulaCard(
          title: 'Special Right Triangles (المثلثات الخاصة)',
          formulas: [
            '30°-60°-90°: Sides in ratio x : x√3 : 2x',
            '45°-45°-90°: Sides in ratio s : s : s√2',
          ],
          icon: Icons.details_outlined,
        ),
        const FormulaCard(
          title: '3D Solids Volume (حجوم المجسمات)',
          formulas: [
            'Rectangular Prism: V = ℓ w h',
            'Cylinder: V = π r² h',
            'Sphere: V = ⁴⁄₃ π r³',
            'Cone: V = ⅓ π r² h',
            'Pyramid: V = ⅓ ℓ w h',
          ],
          icon: Icons.view_in_ar_outlined,
        ),
        ReferenceFactCard(text: l10n.formulaTriangleSum),
        ReferenceFactCard(text: l10n.formulaCircleDegrees),
        ReferenceFactCard(text: l10n.formulaCircleRadians),
      ],
    );
  }

  Widget _buildDesmosHacksTab(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        DesmosHackCard(title: '⚡ Linear Regression', description: l10n.desmosRegressionTip),
        DesmosHackCard(title: '🎯 System Intersections', description: l10n.desmosIntersectionTip),
        DesmosHackCard(title: '⛰️ Quadratic Vertex', description: l10n.desmosVertexTip),
        DesmosHackCard(title: '🎛️ Sliders for Constants', description: l10n.desmosSlidersTip),
      ],
    );
  }
}
