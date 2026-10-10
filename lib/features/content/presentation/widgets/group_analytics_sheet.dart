import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';

class _StudentAttentionItem {
  final String id;
  final String name;
  final String? avatarUrl;
  final int completionPercentage;

  _StudentAttentionItem({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.completionPercentage,
  });
}

class _ChapterMetricItem {
  final String chapterId;
  final String title;
  final int lessonCount;
  final int completionRate;
  final double? quizAvg;

  _ChapterMetricItem({
    required this.chapterId,
    required this.title,
    required this.lessonCount,
    required this.completionRate,
    this.quizAvg,
  });
}

/// Panoramic Group Academic Analytics Masterboard (100% Real Supabase Data).
class GroupAnalyticsSheet extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<ChapterEntity> chapters;
  final List<ContentEntity> lessons;

  const GroupAnalyticsSheet({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.chapters,
    required this.lessons,
  });

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String groupName,
    required List<ChapterEntity> chapters,
    required List<ContentEntity> lessons,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 800),
            child: GroupAnalyticsSheet(
              groupId: groupId,
              groupName: groupName,
              chapters: chapters,
              lessons: lessons,
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
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.6,
          builder: (ctx, scrollController) => GroupAnalyticsSheet(
            groupId: groupId,
            groupName: groupName,
            chapters: chapters,
            lessons: lessons,
          ),
        ),
      );
    }
  }

  @override
  State<GroupAnalyticsSheet> createState() => _GroupAnalyticsSheetState();
}

class _GroupAnalyticsSheetState extends State<GroupAnalyticsSheet> {
  bool _isLoading = true;
  String? _errorMessage;

  int _totalActiveStudents = 0;
  int _totalCourseViews = 0;
  int _overallCourseProgress = 0;
  double? _overallQuizzesAverage;

  List<_ChapterMetricItem> _chapterMetrics = [];
  List<_StudentAttentionItem> _studentsNeedingAttention = [];

  @override
  void initState() {
    super.initState();
    _loadGroupAnalytics();
  }

  Future<void> _loadGroupAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = SupabaseService.client;

      // 1. Fetch active students in this group with user profiles
      final membersRes = await client
          .from('group_members')
          .select('student_id, users!inner(id, full_name, avatar_url)')
          .eq('group_id', widget.groupId)
          .eq('status', 'active');

      final membersList = membersRes as List;
      final Map<String, Map<String, dynamic>> studentsMap = {};
      for (final row in membersList) {
        final sId = row['student_id'] as String?;
        final userObj = row['users'] as Map<String, dynamic>?;
        if (sId != null && userObj != null) {
          studentsMap[sId] = userObj;
        }
      }

      final totalStudents = studentsMap.length;

      // 2. Fetch all video IDs for this course's lessons
      final allLessonIds = widget.lessons.map((l) => l.id).toList();
      final Map<String, String> videoIdToLessonId = {};
      final List<String> allVideoIds = [];

      if (allLessonIds.isNotEmpty) {
        final videosRes = await client
            .from('videos')
            .select('id, content_id')
            .inFilter('content_id', allLessonIds);

        for (final v in (videosRes as List)) {
          final vid = v['id'] as String?;
          final cid = v['content_id'] as String?;
          if (vid != null && cid != null) {
            allVideoIds.add(vid);
            videoIdToLessonId[vid] = cid;
          }
        }
      }

      // 3. Fetch video progress across all course videos
      int totalViews = 0;
      final Map<String, Set<String>> studentCompletedVideoIds = {};

      if (allVideoIds.isNotEmpty) {
        final vpRes = await client
            .from('video_progress')
            .select('student_id, video_id, completed, progress_seconds')
            .inFilter('video_id', allVideoIds);

        for (final row in (vpRes as List)) {
          final sId = row['student_id'] as String?;
          final vId = row['video_id'] as String?;
          final progSec = row['progress_seconds'] as int? ?? 0;
          final isComp = row['completed'] == true;

          if (progSec > 0) {
            totalViews++;
          }
          if (isComp && sId != null && vId != null) {
            studentCompletedVideoIds
                .putIfAbsent(sId, () => <String>{})
                .add(vId);
          }
        }
      }

