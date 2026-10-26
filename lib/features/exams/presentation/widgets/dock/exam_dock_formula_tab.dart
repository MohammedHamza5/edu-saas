import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../formula_reference_cards.dart';

/// Embedded Formula Reference pane designed for the SAT Utility Dock.
/// Displays official SAT Geometry formulas & proven Desmos shortcuts side-by-side with questions.
class ExamDockFormulaTab extends StatelessWidget {
  const ExamDockFormulaTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Sub-tabs: Geometry vs Desmos Hacks
          Container(
            color: AppColors.surface,
            child: TabBar(
              labelColor: AppColors.primary,
              indicatorColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              tabs: [
                Tab(icon: const Icon(Icons.square_foot_outlined, size: 16), text: l10n.formulaGeometryTab),
                Tab(icon: const Icon(Icons.lightbulb_outline_rounded, size: 16), text: l10n.formulaDesmosTab),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Scrollable Formula Content
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
    );
  }

  Widget _buildSatGeometryTab(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s12),
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
      padding: const EdgeInsets.all(AppSpacing.s12),
      children: [
        DesmosHackCard(title: '⚡ Linear Regression', description: l10n.desmosRegressionTip),
        DesmosHackCard(title: '🎯 System Intersections', description: l10n.desmosIntersectionTip),
        DesmosHackCard(title: '⛰️ Quadratic Vertex', description: l10n.desmosVertexTip),
        DesmosHackCard(title: '🎛️ Sliders for Constants', description: l10n.desmosSlidersTip),
      ],
    );
  }
}
