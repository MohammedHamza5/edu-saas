import 'package:equatable/equatable.dart';

/// تمثيل مجلد تنظيمي للاختبارات (Exam Folder / Category)
class ExamFolderEntity extends Equatable {
  final String id;
  final String tenantId;
  final String name;
  final String? description;
  final String color;
  final String icon;
  final int sortOrder;
  final int examCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExamFolderEntity({
    required this.id,
    required this.tenantId,
    required this.name,
    this.description,
    this.color = '#5B4FE0',
    this.icon = 'folder',
    this.sortOrder = 0,
    this.examCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  ExamFolderEntity copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? description,
    String? color,
    String? icon,
    int? sortOrder,
    int? examCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExamFolderEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      examCount: examCount ?? this.examCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    name,
    description,
    color,
    icon,
    sortOrder,
    examCount,
    createdAt,
    updatedAt,
  ];
}
