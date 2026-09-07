import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.tenantId,
    required super.role,
    required super.status,
    required super.fullName,
    required super.email,
    super.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'student';
    final statusStr = json['status'] as String? ?? 'pending';

    final role = switch (roleStr) {
      'teacher' => UserRole.teacher,
      'parent' => UserRole.parent,
      _ => UserRole.student,
    };

    final status = switch (statusStr) {
      'active' => UserStatus.active,
      'rejected' => UserStatus.rejected,
      'suspended' => UserStatus.suspended,
      _ => UserStatus.pending,
    };

    return UserModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      role: role,
      status: status,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'role': role.name,
      'status': status.name,
      'full_name': fullName,
      'email': email,
      'phone': phone,
    };
  }
}
