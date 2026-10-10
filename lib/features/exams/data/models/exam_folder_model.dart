import '../../domain/entities/exam_folder_entity.dart';

class ExamFolderModel extends ExamFolderEntity {
  const ExamFolderModel({
    required super.id,
    required super.tenantId,
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
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      color: json['color'] as String? ?? '#5B4FE0',
      icon: json['icon'] as String? ?? 'folder',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      examCount: parsedExamCount,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
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
