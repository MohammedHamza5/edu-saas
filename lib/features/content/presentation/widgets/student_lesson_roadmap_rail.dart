import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Vertical timeline connector rail linking lesson roadmap stations.
class StudentLessonRoadmapRail extends StatelessWidget {
  final int index;
  final bool isLast;
  final bool isCompleted;
  final bool isLocked;
  final Color statusAccentColor;

  const StudentLessonRoadmapRail({
    super.key,
    required this.index,
    required this.isLast,
    required this.isCompleted,
    required this.isLocked,
    required this.statusAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Column(
        children: [
          // Upper gap connecting from previous station
          Container(
            width: 2,
            height: 12,
            color: index == 1
                ? Colors.transparent
                : (isCompleted
                    ? AppColors.success.withAlpha(150)
                    : AppColors.border),
          ),
          // Node dot indicator
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.success
                  : isLocked
                      ? AppColors.error
                      : AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: statusAccentColor.withAlpha(120),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          // Lower connecting line extending to next station
          Expanded(
            child: Container(
              width: 2,
              color: isLast
                  ? Colors.transparent
                  : (isCompleted
                      ? AppColors.success.withAlpha(150)
                      : AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}