      // 4. Calculate overall completion per student & identify attention list (< 50%)
      int sumStudentProgress = 0;
      final List<_StudentAttentionItem> attentionList = [];
      final totalVideosCount = allVideoIds.length;

      for (final entry in studentsMap.entries) {
        final sId = entry.key;
        final profile = entry.value;
        final name = (profile['full_name'] as String?)?.trim();
        final avatar = profile['avatar_url'] as String?;

        final completedCount = studentCompletedVideoIds[sId]?.length ?? 0;
        final rate = totalVideosCount > 0
            ? ((completedCount / totalVideosCount) * 100).round()
            : 0;

        sumStudentProgress += rate;

        if (rate < 50) {
          attentionList.add(
            _StudentAttentionItem(
              id: sId,
              name: name?.isNotEmpty == true ? name! : 'Student',
              avatarUrl: avatar,
              completionPercentage: rate,
            ),
          );
        }
      }

      final overallProgress = totalStudents > 0
          ? (sumStudentProgress ~/ totalStudents)
          : 0;

      // 5. Calculate overall quizzes average
      final allExamIds = widget.lessons
          .expand((l) => [
                if (l.associatedExamId != null) l.associatedExamId!,
                ...l.attachedExams.map((e) => e.examId),
              ])
          .toSet()
          .toList();

      double? groupQuizAvg;
      final Map<String, double> examAvgMap = {};

      if (allExamIds.isNotEmpty) {
        final attemptsRes = await client
            .from('exam_attempts')
            .select('exam_id, percentage')
            .inFilter('exam_id', allExamIds)
            .inFilter('status', ['submitted', 'completed']);

        final Map<String, List<double>> examScores = {};
        for (final row in (attemptsRes as List)) {
          final eId = row['exam_id'] as String?;
          final p = row['percentage'];
          if (eId != null && p != null) {
            final val = p is num ? p.toDouble() : double.tryParse(p.toString());
            if (val != null) {
              examScores.putIfAbsent(eId, () => []).add(val);
            }
          }
        }

        double totalScoreSum = 0;
        int totalScoreCount = 0;
        for (final entry in examScores.entries) {
          final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
          examAvgMap[entry.key] = avg;
          totalScoreSum += entry.value.reduce((a, b) => a + b);
          totalScoreCount += entry.value.length;
        }

        if (totalScoreCount > 0) {
          groupQuizAvg = totalScoreSum / totalScoreCount;
        }
      }

