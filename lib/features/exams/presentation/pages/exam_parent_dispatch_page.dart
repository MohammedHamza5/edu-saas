import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../cubit/exam_dispatch_cubit.dart';
import '../cubit/exam_dispatch_state.dart';
import '../widgets/exam_dispatch_filter_bar.dart';
import '../widgets/exam_dispatch_hero_banner.dart';
import '../widgets/exam_dispatch_student_card.dart';
import '../widgets/exam_whatsapp_dispatch_modal.dart';
import '../widgets/whatsapp_auto_dispatch_banner.dart';
import '../widgets/whatsapp_gateway_connect_dialog.dart';
import '../../../settings/data/datasources/whatsapp_gateway_remote_datasource.dart';

/// Parent WhatsApp dispatch coordinator page for exam results and performance updates.
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
    final students = state.filteredStudents;
    if (students.isEmpty) return;

    final startIndex = students.indexWhere(
      (s) => !state.isStudentFullySent(s),
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
      onSent: () => cubit.markAsSent(student.studentId,
          attemptId: student.latestAttemptId),
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
            const Icon(Icons.phone_outlined,
                color: AppColors.primary, size: 22),
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
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
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
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMedium),
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
    buffer.writeln(
        '• متوسط الدرجات: ${stats.averageScore} من ${exam.maxScore} (${stats.averagePercentage}%)');
    buffer.writeln('• نسبة النجاح: ${stats.passRate.toStringAsFixed(1)}%');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');

    for (int i = 0; i < state.roster.students.length; i++) {
      final s = state.roster.students[i];
      final rank = i + 1;
      if (s.isSubmitted) {
        final scoreText =
            '${s.bestScore ?? 0}/${exam.maxScore} (${s.bestPercentage?.toStringAsFixed(1)}%)';
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
                  // WhatsApp Gateway Settings Action
                  IconButton(
                    icon: const Icon(Icons.settings_phone_rounded, size: 20),
                    tooltip: context.l10n.whatsappGatewaySettingsTooltip,
                    onPressed: () => WhatsAppGatewayConnectDialog.show(
                      context,
                      dataSource: WhatsAppGatewayRemoteDataSourceImpl(),
                    ),
                  ),

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
                // ── 0. WhatsApp Auto-Dispatch Banner ───────────────────────
                const WhatsAppAutoDispatchBanner(),

                // ── 1. Hero KPI Stats Header ──────────────────────────────
                ExamDispatchHeroBanner(
                  exam: exam,
                  stats: stats,
                  state: state,
                ),
                const SizedBox(height: AppSpacing.s16),

                // ── 2. Search & Filter Bar ────────────────────────────────
                ExamDispatchFilterBar(
                  searchController: _searchController,
                  cubit: cubit,
                  state: state,
                ),
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
                              Icon(Icons.sort_rounded,
                                  size: 16, color: AppColors.primary),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down,
                                  size: 16, color: AppColors.primary),
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
                    final isSent = state.isStudentFullySent(student);
                    final hasNewAttempt = state.hasNewUnsentAttempt(student);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                      child: ExamDispatchStudentCard(
                        student: student,
                        exam: exam,
                        index: index + 1,
                        isSent: isSent,
                        hasNewAttempt: hasNewAttempt,
                        onTapDispatch: () =>
                            _openDispatchModalForStudent(state, index),
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
}
