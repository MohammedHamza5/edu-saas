import '../../domain/entities/exam_folder_entity.dart';

class ExamFolderModel extends ExamFolderEntity {
  const ExamFolderModel({
    required super.id,
    required super.tenantId,
    super.groupId,
    required super.name,
    super.description,
    super.color = '#5B4FE0',
    super.icon = 'folder',
    super.sortOrder = 0,
    super.examCount = 0,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ExamFolderModel.fromJson(Map<String, dynamic> json) {
    int parsedExamCount = 0;
    if (json['exam_count'] != null) {
      parsedExamCount = (json['exam_count'] as num).toInt();
    } else if (json['exams_count'] != null) {
      parsedExamCount = (json['exams_count'] as num).toInt();
    } else if (json['exams'] is List) {
      final list = json['exams'] as List<dynamic>;
      if (list.isNotEmpty && list.first is Map) {
        parsedExamCount = ((list.first as Map)['count'] as num?)?.toInt() ?? list.length;
      } else {
        parsedExamCount = list.length;
      }
    }

    return ExamFolderModel(
      id: json['id']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? '',
      groupId: json['group_id']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      color: json['color']?.toString() ?? '#5B4FE0',
      icon: json['icon']?.toString() ?? 'folder',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      examCount: parsedExamCount,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      if (groupId != null) 'group_id': groupId,
      'name': name,
      if (description != null) 'description': description,
      'color': color,
      'icon': icon,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
