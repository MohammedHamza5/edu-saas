import 'package:equatable/equatable.dart';

/// Student entity — domain layer, no JSON/Supabase dependencies.
/// status: pending | active | rejected | suspended
class StudentEntity extends Equatable {
  final String id;
  final String tenantId;
  final String fullName;
  final String email;
  final String? phone;
  final String? parentPhone;
  final String? avatarUrl;
  final String status; // pending | active | rejected | suspended
  final String role; // always 'student' here
  final DateTime? lastActivityAt;
  final DateTime? createdAt;

  const StudentEntity({
    required this.id,
    required this.tenantId,
    required this.fullName,
    required this.email,
    this.phone,
    this.parentPhone,
    this.avatarUrl,
    this.status = 'pending',
    this.role = 'student',
    this.lastActivityAt,
    this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  StudentEntity copyWith({
    String? id,
    String? tenantId,
    String? fullName,
    String? email,
    String? phone,
    String? parentPhone,
    String? avatarUrl,
    String? status,
    String? role,
    DateTime? lastActivityAt,
    DateTime? createdAt,
  }) {
    return StudentEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      parentPhone: parentPhone ?? this.parentPhone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      role: role ?? this.role,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      createdAt: createdAt ?? this.createdAt,
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
        role,
        lastActivityAt,
        createdAt,
      ];
}
