import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/content_cubit.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';

/// Bottom sheet / dialog displaying deep, 100% real Supabase analytics for a specific chapter.
class ChapterAnalyticsSheet extends StatefulWidget {
  final String groupId;
  final ChapterEntity chapter;
  final List<ContentEntity> chapterLessons;

  const ChapterAnalyticsSheet({
    super.key,
    required this.groupId,
    required this.chapter,
    required this.chapterLessons,
  });

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required ChapterEntity chapter,
    required List<ContentEntity> chapterLessons,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
            child: ChapterAnalyticsSheet(
              groupId: groupId,
              chapter: chapter,
              chapterLessons: chapterLessons,
            ),
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (ctx, scrollController) => ChapterAnalyticsSheet(
            groupId: groupId,
            chapter: chapter,
            chapterLessons: chapterLessons,
          ),
        ),
      );
    }
  }

  @override
  State<ChapterAnalyticsSheet> createState() => _ChapterAnalyticsSheetState();
}

class _ChapterAnalyticsSheetState extends State<ChapterAnalyticsSheet> {
  bool _isLoading = true;
  String? _errorMessage;

  // Real Analytics Metrics
  int _totalActiveStudents = 0;
  int _totalVideoViews = 0;
  int _completedStudentsCount = 0;
  int _inProgressStudentsCount = 0;
  int _notStartedStudentsCount = 0;
  double? _averageQuizScore;

  @override
  void initState() {
    super.initState();
    _loadChapterAnalytics();
  }

  Future<void> _loadChapterAnalytics() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final lessonIds = widget.chapterLessons.map((l) => l.id).toList();
      final examIds = widget.chapterLessons
          .expand((l) => [
                if (l.associatedExamId != null) l.associatedExamId!,
                ...l.attachedExams.map((e) => e.examId),
              ])
          .toSet()
          .toList();

      final analytics = await context.read<ContentCubit>().getChapterAnalytics(
        groupId: widget.groupId,
        lessonIds: lessonIds,
        examIds: examIds,
      );

      if (mounted && analytics != null) {
        setState(() {
          _totalActiveStudents = analytics.totalStudents;
          _totalVideoViews = analytics.totalViews;
          _completedStudentsCount = analytics.completedCount;
          _inProgressStudentsCount = analytics.inProgressCount;
          _notStartedStudentsCount = analytics.notStartedCount;
          _averageQuizScore = analytics.averageScore;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

    @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLarge),
              ),
              border: const Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.chapterAnalyticsDialogTitle(widget.chapter.title),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.chapterLessonsCountLabel(widget.chapterLessons.length),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textSecondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Body Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: AppLoadingView.cardsGrid(count: 2, columns: 2),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.s24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 40,
                                color: AppColors.error,
                              ),
                              const SizedBox(height: AppSpacing.s12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s16),
                              OutlinedButton.icon(
                                onPressed: _loadChapterAnalytics,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: Text(l10n.retry),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.s20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Key Metrics Grid
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isCompact = constraints.maxWidth < 460;
                                return GridView.count(
                                  crossAxisCount: isCompact ? 2 : 4,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: AppSpacing.s12,
                                  mainAxisSpacing: AppSpacing.s12,
                                  childAspectRatio: isCompact ? 1.3 : 1.15,
                                  children: [
                                    _buildMetricCard(
                                      title: l10n.activeStudentsCount,
                                      value: '$_totalActiveStudents',
                                      icon: Icons.people_alt_rounded,
                                      color: AppColors.primary,
                                    ),
                                    _buildMetricCard(
                                      title: l10n.totalChapterViews,
                                      value: '$_totalVideoViews',
                                      icon: Icons.play_circle_fill_rounded,
                                      color: const Color(0xFF0284C7),
                                    ),
                                    _buildMetricCard(
                                      title: l10n.chapterCompletionRate,
                                      value: _totalActiveStudents > 0
                                          ? '${((_completedStudentsCount / _totalActiveStudents) * 100).toStringAsFixed(0)}%'
                                          : '0%',
                                      icon: Icons.task_alt_rounded,
                                      color: AppColors.success,
                                    ),
                                    _buildMetricCard(
                                      title: l10n.averageChapterQuizScore,
                                      value: _averageQuizScore != null
                                          ? '${_averageQuizScore!.toStringAsFixed(0)}%'
                                          : '--',
                                      icon: Icons.quiz_rounded,
                                      color: const Color(0xFFD97706),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: AppSpacing.s20),

                            // Student Progress Distribution Card
                            AppCard(
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.pie_chart_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: AppSpacing.s8),
                                      Text(
                                        l10n.studentProgressDistribution,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.s16),

                                  // Distribution Bar
                                  _buildDistributionBar(),

                                  const SizedBox(height: AppSpacing.s16),

                                  // Legend
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildLegendItem(
                                        label: l10n.completedAllChapterLessons,
                                        count: _completedStudentsCount,
                                        color: AppColors.success,
                                      ),
                                      _buildLegendItem(
                                        label: l10n.inProgressChapterLessons,
                                        count: _inProgressStudentsCount,
                                        color: const Color(0xFF0284C7),
                                      ),
                                      _buildLegendItem(
                                        label: l10n.notStartedChapterLessons,
                                        count: _notStartedStudentsCount,
                                        color: AppColors.textMuted,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionBar() {
    final total = _totalActiveStudents > 0 ? _totalActiveStudents : 1;
    final compFlex = (_completedStudentsCount * 100 ~/ total).clamp(0, 100);
    final progFlex = (_inProgressStudentsCount * 100 ~/ total).clamp(0, 100);
    final notStartFlex = (100 - compFlex - progFlex).clamp(0, 100);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 14,
        color: AppColors.surfaceVariant,
        child: Row(
          children: [
            if (compFlex > 0)
              Expanded(
                flex: compFlex,
                child: Container(color: AppColors.success),
              ),
            if (progFlex > 0)
              Expanded(
                flex: progFlex,
                child: Container(color: const Color(0xFF0284C7)),
              ),
            if (notStartFlex > 0)
              Expanded(
                flex: notStartFlex,
                child: Container(color: AppColors.textMuted.withValues(alpha: 0.4)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: $count',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
