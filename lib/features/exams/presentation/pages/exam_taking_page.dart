import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../content/presentation/widgets/secure_pdf_viewer.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../../domain/entities/exam_entity.dart';
import '../widgets/exam_image_viewer.dart';
import '../widgets/question_option_tile.dart';
import '../widgets/sat_exam_tools_sheet.dart';
import '../widgets/floating_desmos_calculator.dart';
import 'exam_result_page.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../../question_bank/presentation/widgets/question_display_widgets.dart';
import '../../../../core/widgets/forensic_watermark_overlay.dart';
import '../../../../core/utils/exam_security_util.dart';
import '../utils/exam_asset_preloader.dart';

class ExamTakingPage extends StatefulWidget {
  final bool isLectureExam;
  final LessonAssignmentEntity? nextLesson;
  final int? nextLessonIndex;
  final int? totalLessonsCount;

  const ExamTakingPage({
    super.key,
    this.isLectureExam = false,
    this.nextLesson,
    this.nextLessonIndex,
    this.totalLessonsCount,
  });

  @override
  State<ExamTakingPage> createState() => _ExamTakingPageState();
}

class _ExamTakingPageState extends State<ExamTakingPage>
    with WidgetsBindingObserver {
  int _securityViolationsCount = 0;
  bool _isPrivacyShieldActive = false;
  bool _isAutoSubmitting = false;
  bool _isDesmosCalculatorOpen = false;
  bool _hasOpenedCalculatorEver = false;
  bool _showMobilePdfOverlay = false;
  bool _showDesktopPdfPane = true;
  String? _cachedPdfSignedUrl;
  bool _isLoadingPdfUrl = false;
  String? _pdfLoadError;
  static const int _maxAllowedViolations = 3;
  final ExamAssetPreloader _assetPreloader = ExamAssetPreloader();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setExamSecurityActive(true);
  }

  @override
  void dispose() {
    _assetPreloader.dispose();
    setExamSecurityActive(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isPrivacyShieldActive && mounted) {
        setState(() {
          _isPrivacyShieldActive = false;
        });
      }
      return;
    }

    // Flag violations only when page is genuinely hidden or paused (tab switch/backgrounding).
    // Inactive is ignored to avoid false positives on mobile volume buttons, notifications, or keyboard.
    final isViolation =
        state == AppLifecycleState.hidden || state == AppLifecycleState.paused;

    if (isViolation) {
      if (!_isAutoSubmitting && mounted) {
        final cubit = context.read<ExamsCubit>();
        final currentState = cubit.state;
        if (currentState is ExamTakingState &&
            !currentState.isSubmitting &&
            !currentState.submitSuccess) {
          // Untimed lecture exams / homework quizzes are flexible practice activities;
          // do not enforce strict anti-cheat auto-submission.
          if (currentState.isUntimed || widget.isLectureExam) {
            return;
          }

          if (!_isPrivacyShieldActive) {
            setState(() {
              _isPrivacyShieldActive = true;
              _securityViolationsCount++;
            });

            if (_securityViolationsCount >= _maxAllowedViolations) {
              // Final Violation: Immediate auto-submission
              _isAutoSubmitting = true;
              cubit.submitExam(reason: ExamSubmissionReason.securityViolations);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.examAutoSubmittedDueToViolations),
                  backgroundColor: AppColors.error,
                  duration: const Duration(seconds: 5),
                ),
              );
            } else {
              // Warning notice
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.examSecurityWarningSubtitle),
                  backgroundColor: AppColors.warning,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    }
  }

  void _confirmForcedExit(BuildContext context, ExamTakingState state) {
    final unanswered = state.totalQuestions - state.answeredCount;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: Text(context.l10n.forcedExitWarningTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.forcedExitWarningMessage,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.s12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.answeredQuestionsCount(
                      state.answeredCount,
                      state.totalQuestions,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (unanswered > 0) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      context.l10n.unansweredWarning(unanswered),
                      style: const TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.stayAndContinueButton),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _isAutoSubmitting = true;
              });
              context.read<ExamsCubit>().submitExam(
                reason: ExamSubmissionReason.forcedExit,
              );
            },
            child: Text(context.l10n.forcedExitConfirmButton),
          ),
        ],
      ),
    );
  }

  void _confirmSubmit(BuildContext context, ExamTakingState state) {
    final unanswered = state.totalQuestions - state.answeredCount;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.confirmSubmitExamTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.answeredQuestionsCount(
                state.answeredCount,
                state.totalQuestions,
              ),
            ),
            if (unanswered > 0) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                context.l10n.unansweredWarning(unanswered),
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s12),
            Text(context.l10n.confirmSubmitQuestion),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.continueSolving),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<ExamsCubit>().submitExam(
                reason: ExamSubmissionReason.studentSubmitted,
              );
            },
            child: Text(
              context.l10n.yesSubmitExam,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _ensurePdfUrlLoaded(ExamEntity exam) {
    if (_cachedPdfSignedUrl != null || _isLoadingPdfUrl) return;
    final path = exam.pdfStoragePath;
    if (path == null || path.isEmpty) return;

    _isLoadingPdfUrl = true;
    _pdfLoadError = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final url = await context.read<ExamsCubit>().getSignedPdfUrl(path);
        if (mounted) {
          setState(() {
            _cachedPdfSignedUrl = url;
            _isLoadingPdfUrl = false;
            if (url == null || url.isEmpty) {
              _pdfLoadError = context.l10n.secureUrlErrorFallback;
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingPdfUrl = false;
            _pdfLoadError = context.l10n.secureUrlGenericError;
          });
        }
      }
    });
  }

  String _resolveWatermarkText() {
    final user = SupabaseService.currentUser;
    final metadata = user?.userMetadata;
    final name = (metadata?['full_name'] as String?) ??
        user?.email?.split('@').first ??
        '';
    final phone = (metadata?['phone'] as String?) ?? user?.phone ?? '';
    final id = user != null && user.id.isNotEmpty
        ? user.id.substring(0, math.min(8, user.id.length))
        : '';
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (phone.isNotEmpty) parts.add(phone);
    if (id.isNotEmpty) parts.add('ID: $id');
    return parts.isEmpty ? 'EduSaaS Protected' : parts.join(' • ');
  }

  Widget _buildPdfViewerWidget(ExamTakingState state) {
    _ensurePdfUrlLoaded(state.exam);

    if (_isLoadingPdfUrl) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLoadingView.compact(size: 32),
            const SizedBox(height: AppSpacing.s12),
            Text(
              context.l10n.examPdfLoading,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_pdfLoadError != null || _cachedPdfSignedUrl == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 36,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                _pdfLoadError ?? context.l10n.secureUrlGenericError,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.s12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _cachedPdfSignedUrl = null;
                    _pdfLoadError = null;
                  });
                  _ensurePdfUrlLoaded(state.exam);
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(context.l10n.retryAction),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey.shade900,
      child: buildSecurePdfViewer(
        pdfUrl: _cachedPdfSignedUrl!,
        watermarkText: _resolveWatermarkText(),
        docTitle: state.exam.pdfFileName ?? state.exam.title,
      ),
    );
  }

  Widget _buildMobilePdfOverlay(
    BuildContext context,
    ExamTakingState state,
    int qIndex,
  ) {
    return Positioned.fill(
      child: Container(
        color: AppColors.surface,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s10,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: const Border(
                  bottom: BorderSide(color: AppColors.border),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      state.exam.pdfFileName ?? state.exam.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Text(
                      context.l10n.questionProgress(
                        qIndex + 1,
                        state.totalQuestions,
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _showMobilePdfOverlay = false;
                      });
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(
                      context.l10n.hideExamBooklet,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildPdfViewerWidget(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsView(
    BuildContext context,
    ExamTakingState state,
    int qIndex,
    ExamQuestionEntity question, {
    required bool isDesktop,
  }) {
    return ForensicWatermarkOverlay(
      child: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: state.totalQuestions > 0
                ? (state.currentQuestionIndex + 1) / state.totalQuestions
                : 0,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.primary,
            ),
            minHeight: 4,
          ),

          // Attached PDF quick ribbon (for mobile or when desktop PDF pane is closed)
          if (state.exam.hasAttachedPdf && (!isDesktop || !_showDesktopPdfPane))
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s8,
                AppSpacing.s16,
                0,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
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
                      state.exam.pdfFileName ?? context.l10n.attachedExamPdf,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                        vertical: 4,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        if (isDesktop) {
                          _showDesktopPdfPane = true;
                        } else {
                          _showMobilePdfOverlay = true;
                        }
                      });
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: Text(
                      context.l10n.viewExamBooklet,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Question Header info
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.questionProgress(
                    qIndex + 1,
                    state.totalQuestions,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  context.l10n.solvedCount(
                    state.answeredCount,
                    state.totalQuestions,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Question Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Card
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
                              ),
                              child: Text(
                                question.questionType
                                    .localizedLabel(context),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              context.l10n.scorePoints(
                                question.points,
                              ),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        Builder(
                          builder: (context) {
                            final hasExplicitImage =
                                question.imageUrl != null &&
                                question.imageUrl!
                                    .trim()
                                    .isNotEmpty;
                            final isTextAnImageUrl =
                                QuestionStemView.isImageUrl(
                                  question.questionText.trim(),
                                );
                            final effectiveImageUrl =
                                hasExplicitImage
                                ? question.imageUrl!
                                : (isTextAnImageUrl
                                      ? question.questionText.trim()
                                      : null);
                            final shouldShowText =
                                question.questionText
                                    .trim()
                                    .isNotEmpty &&
                                !isTextAnImageUrl;

                            return Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (shouldShowText) ...[
                                  Text(
                                    question.questionText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppSpacing.s12,
                                  ),
                                ],
                                if (effectiveImageUrl != null &&
                                    effectiveImageUrl.isNotEmpty)
                                  ExamImageViewer(
                                    key: ValueKey(
                                      'exam_q_${question.id}_$effectiveImageUrl',
                                    ),
                                    imageUrl: effectiveImageUrl,
                                    imageMeta: question.imageMeta,
                                    caption: context.l10n
                                        .questionProgress(
                                          qIndex + 1,
                                          state.totalQuestions,
                                        ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s20),

                  // Options list
                  if (question.options.isNotEmpty) ...[
                    Text(
                      context.l10n.chooseCorrectAnswer,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    ...question.options.asMap().entries.map((
                      optEntry,
                    ) {
                      final optIdx = optEntry.key;
                      final option = optEntry.value;
                      final isSelected =
                          state.answers[question.id] == option.id;

                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSpacing.s10,
                        ),
                        child: QuestionOptionTile(
                          option: option,
                          index: optIdx,
                          isSelected: isSelected,
                          onTap: () {
                            context.read<ExamsCubit>().selectAnswer(
                              question.id,
                              option.id,
                            );
                          },
                        ),
                      );
                    }),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                        border: Border.all(
                          color: AppColors.error.withValues(
                            alpha: 0.3,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: AppColors.error,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Text(
                              context
                                  .l10n
                                  .noOptionsAvailableForQuestionWarning,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Navigation Control Bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(
                top: BorderSide(color: AppColors.border),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Previous button
                if (state.hasPrevious)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<ExamsCubit>().goToQuestion(
                          qIndex - 1,
                        );
                      },
                      icon: const Icon(
                        Icons.arrow_forward,
                        size: 16,
                      ),
                      label: Text(context.l10n.previousQuestion),
                    ),
                  )
                else
                  const Spacer(),

                const SizedBox(width: AppSpacing.s12),

                // Next or Submit button
                if (state.hasNext)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        context.read<ExamsCubit>().goToQuestion(
                          qIndex + 1,
                        );
                      },
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: Text(context.l10n.nextQuestion),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: state.isSubmitting
                          ? null
                          : () => _confirmSubmit(context, state),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                      ),
                      label: state.isSubmitting
                          ? const AppLoadingView.compact(
                              size: 16,
                              color: Colors.white,
                            )
                          : Text(context.l10n.submitExamNow),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExamsCubit, ExamsState>(
      listenWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is ExamTakingState && current is ExamTakingState) {
          return previous.currentQuestionIndex !=
                  current.currentQuestionIndex ||
              previous.submitSuccess != current.submitSuccess ||
              previous.errorMessage != current.errorMessage;
        }
        return true;
      },
      listener: (context, state) {
        if (state is ExamTakingState) {
          _assetPreloader.startOrUpdate(
            context: context,
            questions: state.questions,
            currentIndex: state.currentQuestionIndex,
          );
          if (state.submitSuccess && state.submitResult != null) {
            Navigator.of(context).pushReplacement<void, void>(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: context.read<ExamsCubit>(),
                  child: ExamResultPage(
                    exam: state.exam,
                    attempt: state.submitResult!.copyWith(
                      questions: state.questions,
                      answers: state.submitResult!.answers.isNotEmpty
                          ? state.submitResult!.answers
                          : state.answers.entries
                              .map(
                                (e) => ExamAnswerEntity(
                                  id: '',
                                  attemptId: state.submitResult!.id,
                                  questionId: e.key,
                                  selectedOptionId: e.value,
                                  answeredAt: DateTime.now(),
                                ),
                              )
                              .toList(),
                    ),
                    isLectureExam:
                        widget.isLectureExam ||
                        state.exam.isLectureExam ||
                        state.exam.isLinkedToLesson,
                    nextLesson: widget.nextLesson,
                    nextLessonIndex: widget.nextLessonIndex,
                    totalLessonsCount: widget.totalLessonsCount,
                  ),
                ),
              ),
            );
          } else if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is ExamTakingState && current is ExamTakingState) {
          return previous.currentQuestionIndex !=
                  current.currentQuestionIndex ||
              previous.answers != current.answers ||
              previous.answeredCount != current.answeredCount ||
              previous.isSubmitting != current.isSubmitting ||
              previous.submitSuccess != current.submitSuccess;
        }
        return true;
      },
      builder: (context, state) {
        if (state is ExamsError) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.examRulesAndGuidelines),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(context.l10n.backToExamsList),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is! ExamTakingState) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: const Center(child: AppLoadingView.signature()),
          );
        }

        final qIndex = state.currentQuestionIndex;
        final question = state.currentQuestion;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              _confirmForcedExit(context, state);
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(state.exam.title),
              centerTitle: false,
              actions: [
                if (state.exam.hasAttachedPdf)
                  IconButton(
                    icon: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: (_showMobilePdfOverlay || _showDesktopPdfPane)
                          ? AppColors.primary
                          : null,
                    ),
                    tooltip: context.l10n.viewExamBooklet,
                    onPressed: () {
                      final isDesktop =
                          MediaQuery.of(context).size.width >= 900;
                      setState(() {
                        if (isDesktop) {
                          _showDesktopPdfPane = !_showDesktopPdfPane;
                        } else {
                          _showMobilePdfOverlay = !_showMobilePdfOverlay;
                        }
                      });
                    },
                  ),
                // SAT Reference Formulas Sheet
                IconButton(
                  icon: const Icon(Icons.menu_book_rounded),
                  tooltip: context.l10n.referenceSheetTooltip,
                  onPressed: () =>
                      SatExamToolsSheet.showReferenceSheet(context),
                ),
                // Official SAT Desmos Calculator (Floating Window)
                IconButton(
                  icon: Icon(
                    Icons.calculate_rounded,
                    color: _isDesmosCalculatorOpen
                        ? AppColors.primaryLight
                        : null,
                  ),
                  tooltip: context.l10n.calculatorTooltip,
                  onPressed: () {
                    setState(() {
                      _hasOpenedCalculatorEver = true;
                      _isDesmosCalculatorOpen = !_isDesmosCalculatorOpen;
                    });
                  },
                ),
                // Timer / Untimed badge
                const _ExamTimerBadge(),
              ],
            ),
            floatingActionButton: (MediaQuery.of(context).size.width < 900 &&
                    state.exam.hasAttachedPdf &&
                    !_showMobilePdfOverlay)
                ? FloatingActionButton.extended(
                    onPressed: () {
                      setState(() {
                        _showMobilePdfOverlay = true;
                      });
                    },
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    label: Text(context.l10n.viewExamBooklet),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  )
                : null,
            body: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth >= 900;
                    if (isDesktop &&
                        state.exam.hasAttachedPdf &&
                        _showDesktopPdfPane) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 55,
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
                                      bottom:
                                          BorderSide(color: AppColors.border),
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
                                          state.exam.pdfFileName ??
                                              state.exam.title,
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
                                        onPressed: () {
                                          setState(() {
                                            _showDesktopPdfPane = false;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(child: _buildPdfViewerWidget(state)),
                              ],
                            ),
                          ),
                          Container(width: 1, color: AppColors.border),
                          Expanded(
                            flex: 45,
                            child: _buildQuestionsView(
                              context,
                              state,
                              qIndex,
                              question,
                              isDesktop: true,
                            ),
                          ),
                        ],
                      );
                    }

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildQuestionsView(
                          context,
                          state,
                          qIndex,
                          question,
                          isDesktop: isDesktop,
                        ),
                        if (!isDesktop &&
                            state.exam.hasAttachedPdf &&
                            _showMobilePdfOverlay)
                          _buildMobilePdfOverlay(context, state, qIndex),
                      ],
                    );
                  },
                ),
                // Official Floating SAT Desmos Calculator (Simulating CollegeBoard Bluebook)
                // Stays mounted in DOM after first opening so student formulas/graphs NEVER reset!
                if (_hasOpenedCalculatorEver)
                  FloatingDesmosCalculator(
                    isVisible: _isDesmosCalculatorOpen,
                    onClose: () {
                      setState(() {
                        _isDesmosCalculatorOpen = false;
                      });
                    },
                  ),
                if (_isPrivacyShieldActive)
                  _buildPrivacyShield()
                else if (state.isExpired ||
                    (!state.isUntimed &&
                        state.remainingSeconds <= 0 &&
                        state.isSubmitting))
                  _buildTimeExpiredOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyShield() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Center(
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color:
                          (_isAutoSubmitting
                                  ? AppColors.error
                                  : AppColors.warning)
                              .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isAutoSubmitting
                          ? Icons.lock_outline_rounded
                          : Icons.warning_amber_rounded,
                      color: _isAutoSubmitting
                          ? AppColors.error
                          : AppColors.warning,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    context.l10n.examSecurityAlertTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isAutoSubmitting
                          ? AppColors.error
                          : AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    _isAutoSubmitting
                        ? context.l10n.examAutoSubmittedDueToViolations
                        : context.l10n.examSecurityWarningSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (!_isAutoSubmitting) ...[
                    const SizedBox(height: AppSpacing.s12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        context.l10n.examSecurityViolationsCount(
                          _securityViolationsCount,
                          _maxAllowedViolations,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s24,
                          vertical: AppSpacing.s12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMedium,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(context.l10n.returnToExamAction),
                      onPressed: () {
                        setState(() {
                          _isPrivacyShieldActive = false;
                        });
                      },
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.s20),
                    const Center(child: AppLoadingView.signature()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeExpiredOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Center(
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.timer_off_outlined,
                      color: AppColors.warning,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    context.l10n.submissionReasonTimeExpired,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    context.l10n.timeExpiredAutoSubmittingNotice,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s20),
                  const Center(child: AppLoadingView.signature()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExamTimerBadge extends StatelessWidget {
  const _ExamTimerBadge();

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ExamsCubit,
      ExamsState,
      ({int remainingSeconds, bool isUntimed})
    >(
      selector: (state) {
        if (state is ExamTakingState) {
          return (
            remainingSeconds: state.remainingSeconds,
            isUntimed: state.isUntimed,
          );
        }
        return (remainingSeconds: 0, isUntimed: false);
      },
      builder: (context, timerData) {
        if (timerData.isUntimed) {
          return Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s6,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.all_inclusive_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.s6),
                Text(
                  context.l10n.untimedExamBadge,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          );
        }

        final isUrgent = timerData.remainingSeconds < 300; // < 5 minutes
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s6,
          ),
          decoration: BoxDecoration(
            color: isUrgent
                ? AppColors.error.withValues(alpha: 0.15)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            border: isUrgent ? Border.all(color: AppColors.error) : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: isUrgent ? AppColors.error : AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                _formatDuration(timerData.remainingSeconds),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isUrgent ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
