import 'package:equatable/equatable.dart';

class GroupMemberEntity extends Equatable {
  final String id;
  final String groupId;
  final String studentId;
  final String studentName;
  final String? studentEmail;
  final String? studentPhone;
  final DateTime joinedAt;
  final String status; // 'active' or 'removed'

  const GroupMemberEntity({
    required this.id,
    required this.groupId,
    required this.studentId,
    required this.studentName,
    this.studentEmail,
    this.studentPhone,
    required this.joinedAt,
    this.status = 'active',
  });

  bool get isActive => status == 'active';

  @override
  List<Object?> get props => [
    id,
    groupId,
    studentId,
    studentName,
    studentEmail,
    studentPhone,
    joinedAt,
    status,
  ];
}
