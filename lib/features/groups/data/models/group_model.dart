import '../../domain/entities/group_entity.dart';

class GroupModel extends GroupEntity {
  const GroupModel({
    required super.id,
    required super.tenantId,
    required super.name,
    required super.level,
    super.description,
    super.previousContentAccess = 'deny',
    super.status = 'active',
    super.createdAt,
    super.updatedAt,
    super.membersCount = 0,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    int count = 0;
    if (json['group_members'] is List) {
      final list = json['group_members'] as List<dynamic>;
      if (list.isNotEmpty && list.first is Map && (list.first as Map).containsKey('count')) {
        count = (list.first as Map)['count'] as int? ?? 0;
      } else {
        count = list.length;
      }
    } else if (json['members_count'] is int) {
      count = json['members_count'] as int;
    }

    return GroupModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String? ?? '',
      name: json['name'] as String,
      level: json['level'] as String? ?? 'SAT',
      description: json['description'] as String?,
      previousContentAccess: json['previous_content_access'] as String? ?? 'deny',
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      membersCount: count,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'level': level,
      'description': description,
      'previous_content_access': previousContentAccess,
      'status': status,
    };
  }
}
