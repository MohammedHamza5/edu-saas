import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';

class LinkExamToLectureSheet extends StatefulWidget {
  final ExamEntity exam;
  final String groupId;
  final ExamsCubit cubit;

  const LinkExamToLectureSheet({
    super.key,
    required this.exam,
    required this.groupId,
    required this.cubit,
  });

  @override
  State<LinkExamToLectureSheet> createState() =>
      LinkExamToLectureSheetState();
}

class LinkExamToLectureSheetState extends State<LinkExamToLectureSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _lessons = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _selectedLessonId;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedLessonId = widget.exam.linkedLessonId;
    _fetchLessons();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLessons() async {
    final list = await widget.cubit.getGroupLessons(widget.groupId);
    if (!mounted) return;
    setState(() {
      _lessons = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _lessons.where((l) {
      if (_search.isEmpty) return true;
      final t = (l['title'] as String? ?? '').toLowerCase();
      return t.contains(_search.toLowerCase());
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.linkExamToLectureDialogTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.exam.title,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              context.l10n.linkExamToLectureDialogSubtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Search input
            AppTextField(
              controller: _searchCtrl,
              hintText: context.l10n.searchLecturesHint,
              prefixIcon: const Icon(Icons.search, size: 18),
              onChanged: (val) => setState(() => _search = val.trim()),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Lessons List
            Expanded(
              child: _isLoading
                  ? const AppLoadingView.list(count: 4)
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            context.l10n.noLecturesFound,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.s8),
                          itemBuilder: (context, idx) {
                            final lesson = filtered[idx];
                            final id = lesson['id']?.toString() ?? '';
                            final title = lesson['title']?.toString() ?? '';
                            final sortOrder = lesson['sort_order'];
                            final attachedExamId =
                                lesson['associated_exam_id']?.toString();
                            final attachedExamTitle =
                                lesson['exam_title']?.toString() ?? '';
                            final isCurrentExamAttached =
                                attachedExamId == widget.exam.id;
                            final isSelected = _selectedLessonId == id;
                            final isAttachedToOther =
                                attachedExamId != null && !isCurrentExamAttached;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedLessonId = id;
                                });
                              },
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMedium,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF0284C7)
                                          .withValues(alpha: 0.08)
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0284C7)
                                        : AppColors.border,
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: isSelected
                                          ? const Color(0xFF0284C7)
                                          : AppColors.textMuted,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.s12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (sortOrder != null) ...[
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceVariant,
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '#$sortOrder',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          if (isCurrentExamAttached)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.success
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                context.l10n.linkedToLecturePill(
                                                  title,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            )
                                          else if (isAttachedToOther)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                context.l10n
                                                    .currentExamAttachedWarning(
                                                  attachedExamTitle,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.warning,
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0284C7)
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                context.l10n
                                                    .lectureFreeForLinking,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0284C7),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  _isSubmitting
                      ? context.l10n.savingChanges
                      : context.l10n.confirmLinkExamAction,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: (_isSubmitting ||
                        _selectedLessonId == null ||
                        _selectedLessonId == widget.exam.linkedLessonId)
                    ? null
                    : () async {
                        setState(() => _isSubmitting = true);
                        final selectedLesson = _lessons.firstWhere(
                          (l) => l['id'] == _selectedLessonId,
                          orElse: () => <String, dynamic>{},
                        );
                        final lessonTitle =
                            selectedLesson['title']?.toString() ?? '';
                        final messenger = ScaffoldMessenger.of(context);
                        final successToast =
                            context.l10n.examLinkedSuccessToast(lessonTitle);
                        final nav = Navigator.of(context);

                        final success = await widget.cubit.linkExamToLesson(
                          examId: widget.exam.id,
                          lessonId: _selectedLessonId!,
                          groupId: widget.groupId,
                        );

                        if (mounted && context.mounted) {
                          nav.pop();
                          if (success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(successToast),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXAM DETAILS & ATTEMPTS SHEET CONTENT
// ─────────────────────────────────────────────────────────────────────────────

