import 'package:equatable/equatable.dart';

enum UserRole { teacher, student, parent }

enum UserStatus { pending, active, rejected, suspended }

class UserEntity extends Equatable {
  final String id;
  final String tenantId;
  final UserRole role;
  final UserStatus status;
  final String fullName;
  final String email;
  final String? phone;
  final String? parentPhone;

  const UserEntity({
    required this.id,
    required this.tenantId,
    required this.role,
    required this.status,
    required this.fullName,
    required this.email,
    this.phone,
    this.parentPhone,
  });

  bool get isActive => status == UserStatus.active;
  bool get isPending => status == UserStatus.pending;
  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;
  bool get isParent => role == UserRole.parent;

  @override
  List<Object?> get props => [
        id,
        tenantId,
        role,
        status,
        fullName,
        email,
        phone,
        parentPhone,
      ];
}
