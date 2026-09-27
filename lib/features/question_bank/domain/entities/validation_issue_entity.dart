import 'package:equatable/equatable.dart';

/// Validation issue entity for review console (§9 Rule Catalog).
class ValidationIssueEntity extends Equatable {
  final String id;
  final String ruleId;
  final String severity; // 'BLOCKER' | 'WARN' | 'INFO'
  final String? blockRef;
  final Map<String, dynamic> message; // {'en': '...', 'ar': '...'}
  final String? resolvableBy; // 'edit' | 'confirm' | 'none'
  final String? resolvedBy;
  final DateTime? resolvedAt;

  const ValidationIssueEntity({
    required this.id,
    required this.ruleId,
    required this.severity,
    this.blockRef,
    required this.message,
    this.resolvableBy,
    this.resolvedBy,
    this.resolvedAt,
  });

  bool get isBlocker => severity == 'BLOCKER';
  bool get isResolved => resolvedAt != null;

  String getLocalizedMessage(String langCode) {
    if (message.containsKey(langCode)) {
      return message[langCode]?.toString() ?? '';
    }
    return message['en']?.toString() ?? message['ar']?.toString() ?? ruleId;
  }

  @override
  List<Object?> get props => [
    id,
    ruleId,
    severity,
    blockRef,
    message,
    resolvableBy,
    resolvedBy,
    resolvedAt,
  ];
}
