import '../../domain/entities/child_entity.dart';

class ChildModel extends ChildEntity {
  const ChildModel({
    required super.id,
    required super.parentStudentId,
    required super.fullName,
    required super.email,
    super.phone,
    super.relationship,
    super.avatarUrl,
    required super.status,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    final userData = (json['users'] as Map<String, dynamic>?) ?? json;

    return ChildModel(
      id: userData['id'] as String? ?? json['student_id'] as String? ?? '',
      parentStudentId: json['id'] as String? ?? '',
      fullName: userData['full_name'] as String? ?? '',
      email: userData['email'] as String? ?? '',
      phone: userData['phone'] as String?,
      relationship: json['relationship'] as String?,
      avatarUrl: userData['avatar_url'] as String?,
      status: userData['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_student_id': parentStudentId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'relationship': relationship,
      'avatar_url': avatarUrl,
      'status': status,
    };
  }
}
