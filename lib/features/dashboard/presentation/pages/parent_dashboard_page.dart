import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/academic_hero_banner.dart';
import '../../../../core/widgets/animated_math_background.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/widgets/notification_badge_button.dart';
import '../../../parent/presentation/cubit/parent_cubit.dart';
import '../../../parent/presentation/cubit/parent_state.dart';
import '../../../parent/presentation/widgets/child_selector_bar.dart';
import '../../../parent/presentation/widgets/parent_academic_overview_card.dart';
import '../../../parent/presentation/widgets/parent_guidance_card.dart';
import '../../../parent/presentation/widgets/parent_recent_attendance_section.dart';
import '../../../parent/presentation/widgets/parent_recent_exams_section.dart';

class ParentDashboardPage extends StatelessWidget {
  final ParentCubit? cubit;

  const ParentDashboardPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider<ParentCubit>.value(
        value: cubit!,
        child: const _ParentDashboardView(),
      );
    }

    try {
      context.read<ParentCubit>();
      return const _ParentDashboardView();
    } catch (_) {
      return BlocProvider<ParentCubit>(
        create: (_) =>
            InjectionContainer.createParentCubit()..loadParentDashboard(),
        child: const _ParentDashboardView(),
      );
    }
  }
}

class _ParentDashboardView extends StatefulWidget {
  const _ParentDashboardView();

  @override
  State<_ParentDashboardView> createState() => _ParentDashboardViewState();
}

class _ParentDashboardViewState extends State<_ParentDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationsCubit>().loadNotifications();
      }
    });
  }

  Widget _buildSkeletonLoading() {
    return const AppLoadingView.dashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.parentDashboardTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refreshDashboard,
            onPressed: () => context.read<ParentCubit>().refresh(),
          ),
          NotificationBadgeButton(
            onPressed: () => context.push(AppRoutes.notificationsCenter),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: context.l10n.logout,
            onPressed: () {
              context.read<AuthCubit>().logout();
              context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: AnimatedMathBackground(
          opacity: 0.032,
          gridColor: const Color(0xFF6366F1),
          waveColor: const Color(0xFF38BDF8),
          gridSpacing: 38,
          showAxes: false,
          showWave: true,
          showFormulas: false,
          showNodes: false,
          cycleDuration: const Duration(seconds: 32),
          child: BlocBuilder<ParentCubit, ParentState>(
            builder: (context, state) {
              if (state is ParentLoading || state is ParentInitial) {
                return _buildSkeletonLoading();
              }

              if (state is ParentNoChildren) {
                return AppEmptyView(
                  icon: Icons.family_restroom_rounded,
                  message: context.l10n.parentNoChildrenLinked,
                  actionText: context.l10n.refreshDashboardButton,
                  onAction: () =>
                      context.read<ParentCubit>().loadParentDashboard(),
                );
              }

              if (state is ParentError) {
                return AppErrorView(
                  message: state.message,
                  onRetry: () =>
                      context.read<ParentCubit>().loadParentDashboard(),
                );
              }

              if (state is ParentLoaded) {
                return RefreshIndicator(
                  onRefresh: () => context.read<ParentCubit>().refresh(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: context.responsivePagePadding,
                    child: ResponsiveContainer(
                      maxWidth: ResponsiveBreakpoints.maxContentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Academic Hero Banner
                          AcademicHeroBanner(
                            title: context.l10n.academicOverviewTitle,
                            subtitle: context.l10n.childRecentActivity,
                            badgeText: context.l10n.roleParent,
                          ),
                          const SizedBox(height: AppSpacing.s16),

                          // P-02: Child Selector Bar
                          ChildSelectorBar(
                            children: state.children,
                            selectedChild: state.selectedChild,
                            onChildSelected: (child) {
                              context.read<ParentCubit>().selectChild(child);
                            },
                          ),

                          const SizedBox(height: AppSpacing.s16),

                          if (state.isLoadingSummary)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.s32,
                              ),
                              child: Center(
                                child: AppLoadingView.signature(size: 60),
                              ),
                            )
                          else if (state.summary != null) ...[
                            // P-01 & P-03: Academic Overview Cards
                            ParentAcademicOverviewCard(summary: state.summary!),

                            const SizedBox(height: AppSpacing.s20),

                            // P-06: Recent Attendance Section
                            ParentRecentAttendanceSection(
                              records: state.summary!.recentAttendance,
                            ),

                            const SizedBox(height: AppSpacing.s20),

                            // P-05: Exam Results Section
                            ParentRecentExamsSection(
                              exams: state.summary!.recentExams,
                            ),

                            const SizedBox(height: AppSpacing.s20),

                            // Guidance Information Card
                            const ParentGuidanceCard(),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
