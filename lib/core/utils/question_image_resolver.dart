import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Centralized, production-grade image resolution engine for exam questions,
/// question bank revisions, and student mistake practice cards.
///
/// Solves:
/// 1. Markdown image syntax extraction (`![alt](url)`).
/// 2. Raw URL detection in question stem text.
/// 3. Relative Supabase Storage paths (`crops/...`, `test/exam_images/...`, `qb-documents/...`).
/// 4. Suppression of redundant or placeholder stem text when an image represents the entire question.
class QuestionImageResolver {
  QuestionImageResolver._();

  static final RegExp _markdownImageRegex = RegExp(
    r'^!\[(.*?)\]\((https?://[^\)]+|\S+)\)$',
  );

  /// Checks if a string is an image URL (absolute or relative storage path).
  static bool isImageUrl(String str) {
    final lower = str.trim().toLowerCase();
    if (lower.isEmpty) return false;

    // Direct HTTP/HTTPS image URL
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return lower.contains('.png') ||
          lower.contains('.jpg') ||
          lower.contains('.jpeg') ||
          lower.contains('.webp') ||
          lower.contains('.gif') ||
          lower.contains('/storage/v1/object/') ||
          lower.contains('/exam_images/') ||
          lower.contains('/crops/');
    }

    // Relative storage paths
    if (lower.startsWith('crops/') ||
        lower.startsWith('qb-documents/') ||
        lower.startsWith('test/exam_images/') ||
        lower.startsWith('exam_images/') ||
        lower.startsWith('/crops/') ||
        lower.startsWith('/test/exam_images/')) {
      return true;
    }

    // Common image extensions alone
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  /// Normalizes and resolves any relative or partial storage path into an absolute URL.
  static String? resolveUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Check for markdown image format ![alt](url)
    final mdMatch = _markdownImageRegex.firstMatch(trimmed);
    if (mdMatch != null) {
      final innerUrl = mdMatch.group(2);
      if (innerUrl != null && innerUrl.isNotEmpty) {
        return resolveUrl(innerUrl);
      }
    }

    // Already an absolute HTTP/HTTPS URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    var clean = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;

    // Question Bank crops and documents
    if (clean.startsWith('crops/') || clean.startsWith('qb-documents/')) {
      if (clean.startsWith('qb-documents/')) {
        clean = clean.substring('qb-documents/'.length);
      }
      return '${AppConfig.supabaseUrl}/storage/v1/object/public/qb-documents/$clean';
    }

    // Static web exam images (e.g. bundled SAT / ACT diagrams under web/exam_images/)
    if (clean.startsWith('exam_images/')) {
      if (kIsWeb) {
        return '/$clean';
      } else {
        return 'https://antounios.web.app/$clean';
      }
    }

    // Dynamic uploaded exam images in Supabase Storage group-content
    if (clean.startsWith('test/exam_images/') ||
        clean.startsWith('group-content/')) {
      if (clean.startsWith('group-content/')) {
        clean = clean.substring('group-content/'.length);
      }
      return '${AppConfig.supabaseUrl}/storage/v1/object/public/group-content/$clean';
    }

    // Fallback if it has a direct image extension
    if (clean.endsWith('.webp') ||
        clean.endsWith('.png') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg')) {
      return '${AppConfig.supabaseUrl}/storage/v1/object/public/group-content/test/exam_images/$clean';
    }

    return trimmed;
  }

  /// Extracts the effective image URL from question properties in precedence order.
  static String? resolveEffectiveImageUrl({
    String? imageUrl,
    String? questionText,
    String? contextImageUrl,
  }) {
    // 1. Explicit imageUrl on question
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      final resolved = resolveUrl(imageUrl.trim());
      if (resolved != null && resolved.isNotEmpty) return resolved;
    }

    // 2. Question text contains or is an image URL or markdown
    if (questionText != null && questionText.trim().isNotEmpty) {
      final trimmedText = questionText.trim();
      final mdMatch = _markdownImageRegex.firstMatch(trimmedText);
      if (mdMatch != null) {
        final innerUrl = mdMatch.group(2);
        return resolveUrl(innerUrl);
      }
      if (isImageUrl(trimmedText)) {
        return resolveUrl(trimmedText);
      }
    }

    // 3. Fallback to context/passage diagram image if present
    if (contextImageUrl != null && contextImageUrl.trim().isNotEmpty) {
      return resolveUrl(contextImageUrl.trim());
    }

    return null;
  }

  /// Determines if the questionText should be rendered as visible text.
  static bool shouldShowQuestionText(
    String? questionText,
    String? effectiveImageUrl,
  ) {
    if (questionText == null) return false;
    final trimmed = questionText.trim();
    if (trimmed.isEmpty) return false;

    // If text is literally an image URL or markdown image, don't render it as raw text
    if (isImageUrl(trimmed)) return false;
    if (_markdownImageRegex.hasMatch(trimmed)) return false;

    // If an image is present, ignore generic metadata placeholders
    if (effectiveImageUrl != null && effectiveImageUrl.isNotEmpty) {
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('question ') ||
          trimmed.startsWith('سؤال ') ||
          lower == 'q' ||
          trimmed == 'س') {
        return false;
      }
    }

    return true;
  }
}
