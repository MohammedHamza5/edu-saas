import 'package:equatable/equatable.dart';

class GroupEntity extends Equatable {
  final String id;
  final String tenantId;
  final String name;
  final String level;
  final String? description;
  final String previousContentAccess; // 'allow' or 'deny'
  final String status; // 'active' or 'archived'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int membersCount;
  final bool enforceSequentialLearning;
  final int defaultPassingScore;

  const GroupEntity({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.level,
    this.description,
    this.previousContentAccess = 'deny',
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.membersCount = 0,
    this.enforceSequentialLearning = true,
    this.defaultPassingScore = 60,
  });

  bool get isPreviousContentAllowed => previousContentAccess == 'allow';
  bool get isActive => status == 'active';

  GroupEntity copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? level,
    String? description,
    String? previousContentAccess,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? membersCount,
    bool? enforceSequentialLearning,
    int? defaultPassingScore,
  }) {
    return GroupEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      level: level ?? this.level,
      description: description ?? this.description,
      previousContentAccess:
          previousContentAccess ?? this.previousContentAccess,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      membersCount: membersCount ?? this.membersCount,
      enforceSequentialLearning: enforceSequentialLearning ?? this.enforceSequentialLearning,
      defaultPassingScore: defaultPassingScore ?? this.defaultPassingScore,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    name,
    level,
    description,
    previousContentAccess,
    status,
    createdAt,
    updatedAt,
    membersCount,
    enforceSequentialLearning,
    defaultPassingScore,
  ];
}
