import 'package:equatable/equatable.dart';

/// Question revision entity representing an immutable content snapshot (§7.1, §10).
class QuestionRevisionEntity extends Equatable {
  final String id;
  final String questionId;
  final String tenantId;
  final int revNo;
  final Map<String, dynamic> content;
  final Map<String, dynamic> answer;
  final Map<String, dynamic>? confidence;
  final Map<String, dynamic> provenance;
  final String contentHash;
  final String? createdBy;
  final String? createdVia;
  final String? editNote;
  final DateTime createdAt;

  const QuestionRevisionEntity({
    required this.id,
    required this.questionId,
    required this.tenantId,
    required this.revNo,
    required this.content,
    required this.answer,
    this.confidence,
    required this.provenance,
    required this.contentHash,
    this.createdBy,
    this.createdVia,
    this.editNote,
    required this.createdAt,
  });

  /// Extracts the stem text from all text and math blocks
  String get stemText {
    final stem = content['stem'];
    if (stem is List) {
      final parts = <String>[];
      for (final b in stem) {
        if (b is Map) {
          if (b['type'] == 'text') {
            parts.add(b['value']?.toString() ?? '');
          } else if (b['type'] == 'math') {
            parts.add('\$${b['latex'] ?? b['value'] ?? ''}\$');
          }
        }
      }
      return parts.join(' ').trim();
    }
    return '';
  }

  /// Ordered stem blocks (text, math, asset, table)
  List<Map<String, dynamic>> get stemBlocks {
    final stem = content['stem'];
    if (stem is List) {
      return stem.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Extracts MCQ options if present
  List<Map<String, dynamic>> get options {
    final opts = content['options'];
    if (opts is List) {
      return opts.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// Answer status ('unknown', 'ai_proposed', 'source_extracted', 'solver_verified', 'source_and_solver_agree', 'teacher_confirmed')
  String get answerStatus => answer['status']?.toString() ?? 'unknown';

  /// Answer key or normalized answer
  String? get answerKey =>
      answer['normalized']?.toString() ?? answer['raw']?.toString();

  /// Source references
  List<String> get sourceRefs {
    final refs = <String>{};
    for (final b in stemBlocks) {
      final s = b['source_refs'];
      if (s is List) {
        refs.addAll(s.map((e) => e.toString()));
      }
    }
    for (final o in options) {
      final s = o['source_refs'];
      if (s is List) {
        refs.addAll(s.map((e) => e.toString()));
      }
    }
    return refs.toList();
  }

  /// Confidence scores
  Map<String, dynamic> get confidenceMap {
    if (content['confidence'] is Map) {
      return content['confidence'] as Map<String, dynamic>;
    }
    return confidence ?? {};
  }

  /// Revision flags (e.g. ai_enriched, etc.)
  List<dynamic> get flags {
    final f = content['flags'];
    if (f is List) return f;
    final provFlags = provenance['flags'];
    if (provFlags is List) return provFlags;
    return const [];
  }

  QuestionRevisionEntity copyWith({
    String? id,
    String? questionId,
    String? tenantId,
    int? revNo,
    Map<String, dynamic>? content,
    Map<String, dynamic>? answer,
    Map<String, dynamic>? confidence,
    Map<String, dynamic>? provenance,
    String? contentHash,
    String? createdBy,
    String? createdVia,
    String? editNote,
    DateTime? createdAt,
  }) {
    return QuestionRevisionEntity(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      tenantId: tenantId ?? this.tenantId,
      revNo: revNo ?? this.revNo,
      content: content ?? this.content,
      answer: answer ?? this.answer,
      confidence: confidence ?? this.confidence,
      provenance: provenance ?? this.provenance,
      contentHash: contentHash ?? this.contentHash,
      createdBy: createdBy ?? this.createdBy,
      createdVia: createdVia ?? this.createdVia,
      editNote: editNote ?? this.editNote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    questionId,
    tenantId,
    revNo,
    content,
    answer,
    confidence,
    provenance,
    contentHash,
    createdBy,
    createdVia,
    editNote,
    createdAt,
  ];
}
