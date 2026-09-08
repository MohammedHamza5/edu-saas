import '../../domain/entities/group_member_entity.dart';

class GroupMemberModel extends GroupMemberEntity {
  const GroupMemberModel({
    required super.id,
    required super.groupId,
    required super.studentId,
    required super.studentName,
    super.studentEmail,
    super.studentPhone,
    required super.joinedAt,
    super.status = 'active',
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    String studentName = 'طالب';
    String? email;
    String? phone;

    if (json['users'] is Map) {
      final userMap = json['users'] as Map<String, dynamic>;
      studentName = userMap['full_name'] as String? ?? studentName;
      email = userMap['email'] as String?;
      phone = userMap['phone'] as String?;
    } else if (json['student_name'] is String) {
      studentName = json['student_name'] as String;
    }

    return GroupMemberModel(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      studentId: json['student_id'] as String,
      studentName: studentName,
      studentEmail: email,
      studentPhone: phone,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
      status: json['status'] as String? ?? 'active',
    );
  }
}
