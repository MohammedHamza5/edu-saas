import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';

/// Fullscreen security blur overlay that activates when a student unfocuses
/// the exam window or triggers integrity violations.
class ExamPrivacyShieldOverlay extends StatelessWidget {
  final bool isAutoSubmitting;
  final int securityViolationsCount;
  final int maxAllowedViolations;
  final VoidCallback onReturnToExam;

  const ExamPrivacyShieldOverlay({
    super.key,
    required this.isAutoSubmitting,
    required this.securityViolationsCount,
    required this.maxAllowedViolations,
    required this.onReturnToExam,
  });

  @override
  Widget build(BuildContext context) {
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
                      color: (isAutoSubmitting ? AppColors.error : AppColors.warning)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAutoSubmitting
                          ? Icons.lock_outline_rounded
                          : Icons.warning_amber_rounded,
                      color: isAutoSubmitting ? AppColors.error : AppColors.warning,
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
                      color: isAutoSubmitting ? AppColors.error : AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    isAutoSubmitting
                        ? context.l10n.examAutoSubmittedDueToViolations
                        : context.l10n.examSecurityWarningSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (!isAutoSubmitting) ...[
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
                          securityViolationsCount,
                          maxAllowedViolations,
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
                      onPressed: onReturnToExam,
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
}

/// Overlay displayed when the examination time limit expires.
class ExamTimeExpiredOverlay extends StatelessWidget {
  const ExamTimeExpiredOverlay({super.key});

  @override
  Widget build(BuildContext context) {
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

/// Modal overlay that prevents user interaction while the exam submission is in flight.
class ExamSubmittingBlockingOverlay extends StatelessWidget {
  const ExamSubmittingBlockingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: PopScope(
        canPop: false,
        child: Container(
          color: Colors.black.withValues(alpha: 0.82),
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Center(
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s32,
                  vertical: AppSpacing.s28,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),
                    Text(
                      context.l10n.submittingExam,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      context.l10n.ruleDoNotCloseWindow,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dynamic timer badge widget for exam duration countdown or untimed indicator.
class ExamTimerBadge extends StatelessWidget {
  const ExamTimerBadge({super.key});

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
