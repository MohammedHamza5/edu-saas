import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import 'teacher_cohorts_empty_card.dart';
import 'teacher_default_cohort_card.dart';
import 'teacher_group_cohort_card.dart';

/// Test preparation cohorts and study groups list view for the teacher dashboard.
class TeacherTestPrepCohortsList extends StatelessWidget {
  final GroupsState? groupsState;

  const TeacherTestPrepCohortsList({
    super.key,
    this.groupsState,
  });

  static const _palette = [
    Color(0xFF818CF8), // Indigo
    Color(0xFF2DD4BF), // Teal
    Color(0xFFFB7185), // Rose
    Color(0xFFA78BFA), // Purple
    Color(0xFFFBBF24), // Amber
  ];

  static const _defaultCohorts = [
    {
      'title': 'Digital SAT Master (Target 800)',
      'target': 'Digital SAT • August',
      'level': 'SAT Module 1 & 2 Hard',
      'members': '5 Students',
      'score': '740 / 800',
      'focus': 'Desmos Shortcuts + Advanced Quadratics & Circles',
      'color': Color(0xFF818CF8),
    },
    {
      'title': 'EST I & EST II Intensive',
      'target': 'Egyptian Universities • October EST',
      'level': 'EST Math I & II',
      'members': '5 Students',
      'score': '690 / 800',
      'focus': 'Coordinate Geometry & Exponential Modeling',
      'color': Color(0xFF2DD4BF),
    },
    {
      'title': 'ACT Math Sprint Drills',
      'target': 'ACT Speed • 45Q in 50M',
      'level': 'Time-Constrained Drills',
      'members': '5 Students',
      'score': '32 / 36',
      'focus': 'Trigonometry & Rapid Problem Solving',
      'color': Color(0xFFFB7185),
    },
    {
      'title': 'Advanced Math & Problem Solving',
      'target': 'Level 2 • High Scorers',
      'level': 'Algebra & Functions Mastery',
      'members': '5 Students',
      'score': '88% Mastery',
      'focus': 'Nonlinear equations & Systems',
      'color': Color(0xFFA78BFA),
    },
    {
      'title': 'Basics & Foundations Cohort',
      'target': 'Level 1 • Diagnostic',
      'level': 'Core Foundations',
      'members': '5 Students',
      'score': '82% Mastery',
      'focus': 'Linear Equations, Ratios, & Percentages',
      'color': Color(0xFFFBBF24),
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (groupsState is GroupsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (groupsState is GroupsLoaded) {
      final groups = (groupsState as GroupsLoaded).groups;
      if (groups.isEmpty) {
        return const TeacherCohortsEmptyCard();
      }

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
        itemBuilder: (context, i) {
          final group = groups[i];
          final color = _palette[i % _palette.length];
          return TeacherGroupCohortCard(
            group: group,
            color: color,
          );
        },
      );
    }

    // Default Academic Test Prep Cohorts (shown when groups are not loaded or in standalone previews)
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _defaultCohorts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
      itemBuilder: (context, i) {
        final cohort = _defaultCohorts[i];
        final color = cohort['color'] as Color;
        return TeacherDefaultCohortCard(
          cohort: cohort,
          color: color,
        );
      },
    );
  }
}
