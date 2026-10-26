import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/tenant_registry.dart';
import '../../../../core/config/tenant_resolver.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/tenant_branding.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/widgets/academic_hero_banner.dart';
import '../widgets/academy_profile_settings_section.dart';
import '../widgets/language_settings_section.dart';
import '../widgets/streaming_provider_settings_section.dart';
import '../widgets/teacher_account_security_section.dart';

/// صفحة إعدادات المنصة والأكاديمية للمعلم (Teacher & Academy Settings)
/// مخصصة لإدارة بيانات الأكاديمية، لغة المنصة، وبيانات حساب المعلم.
/// ملتزمة بقاعدة "ثيم أكاديمي موحد واحد فقط" دون خيارات تبديل ثيمات أو دارك مود.
class TeacherSettingsPage extends StatefulWidget {
  const TeacherSettingsPage({super.key});

  @override
  State<TeacherSettingsPage> createState() => _TeacherSettingsPageState();
}

class _TeacherSettingsPageState extends State<TeacherSettingsPage> {
  late final TextEditingController _academyNameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _taglineController;
  late final TextEditingController _supportPhoneController;
  late final TextEditingController _supportEmailController;

  bool _isSaving = false;
  late String _selectedVideoProvider;

  @override
  void initState() {
    super.initState();
    final tenantId =
        SupabaseService.currentTenantId ?? TenantResolver.resolveTenantId();
    final branding = TenantRegistry.resolve(tenantId);

    _academyNameController = TextEditingController(text: branding.brandName);
    _subjectController = TextEditingController(text: branding.subjectTitle);
    _taglineController = TextEditingController(text: branding.tagline);
    _supportPhoneController = TextEditingController(
      text: branding.supportPhone ?? '',
    );
    _supportEmailController = TextEditingController(
      text: branding.supportEmail ?? '',
    );
    _selectedVideoProvider = branding.videoProvider;
    _loadTenantProvider();
  }

  Future<void> _loadTenantProvider() async {
    try {
      final tenantId = SupabaseService.currentTenantId ??
          TenantResolver.resolveTenantId();
      final res = await InjectionContainer.settingsRepository.getTenantSettings(tenantId);
      final row = res.when(
        onSuccess: (data) => data,
        onFailure: (_) => null,
      );
      if (row != null && mounted) {
        if (row['video_provider'] != null) {
          final prov = row['video_provider'] as String;
          setState(() {
            _selectedVideoProvider = prov;
          });
          final updated = TenantRegistry.resolve(tenantId).copyWith(
            videoProvider: prov,
          );
          TenantRegistry.register(updated);
          try {
            context.read<TenantThemeCubit>().setBranding(updated);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _academyNameController.dispose();
    _subjectController.dispose();
    _taglineController.dispose();
    _supportPhoneController.dispose();
    _supportEmailController.dispose();
    super.dispose();
  }

  void _handleSaveAcademyProfile() {
    setState(() => _isSaving = true);

    final tenantId =
        SupabaseService.currentTenantId ?? TenantResolver.resolveTenantId();
    final currentBranding = TenantRegistry.resolve(tenantId);
    final updatedBranding = TenantBranding.fromPrimary(
      tenantId: currentBranding.tenantId,
      brandName: _academyNameController.text.trim(),
      brandNameEn: currentBranding.brandNameEn,
      teacherName: currentBranding.teacherName,
      teacherNameEn: currentBranding.teacherNameEn,
      subjectTitle: _subjectController.text.trim(),
      subjectTitleEn: currentBranding.subjectTitleEn,
      academicTrack: currentBranding.academicTrack,
      academicTrackEn: currentBranding.academicTrackEn,
      tagline: _taglineController.text.trim(),
      taglineEn: currentBranding.taglineEn,
      primaryColor: currentBranding.primaryColor,
      supportPhone: _supportPhoneController.text.trim(),
      supportEmail: _supportEmailController.text.trim(),
      videoProvider: _selectedVideoProvider,
    );

    // Register in tenant registry and update theme cubit
    TenantRegistry.register(updatedBranding);
    try {
      context.read<TenantThemeCubit>().setBranding(updatedBranding);
    } catch (_) {}

    // Also persist video provider if changed
    try {
      InjectionContainer.settingsRepository.updateTenantVideoProvider(_selectedVideoProvider);
    } catch (_) {}

    setState(() => _isSaving = false);

    if (mounted) {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'تم حفظ وتحديث بيانات الأكاديمية بنجاح'
                : 'Academy profile updated successfully',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.settingsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: isAr ? 'رجوع' : 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.teacherDashboard);
            }
          },
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Academic Hero Banner
            AcademicHeroBanner(
              title: l10n.settingsTitle,
              subtitle: l10n.settingsSubtitle,
              trailing: Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.settings_suggest_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // 2. Section: Academy & Platform Profile
            AcademyProfileSettingsSection(
              academyNameController: _academyNameController,
              subjectController: _subjectController,
              taglineController: _taglineController,
              supportPhoneController: _supportPhoneController,
              supportEmailController: _supportEmailController,
              isSaving: _isSaving,
              onSave: _handleSaveAcademyProfile,
            ),
            const SizedBox(height: AppSpacing.s24),

            // 3. Section: Video Streaming Provider (Bunny Stream vs YouTube)
            const StreamingProviderSettingsSection(),
            const SizedBox(height: AppSpacing.s24),

            // 4. Section: Language Preference (Arabic / English)
            const LanguageSettingsSection(),
            const SizedBox(height: AppSpacing.s24),

            // 5. Section: Teacher Account & Security
            const TeacherAccountSecuritySection(),
            const SizedBox(height: AppSpacing.s40),
          ],
        ),
      ),
    );
  }
}