      // 6. Chapter-by-chapter metrics breakdown
      final List<_ChapterMetricItem> chapterMetrics = [];
      for (final ch in widget.chapters) {
        final chLessons =
            widget.lessons.where((l) => l.chapterId == ch.id).toList();
        final chLessonIds = chLessons.map((l) => l.id).toSet();
        final chVideoIds = allVideoIds
            .where((vid) => chLessonIds.contains(videoIdToLessonId[vid]))
            .toList();

        int chCompletedStudents = 0;
        for (final sId in studentsMap.keys) {
          final completed = studentCompletedVideoIds[sId] ?? {};
          if (chVideoIds.isNotEmpty &&
              chVideoIds.every((vid) => completed.contains(vid))) {
            chCompletedStudents++;
          }
        }

        final chRate = totalStudents > 0
            ? ((chCompletedStudents / totalStudents) * 100).round()
            : 0;

        final chExamIds = chLessons
            .expand((l) => [
                  if (l.associatedExamId != null) l.associatedExamId!,
                  ...l.attachedExams.map((e) => e.examId),
                ])
            .toSet()
            .toList();
        double? chAvg;
        if (chExamIds.isNotEmpty) {
          final validAvgs = chExamIds
              .map((id) => examAvgMap[id])
              .whereType<double>()
              .toList();
          if (validAvgs.isNotEmpty) {
            chAvg = validAvgs.reduce((a, b) => a + b) / validAvgs.length;
          }
        }

        chapterMetrics.add(
          _ChapterMetricItem(
            chapterId: ch.id,
            title: ch.title,
            lessonCount: chLessons.length,
            completionRate: chRate,
            quizAvg: chAvg,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _totalActiveStudents = totalStudents;
          _totalCourseViews = totalViews;
          _overallCourseProgress = overallProgress;
          _overallQuizzesAverage = groupQuizAvg;
          _chapterMetrics = chapterMetrics;
          _studentsNeedingAttention = attentionList;
          _isLoading = false;
        });
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
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
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
                    Icons.insights_rounded,
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
                        l10n.groupAnalyticsDialogTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.groupName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

          // Body
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
                                onPressed: _loadGroupAnalytics,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Retry'),
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
                            // 4 Key Stats
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
                                      icon: Icons.groups_rounded,
                                      color: AppColors.primary,
                                    ),
                                    _buildMetricCard(
                                      title: l10n.courseWatchEngagement,
                                      value: '$_totalCourseViews',
                                      icon: Icons.play_circle_filled_rounded,
                                      color: const Color(0xFF0284C7),
                                    ),
                                    _buildMetricCard(
                                      title: l10n.overallCourseProgress,
                                      value: '$_overallCourseProgress%',
                                      icon: Icons.trending_up_rounded,
                                      color: AppColors.success,
                                    ),
                                    _buildMetricCard(
                                      title: l10n.overallQuizzesAverage,
                                      value: _overallQuizzesAverage != null
                                          ? '${_overallQuizzesAverage!.toStringAsFixed(0)}%'
                                          : '--',
                                      icon: Icons.military_tech_rounded,
                                      color: const Color(0xFFD97706),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: AppSpacing.s20),

                            // Chapter Progress Breakdown
                            AppCard(
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.bar_chart_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: AppSpacing.s8),
                                      Text(
                                        l10n.chapterBreakdown,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.s16),
                                  if (_chapterMetrics.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text(
                                        'No chapters created yet.',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    )
                                  else
                                    for (final chItem in _chapterMetrics)
                                      _buildChapterProgressRow(chItem, l10n),
                                ],
                              ),
                            ),

                            const SizedBox(height: AppSpacing.s20),

                            // Students Needing Attention
                            AppCard(
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 18,
                                        color: Color(0xFFEA580C),
                                      ),
                                      const SizedBox(width: AppSpacing.s8),
                                      Text(
                                        l10n.studentsNeedingAttention,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (_studentsNeedingAttention.isEmpty
                                                  ? AppColors.success
                                                  : const Color(0xFFEA580C))
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_studentsNeedingAttention.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _studentsNeedingAttention.isEmpty
                                                ? AppColors.success
                                                : const Color(0xFFEA580C),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.s12),
                                  if (_studentsNeedingAttention.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.all(AppSpacing.s12),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.success.withValues(alpha: 0.25),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.verified_rounded,
                                            color: AppColors.success,
                                            size: 20,
                                          ),
                                          const SizedBox(width: AppSpacing.s10),
                                          Expanded(
                                            child: Text(
                                              l10n.noStudentsNeedingAttention,
                                              style: const TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _studentsNeedingAttention.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final student = _studentsNeedingAttention[idx];
                                        return ListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          leading: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: AppColors.primary
                                                .withValues(alpha: 0.12),
                                            backgroundImage: student.avatarUrl != null
                                                ? NetworkImage(student.avatarUrl!)
                                                : null,
                                            child: student.avatarUrl == null
                                                ? Text(
                                                    student.name.isNotEmpty
                                                        ? student.name[0].toUpperCase()
                                                        : 'S',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      color: AppColors.primary,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          title: Text(
                                            student.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEA580C)
                                                  .withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFEA580C)
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              l10n.studentCompletionRate(
                                                  student.completionPercentage),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFEA580C),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
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

  Widget _buildChapterProgressRow(
    _ChapterMetricItem ch,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  ch.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                '${ch.completionRate}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (ch.quizAvg != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Quiz: ${ch.quizAvg!.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ch.completionRate / 100.0,
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                ch.completionRate >= 70
                    ? AppColors.success
                    : ch.completionRate >= 40
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFEA580C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
