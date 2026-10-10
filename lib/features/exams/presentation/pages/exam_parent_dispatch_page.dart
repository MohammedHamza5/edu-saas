import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/exam_parent_dispatch_entity.dart';
import '../cubit/exam_dispatch_cubit.dart';
import '../cubit/exam_dispatch_state.dart';
import '../widgets/exam_dispatch_student_card.dart';
import '../widgets/exam_whatsapp_dispatch_modal.dart';

class ExamParentDispatchPage extends StatefulWidget {
  final String examId;
  final String? initialExamTitle;

  const ExamParentDispatchPage({
    super.key,
    required this.examId,
    this.initialExamTitle,
  });

  @override
  State<ExamParentDispatchPage> createState() =>
      _ExamParentDispatchPageState();
}

class _ExamParentDispatchPageState extends State<ExamParentDispatchPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    context.read<ExamDispatchCubit>().loadRoster(widget.examId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSequentialDispatch(ExamDispatchLoaded state) {
    // Find first unnotified student, or fall back to first in filtered list
    final students = state.filteredStudents;
    if (students.isEmpty) return;

    final startIndex = students.indexWhere(
      (s) => !state.sentStudentIds.contains(s.studentId),
    );
    final targetIndex = startIndex != -1 ? startIndex : 0;
    _openDispatchModalForStudent(state, targetIndex);
  }

  void _openDispatchModalForStudent(ExamDispatchLoaded state, int index) {
    final students = state.filteredStudents;
    if (index < 0 || index >= students.length) return;

    final student = students[index];
    final hasNext = index + 1 < students.length;
    final nextStudent = hasNext ? students[index + 1] : null;
    final cubit = context.read<ExamDispatchCubit>();

    ExamWhatsAppDispatchModal.show(
      context: context,
      student: student,
      exam: state.roster.exam,
      onSent: () => cubit.markAsSent(student.studentId),
      onNext: hasNext
          ? () => _openDispatchModalForStudent(state, index + 1)
          : null,
      nextStudentName: nextStudent?.studentName,
      onUpdatePhone: (newPhone) => cubit.updateStudentParentPhone(
        studentId: student.studentId,
        newPhone: newPhone,
      ),
    );
  }

  void _showEditPhoneDialog(
    BuildContext context,
    String studentId,
    String studentName,
    String? currentPhone,
  ) {
    final controller = TextEditingController(text: currentPhone ?? '');
    final cubit = context.read<ExamDispatchCubit>();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.phone_outlined, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                context.l10n.editParentPhoneDialogTitle(studentName),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.editParentPhoneDialogBody,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.enterParentPhoneHint,
                prefixIcon: const Icon(Icons.phone_android_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPhone = controller.text.trim();
              final messenger = ScaffoldMessenger.of(context);
              final l10n = context.l10n;
              Navigator.of(dialogCtx).pop();
              final success = await cubit.updateStudentParentPhone(
                studentId: studentId,
                newPhone: newPhone,
              );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? l10n.parentPhoneSavedSuccess
                          : l10n.parentPhoneSaveFailed,
                    ),
                    backgroundColor:
                        success ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            child: Text(context.l10n.saveActionShort),
          ),
        ],
      ),
    );
  }

  void _copyRosterSummary(ExamDispatchLoaded state) {
    final exam = state.roster.exam;
    final stats = state.roster.stats;
    final buffer = StringBuffer();

    buffer.writeln('📊 كشف درجات اختبار: ${exam.title}');
    if (exam.primaryGroupName != null) {
      buffer.writeln('المجموعة: ${exam.primaryGroupName}');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('• إجمالي الطلاب: ${stats.totalAssignedStudents}');
    buffer.writeln('• عدد المسلمين: ${stats.submittedCount}');
    buffer.writeln('• متوسط الدرجات: ${stats.averageScore} من ${exam.maxScore} (${stats.averagePercentage}%)');
    buffer.writeln('• نسبة النجاح: ${stats.passRate.toStringAsFixed(1)}%');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');

    for (int i = 0; i < state.roster.students.length; i++) {
      final s = state.roster.students[i];
      final rank = i + 1;
      if (s.isSubmitted) {
        final scoreText = '${s.bestScore ?? 0}/${exam.maxScore} (${s.bestPercentage?.toStringAsFixed(1)}%)';
        final statusTag = s.isPassed ? '✅ ناجح' : '⚠️ راسب';
        buffer.writeln('$rank. ${s.studentName} — $scoreText — $statusTag');
      } else {
        buffer.writeln('$rank. ${s.studentName} — (لم يؤدِ الاختبار ⏳)');
      }
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('منصة التعليم - د. أنطونيوس أشرف');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.rosterCopiedToast),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.examParentDispatchHubTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          BlocBuilder<ExamDispatchCubit, ExamDispatchState>(
            builder: (context, state) {
              if (state is! ExamDispatchLoaded) return const SizedBox.shrink();

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Copy Roster Action
                  IconButton(
                    icon: const Icon(Icons.copy_all_rounded, size: 20),
                    tooltip: context.l10n.copyRosterSummaryTooltip,
                    onPressed: () => _copyRosterSummary(state),
                  ),

                  // Sequential Fast Runner Action
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF16A34A),
                    ),
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: Text(
                      context.l10n.sequentialDispatchActionShort,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () => _startSequentialDispatch(state),
                  ),

                  const SizedBox(width: AppSpacing.s8),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ExamDispatchCubit, ExamDispatchState>(
        builder: (context, state) {
          if (state is ExamDispatchLoading || state is ExamDispatchInitial) {
            return const AppLoadingView.list(count: 4);
          }

          if (state is ExamDispatchError) {
            return Center(
              child: AppErrorView(
                message: state.message,
                onRetry: () => context
                    .read<ExamDispatchCubit>()
                    .loadRoster(widget.examId),
              ),
            );
          }

          if (state is! ExamDispatchLoaded) {
            return const SizedBox.shrink();
          }

          final roster = state.roster;
          final exam = roster.exam;
          final stats = roster.stats;
          final filtered = state.filteredStudents;
          final cubit = context.read<ExamDispatchCubit>();

          return RefreshIndicator(
            onRefresh: () => cubit.loadRoster(widget.examId),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                // ── 1. Hero KPI Stats Header ──────────────────────────────
                _buildHeroStatsBanner(context, exam, stats, state),
                const SizedBox(height: AppSpacing.s16),

                // ── 2. Search & Filter Bar ────────────────────────────────
                _buildSearchAndFilters(context, cubit, state),
                const SizedBox(height: AppSpacing.s16),

                // ── 3. Students List or Empty State ───────────────────────
                if (filtered.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: AppEmptyView(
                        icon: Icons.person_search_rounded,
                        message: context.l10n.noMatchingStudentsFound,
                        actionText: context.l10n.clearSearchAction,
                        onAction: () {
                          _searchController.clear();
                          cubit.setSearchQuery('');
                          cubit.setFilter(ExamDispatchFilter.all);
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  // Results Count & Sort Header
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: Row(
                      children: [
                        Text(
                          context.l10n.studentsCountSummary(filtered.length),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        PopupMenuButton<ExamDispatchSort>(
                          initialValue: state.activeSort,
                          icon: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sort_rounded, size: 16, color: AppColors.primary),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
                            ],
                          ),
                          tooltip: context.l10n.sortOptionsTooltip,
                          onSelected: cubit.setSort,
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: ExamDispatchSort.highestScore,
                              child: Text(ctx.l10n.sortHighestScoreFirst),
                            ),
                            PopupMenuItem(
                              value: ExamDispatchSort.lowestScore,
                              child: Text(ctx.l10n.sortLowestScoreFirst),
                            ),
                            PopupMenuItem(
                              value: ExamDispatchSort.name,
                              child: Text(ctx.l10n.sortStudentNameAlphabetical),
                            ),
                            PopupMenuItem(
                              value: ExamDispatchSort.latestSubmitted,
                              child: Text(ctx.l10n.sortLatestSubmittedFirst),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Student Cards List
                  ...filtered.asMap().entries.map((entry) {
                    final index = entry.key;
                    final student = entry.value;
                    final isSent = state.sentStudentIds.contains(student.studentId);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                      child: ExamDispatchStudentCard(
                        student: student,
                        exam: exam,
                        index: index + 1,
                        isSent: isSent,
                        onTapDispatch: () => _openDispatchModalForStudent(state, index),
                        onEditPhone: () => _showEditPhoneDialog(
                          context,
                          student.studentId,
                          student.studentName,
                          student.parentPhone,
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroStatsBanner(
    BuildContext context,
    ExamDispatchMetaEntity exam,
    ExamDispatchStatsEntity stats,
    ExamDispatchLoaded state,
  ) {
    final notifiedCount = state.notifiedCount;
    final totalAssigned = stats.totalAssignedStudents;
    final submittedCount = stats.submittedCount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxStyle.subtle,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam Title & Groups Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${context.l10n.scorePoints(exam.maxScore)}${exam.passingScore != null ? ' • ${context.l10n.passingScoreLabel}: ${exam.passingScore}%' : ''}${exam.primaryGroupName != null ? ' • ${exam.primaryGroupName}' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // 4 KPI Metric Cards Grid
          Row(
            children: [
              // Submissions
              Expanded(
                child: _buildMetricTile(
                  title: context.l10n.metricSubmissionsRateTitle,
                  value: '$submittedCount / $totalAssigned',
                  subtitle: '${stats.submissionRate.toStringAsFixed(0)}%',
                  accentColor: const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),

              // Average Score
              Expanded(
                child: _buildMetricTile(
                  title: context.l10n.metricAverageScoreTitle,
                  value: '${stats.averageScore} / ${exam.maxScore}',
                  subtitle: '${stats.averagePercentage.toStringAsFixed(0)}%',
                  accentColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),

              // Pass Rate
              Expanded(
                child: _buildMetricTile(
                  title: context.l10n.metricPassRateTitle,
                  value: '${stats.passedCount} / $submittedCount',
                  subtitle: '${stats.passRate.toStringAsFixed(0)}%',
                  accentColor: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),

              // WhatsApp Dispatched
              Expanded(
                child: _buildMetricTile(
                  title: context.l10n.metricWhatsAppDispatchedTitle,
                  value: '$notifiedCount / $totalAssigned',
                  subtitle: context.l10n.notifiedBadgeShort,
                  accentColor: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context,
    ExamDispatchCubit cubit,
    ExamDispatchLoaded state,
  ) {
    final stats = state.roster.stats;
    final total = stats.totalAssignedStudents;
    final submitted = stats.submittedCount;
    final passed = stats.passedCount;
    final failed = stats.failedCount;
    final notStarted = stats.notStartedCount + stats.inProgressCount;
    final unnotified = total - state.notifiedCount;
    final notified = state.notifiedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Field
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: context.l10n.searchStudentOrPhoneHint,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      cubit.setSearchQuery('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          onChanged: cubit.setSearchQuery,
        ),
        const SizedBox(height: AppSpacing.s12),

        // Filter Pills Scroll
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: context.l10n.filterAllRoster(total),
                isSelected: state.activeFilter == ExamDispatchFilter.all,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.all),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterSubmittedRoster(submitted),
                isSelected: state.activeFilter == ExamDispatchFilter.submitted,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.submitted),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterPassedRoster(passed),
                isSelected: state.activeFilter == ExamDispatchFilter.passed,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.passed),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterNeedsAttentionRoster(failed),
                isSelected: state.activeFilter == ExamDispatchFilter.needsAttention,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.needsAttention),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterNotStartedRoster(notStarted),
                isSelected: state.activeFilter == ExamDispatchFilter.notStarted,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.notStarted),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterUnnotifiedRoster(unnotified),
                isSelected: state.activeFilter == ExamDispatchFilter.unnotified,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.unnotified),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterNotifiedRoster(notified),
                isSelected: state.activeFilter == ExamDispatchFilter.notified,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.notified),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterMissingPhoneRoster,
                isSelected: state.activeFilter == ExamDispatchFilter.missingPhone,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.missingPhone),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

class BoxStyle {
  static final subtle = BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );
}
