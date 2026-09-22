import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../widgets/lesson_editor_pane.dart';

/// Full-page dedicated workspace for a single Lesson/Lecture in the Course Builder.
///
/// Provides:
/// 1. Top Breadcrumb & Back to Syllabus navigation (`← العودة للمنهج`).
/// 2. Tab 1: Comprehensive Lesson Editor (Video, Title, PDF Handout, Quiz, Gating).
/// 3. Tab 2: 100% Real Live Analytics from Supabase (Zero mock/fake numbers).
class TeacherLessonDetailsPage extends StatefulWidget {
  final String groupId;
  final String lessonId; // Can be a UUID or 'new'
  final String? groupName;

  const TeacherLessonDetailsPage({
    super.key,
    required this.groupId,
    required this.lessonId,
    this.groupName,
  });

  @override
  State<TeacherLessonDetailsPage> createState() =>
      _TeacherLessonDetailsPageState();
}

class _TeacherLessonDetailsPageState extends State<TeacherLessonDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  ContentEntity? _lesson;
  bool _isLoading = true;

  // Real Analytics State (100% fetched from Supabase, NO mock numbers)
  int _totalStudents = 0;
  int _totalViews = 0;
  int _completedStudents = 0;
  double? _averageQuizScore; // null if no quiz attached or no completed attempts

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLessonData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLessonData() async {
    setState(() => _isLoading = true);

    if (widget.lessonId == 'new') {
      _lesson = null;
      _totalStudents = 0;
      _totalViews = 0;
      _completedStudents = 0;
      _averageQuizScore = null;
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final cubit = context.read<ContentCubit>();
      if (cubit.state is! ContentLoaded) {
        await cubit.loadGroupContent(widget.groupId);
      }

      final items = cubit.state is ContentLoaded
          ? (cubit.state as ContentLoaded).items
          : <ContentEntity>[];
      final found = items.where((e) => e.id == widget.lessonId).firstOrNull;

      if (found != null) {
        _lesson = found;
      }

      await _loadAnalytics();
    } catch (_) {
      // Handled gracefully
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAnalytics() async {
    if (widget.lessonId == 'new') return;

    try {
      final client = SupabaseService.client;

      // 1. Total students in this group (active)
      final countRes = await client
          .from('group_members')
          .select('id')
          .eq('group_id', widget.groupId)
          .eq('status', 'active');
      final total = (countRes as List).length;

      // 2. Video views & completions
      int views = 0;
      int completed = 0;
      String? vId = _lesson?.videoId;
      if (vId == null) {
        final videoRes = await client
            .from('videos')
            .select('id')
            .eq('content_id', widget.lessonId)
            .maybeSingle();
        if (videoRes != null && videoRes['id'] != null) {
          vId = videoRes['id'] as String;
        }
      }

      if (vId != null) {
        final vpRes = await client
            .from('video_progress')
            .select('completed, progress_seconds')
            .eq('video_id', vId);
        final list = vpRes as List;
        views = list.where((r) => (r['progress_seconds'] as int? ?? 0) > 0).length;
        completed = list.where((r) => r['completed'] == true).length;
      }

      // 3. Quiz average percentage
      double? avgScore;
      final examId = _lesson?.associatedExamId;
      if (examId != null) {
        final attemptsRes = await client
            .from('exam_attempts')
            .select('percentage')
            .eq('exam_id', examId)
            .inFilter('status', ['submitted', 'completed']);
        final attempts = attemptsRes as List;
        if (attempts.isNotEmpty) {
          double sum = 0;
          int validCount = 0;
          for (final a in attempts) {
            final p = a['percentage'];
            if (p != null) {
              sum += (p is num ? p.toDouble() : double.tryParse(p.toString()) ?? 0);
              validCount++;
            }
          }
          if (validCount > 0) {
            avgScore = sum / validCount;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalStudents = total;
          _totalViews = views;
          _completedStudents = completed;
          _averageQuizScore = avgScore;
        });
      }
    } catch (_) {}
  }

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teacher/groups/${widget.groupId}/content');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isNew = widget.lessonId == 'new';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final displayHeaderTitle = isNew
        ? l10n.lessonEditorAddTitle
        : '${widget.groupName ?? ""} / ${_lesson?.title ?? l10n.lessonDetails}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Top Navigation Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s12,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _navigateBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: Text(l10n.backToCourse),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayHeaderTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isNew ? l10n.addLessonButton : l10n.editLessonTitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  text: l10n.lessonDetails,
                ),
                Tab(
                  icon: const Icon(Icons.analytics_rounded, size: 18),
                  text: l10n.lessonAnalytics,
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Full-Page Lesson Editor
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: LessonEditorPane(
                        editingLesson: _lesson,
                        groupId: widget.groupId,
                        groupName: widget.groupName ?? '',
                        defaultPassingScore: 70,
                        onSaved: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.contentUpdatedToast),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          if (isNew) {
                            _navigateBack();
                          } else {
                            _loadLessonData();
                          }
                        },
                        onCancel: _navigateBack,
                        onClose: _navigateBack,
                      ),
                    ),
                  ),
                ),

                // Tab 2: Analytics & Student Progress (100% Real Supabase Data)
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: ANALYTICS & STUDENT PROGRESS (REAL SUPABASE DATA) ---
  Widget _buildAnalyticsTab() {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (widget.lessonId == 'new' || _lesson == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: AppEmptyView(
            message: l10n.analyticsAvailableAfterPublish,
            icon: Icons.analytics_outlined,
          ),
        ),
      );
    }

    final quizScoreText = _averageQuizScore != null
        ? '${_averageQuizScore!.toStringAsFixed(1)}%'
        : l10n.noDataDash;

    final quizSubtitle = _lesson?.associatedExamId == null
        ? l10n.noAssociatedQuiz
        : (_averageQuizScore == null ? l10n.noAttemptsYet : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: l10n.totalViews,
                      value: '$_totalViews',
                      icon: Icons.visibility_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: _buildMetricCard(
                      title: l10n.completedLesson,
                      value: '$_completedStudents / $_totalStudents',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: _buildMetricCard(
                      title: l10n.averageQuizScore,
                      value: quizScoreText,
                      subtitle: quizSubtitle,
                      icon: Icons.emoji_events_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.studentLessonProgressStats,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _totalStudents > 0
                              ? _completedStudents / _totalStudents
                              : 0.0,
                          minHeight: 10,
                          backgroundColor: AppColors.border,
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        l10n.overallCompletionRate(_totalStudents > 0
                            ? ((_completedStudents / _totalStudents) * 100).toInt()
                            : 0),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
