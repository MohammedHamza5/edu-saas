import 'package:equatable/equatable.dart';
import '../../../auth/domain/entities/user_entity.dart';
import 'tenant_entity.dart';

class ProvisionTenantParams extends Equatable {
  final String tenantName;
  final String? tenantEmail;
  final String? tenantPhone;
  final String? logoUrl;
  final String teacherFullName;
  final String teacherEmail;
  final String teacherPassword;
  final String? teacherPhone;

  const ProvisionTenantParams({
    required this.tenantName,
    this.tenantEmail,
    this.tenantPhone,
    this.logoUrl,
    required this.teacherFullName,
    required this.teacherEmail,
    required this.teacherPassword,
    this.teacherPhone,
  });

  @override
  List<Object?> get props => [
        tenantName,
        tenantEmail,
        tenantPhone,
        logoUrl,
        teacherFullName,
        teacherEmail,
        teacherPassword,
        teacherPhone,
      ];
}

class OnboardingResult extends Equatable {
  final TenantEntity tenant;
  final UserEntity teacher;

  const OnboardingResult({
    required this.tenant,
    required this.teacher,
  });

  @override
  List<Object?> get props => [tenant, teacher];
}
