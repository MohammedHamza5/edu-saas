import 'package:equatable/equatable.dart';

/// Group summary entity for displaying student's enrolled cohorts
class EnrolledGroupSummary extends Equatable {
  final String id;
  final String name;
  final String level;

  const EnrolledGroupSummary({
    required this.id,
    required this.name,
    required this.level,
  });

  @override
  List<Object?> get props => [id, name, level];
}

/// Pure domain entity representing the complete student profile
class StudentProfileEntity extends Equatable {
  final String id;
  final String tenantId;
  final String fullName;
  final String email;
  final String? phone;
  final String? parentPhone;
  final String? avatarUrl;
  final String status;
  final DateTime? createdAt;
  final List<EnrolledGroupSummary> enrolledGroups;

  const StudentProfileEntity({
    required this.id,
    required this.tenantId,
    required this.fullName,
    required this.email,
    this.phone,
    this.parentPhone,
    this.avatarUrl,
    this.status = 'active',
    this.createdAt,
    this.enrolledGroups = const [],
  });

  bool get isActive => status == 'active';

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  StudentProfileEntity copyWith({
    String? id,
    String? tenantId,
    String? fullName,
    String? email,
    String? phone,
    String? parentPhone,
    String? avatarUrl,
    String? status,
    DateTime? createdAt,
    List<EnrolledGroupSummary>? enrolledGroups,
  }) {
    return StudentProfileEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      parentPhone: parentPhone ?? this.parentPhone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      enrolledGroups: enrolledGroups ?? this.enrolledGroups,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        fullName,
        email,
        phone,
        parentPhone,
        avatarUrl,
        status,
        createdAt,
        enrolledGroups,
      ];
}
