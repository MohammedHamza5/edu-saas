import '../../domain/entities/student_profile_entity.dart';

class EnrolledGroupSummaryModel extends EnrolledGroupSummary {
  const EnrolledGroupSummaryModel({
    required super.id,
    required super.name,
    required super.level,
  });

  factory EnrolledGroupSummaryModel.fromJson(Map<String, dynamic> json) {
    return EnrolledGroupSummaryModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      level: json['level'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
      };
}

class StudentProfileModel extends StudentProfileEntity {
  const StudentProfileModel({
    required super.id,
    required super.tenantId,
    required super.fullName,
    required super.email,
    super.phone,
    super.parentPhone,
    super.avatarUrl,
    super.status = 'active',
    super.createdAt,
    super.enrolledGroups = const [],
  });

  factory StudentProfileModel.fromJson(
    Map<String, dynamic> userMap, {
    List<Map<String, dynamic>> groupsList = const [],
  }) {
    final groups = groupsList
        .map((g) => EnrolledGroupSummaryModel.fromJson(g))
        .toList();

    return StudentProfileModel(
      id: userMap['id'] as String? ?? '',
      tenantId: userMap['tenant_id'] as String? ?? '',
      fullName: userMap['full_name'] as String? ?? '',
      email: userMap['email'] as String? ?? '',
      phone: userMap['phone'] as String?,
      parentPhone: userMap['parent_phone'] as String?,
      avatarUrl: userMap['avatar_url'] as String?,
      status: userMap['status'] as String? ?? 'active',
      createdAt: userMap['created_at'] != null
          ? DateTime.tryParse(userMap['created_at'] as String)
          : null,
      enrolledGroups: groups,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'parent_phone': parentPhone,
        'avatar_url': avatarUrl,
        'status': status,
        'created_at': createdAt?.toIso8601String(),
      };
}
