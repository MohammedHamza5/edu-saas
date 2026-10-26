import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/tenant_registry.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../../../core/utils/group_slug_resolver.dart';
import '../../../../core/widgets/academic_hero_banner.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/widgets/notification_badge_button.dart';
import '../cubit/student_dashboard_cubit.dart';
import '../cubit/student_dashboard_state.dart';
import '../widgets/academic_performance_card.dart';
import '../widgets/continue_learning_card.dart';
import '../widgets/student_enrolled_courses_section.dart';
import '../widgets/student_quick_study_hub.dart';
import '../widgets/urgent_tasks_radar_card.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  List<GroupEntity> _enrolledCourses = [];
  bool _isLoadingCourses = true;

  @override
  void initState() {
    super.initState();
    // 1. Resolve initial groups from user-scoped cache immediately (0ms render)
    final cached = AppCache.groups.getStale(AppCache.userKey('groups'));
    if (cached is List<GroupEntity> && cached.isNotEmpty) {
      _enrolledCourses = cached;
      _isLoadingCourses = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _triggerInitialLoads();
      }
    });
  }

  void _triggerInitialLoads() {
    if (!mounted) return;
    try {
      context.read<NotificationsCubit>().loadNotifications();
      final authState = context.read<AuthCubit>().state;
      final studentId = (authState is AuthAuthenticated)
          ? authState.user.id
          : AppCache.currentUserId;

      if (studentId != null && studentId.isNotEmpty) {
        final dashState = context.read<StudentDashboardCubit>().state;
        if (dashState is! StudentDashboardLoaded) {
          context.read<StudentDashboardCubit>().loadDashboardStats(studentId);
        }
      }
      _loadEnrolledCourses();
    } catch (_) {}
  }

  Future<void> _loadEnrolledCourses({bool forceRefresh = false}) async {
    // If already populated and not forcing refresh, avoid duplicate work
    if (!forceRefresh && _enrolledCourses.isNotEmpty) {
      if (mounted && _isLoadingCourses) {
        setState(() => _isLoadingCourses = false);
      }
      return;
    }

    // Check GroupsCubit state safely (may not be present in isolated widget tests)
    try {
      final groupsCubit = context.read<GroupsCubit>();
      final groupsState = groupsCubit.state;
      if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
        if (mounted) {
          setState(() {
            _enrolledCourses = groupsState.groups;
            _isLoadingCourses = false;
          });
        }
        return;
      }
      await groupsCubit.loadGroups();
      if (mounted) {
        final updatedState = groupsCubit.state;
        if (updatedState is GroupsLoaded) {
          setState(() {
            _enrolledCourses = updatedState.groups;
            _isLoadingCourses = false;
          });
          return;
        }
      }
      if (mounted) {
        setState(() => _isLoadingCourses = false);
      }
      return;
    } catch (_) {
      // GroupsCubit may not be provided in isolated test trees
    }

    try {
      final res = await InjectionContainer.groupsRepository.getGroups();
      if (mounted) {
        setState(() {
          _enrolledCourses = res.dataOrNull ?? [];
          _isLoadingCourses = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCourses = false);
      }
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.logoutDialogTitle),
        content: Text(context.l10n.confirmLogoutStudent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthCubit>().logout();
              context.go(AppRoutes.login);
            },
            child: Text(context.l10n.logout),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOpenContent(
    BuildContext context, [
    List<GroupEntity>? fallbackGroups,
  ]) async {
    final groups = _enrolledCourses.isNotEmpty
        ? _enrolledCourses
        : (fallbackGroups ?? []);

    if (groups.isNotEmpty) {
      final g = groups.first;
      final slug = GroupSlugResolver.toSlug(g.id, g.name);
      context.go(
        AppRoutes.studentGroupContent.replaceAll(':groupId', slug),
        extra: g.name,
      );
      return;
    }

    // Direct fetch if empty
    final result = await InjectionContainer.groupsRepository.getGroups();
    if (!context.mounted) return;

    final fetched = result.dataOrNull ?? [];
    if (!result.isSuccess || fetched.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.studentNoGroupsAssigned),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }

    final g = fetched.first;
    final slug = GroupSlugResolver.toSlug(g.id, g.name);
    context.go(
      AppRoutes.studentGroupContent.replaceAll(':groupId', slug),
      extra: g.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.studentDashboardHeader(branding.brandName)),
        actions: [
          NotificationBadgeButton(
            onPressed: () => context.go(AppRoutes.studentNotifications),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: context.l10n.logout,
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, authState) {
          if (authState is AuthAuthenticated) {
            _triggerInitialLoads();
          }
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: child,
              ),
            );
          },
          child: BlocBuilder<StudentDashboardCubit, StudentDashboardState>(
            buildWhen: (previous, current) => previous != current,
            builder: (context, dashboardState) {
              if (dashboardState is StudentDashboardInitial) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _triggerInitialLoads();
                });
                return const Center(child: AppLoadingView.signature());
              }

              if (dashboardState is StudentDashboardLoading) {
                return const Center(child: AppLoadingView.signature());
              }

              if (dashboardState is StudentDashboardError) {
                return Center(
                  child: Text(
                    dashboardState.message,
                    style: const TextStyle(color: AppColors.error),
                  ),
                );
              }

              final stats = (dashboardState as StudentDashboardLoaded).stats;

              return RefreshIndicator(
                onRefresh: () async {
                  final authState = context.read<AuthCubit>().state;
                  final dashboardCubit = context.read<StudentDashboardCubit>();
                  if (authState is AuthAuthenticated) {
                    await Future.wait([
                      dashboardCubit.loadDashboardStats(
                        authState.user.id,
                        forceRefresh: true,
                      ),
                      _loadEnrolledCourses(),
                    ]);
                  }
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: context.responsivePagePadding,
                  child: ResponsiveContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Academic Hero Banner
                        AcademicHeroBanner(
                          title: context.l10n.welcomeStudentHeader(
                            branding.localizedBrandName(context),
                          ),
                          subtitle: context.l10n.studentHeroSubtitle(
                            branding.localizedTeacherName(context),
                            branding.localizedAcademicTrack(context),
                          ),
                          academicTrack: branding.localizedAcademicTrack(
                            context,
                          ),
                          badgeText: stats.activeGroupName != 'No Active Group'
                              ? stats.activeGroupName
                              : context.l10n.americanMathAcademy,
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // 2. Continue Learning Hero Card (If student has a lecture in progress)
                        if (stats.continueLearningItem != null) ...[
                          ContinueLearningCard(
                            item: stats.continueLearningItem!,
                          ),
                          const SizedBox(height: AppSpacing.s16),
                        ],

                        // 3. Urgent Tasks & Deadlines Radar
                        UrgentTasksRadarCard(tasks: stats.urgentTasks),
                        const SizedBox(height: AppSpacing.s16),

                        // 4. Academic Performance Summary (Sigma Badge)
                        AcademicPerformanceCard(stats: stats),
                        const SizedBox(height: AppSpacing.s20),

                        // 5. My Lectures & Groups Section
                        StudentEnrolledCoursesSection(
                          courses: _enrolledCourses.isNotEmpty
                              ? _enrolledCourses
                              : stats.enrolledGroups,
                          isLoading: _isLoadingCourses,
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        // 6. Fast Navigation Hub (Quick Study Cards)
                        StudentQuickStudyHub(
                          onOpenLectures: () => _handleOpenContent(
                            context,
                            stats.enrolledGroups,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
