import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/responsive_container.dart';

/// Layout coordinator that switches between Wide Desktop Academic Theater (Row)
/// and Mobile/Tablet Stacked (Column) layouts.
class VideoPlayerContentView extends StatelessWidget {
  final Widget videoPlayer;
  final Widget navigationBar;
  final Widget academicPanel;

  const VideoPlayerContentView({
    super.key,
    required this.videoPlayer,
    required this.navigationBar,
    required this.academicPanel,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktopTheater = constraints.maxWidth >= 960;

          if (isDesktopTheater) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        videoPlayer,
                        navigationBar,
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s20),
                  Expanded(
                    flex: 3,
                    child: academicPanel,
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                videoPlayer,
                navigationBar,
                const SizedBox(height: AppSpacing.s12),
                academicPanel,
              ],
            ),
          );
        },
      ),
    );
  }
}
