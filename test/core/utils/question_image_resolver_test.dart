import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/config/app_config.dart';
import 'package:edu_saas/core/utils/question_image_resolver.dart';

void main() {
  group('QuestionImageResolver Tests', () {
    test('isImageUrl correctly identifies image URLs and relative storage paths', () {
      expect(QuestionImageResolver.isImageUrl('https://example.com/math.png'), isTrue);
      expect(QuestionImageResolver.isImageUrl('https://example.com/diagram.webp'), isTrue);
      expect(QuestionImageResolver.isImageUrl('crops/doc_1/q12.png'), isTrue);
      expect(QuestionImageResolver.isImageUrl('test/exam_images/12345.webp'), isTrue);
      expect(QuestionImageResolver.isImageUrl('/storage/v1/object/public/test.jpg'), isTrue);
      expect(QuestionImageResolver.isImageUrl('What is the value of x?'), isFalse);
      expect(QuestionImageResolver.isImageUrl(''), isFalse);
    });

    test('resolveUrl properly normalizes markdown, absolute, and relative paths', () {
      // Markdown image
      expect(
        QuestionImageResolver.resolveUrl('![Graph](https://cdn.example.com/sat/graph.png)'),
        equals('https://cdn.example.com/sat/graph.png'),
      );

      // Absolute URL
      expect(
        QuestionImageResolver.resolveUrl('https://my-bucket.com/img.png'),
        equals('https://my-bucket.com/img.png'),
      );

      // Question Bank crop
      expect(
        QuestionImageResolver.resolveUrl('crops/doc_99/q5.png'),
        equals('${AppConfig.supabaseUrl}/storage/v1/object/public/qb-documents/crops/doc_99/q5.png'),
      );

      // Dynamic uploaded exam image path in Supabase Storage
      expect(
        QuestionImageResolver.resolveUrl('test/exam_images/sample.webp'),
        equals('${AppConfig.supabaseUrl}/storage/v1/object/public/group-content/test/exam_images/sample.webp'),
      );

      // Bundled SAT static exam image
      expect(
        QuestionImageResolver.resolveUrl('exam_images/sat_12_q_012_27d075d8.png'),
        equals('https://antounios.web.app/exam_images/sat_12_q_012_27d075d8.png'),
      );

      // Null or empty
      expect(QuestionImageResolver.resolveUrl(null), isNull);
      expect(QuestionImageResolver.resolveUrl('  '), isNull);
    });

    test('resolveEffectiveImageUrl respects precedence', () {
      // 1. Explicit image URL
      expect(
        QuestionImageResolver.resolveEffectiveImageUrl(
          imageUrl: 'https://example.com/explicit.png',
          questionText: 'https://example.com/stem.png',
        ),
        equals('https://example.com/explicit.png'),
      );

      // 2. Question text contains image URL
      expect(
        QuestionImageResolver.resolveEffectiveImageUrl(
          imageUrl: null,
          questionText: 'https://example.com/stem.png',
        ),
        equals('https://example.com/stem.png'),
      );

      // 3. Question text contains markdown image
      expect(
        QuestionImageResolver.resolveEffectiveImageUrl(
          imageUrl: '',
          questionText: '![Geometry](https://example.com/triangle.png)',
        ),
        equals('https://example.com/triangle.png'),
      );

      // 4. Fallback to context diagram image
      expect(
        QuestionImageResolver.resolveEffectiveImageUrl(
          imageUrl: null,
          questionText: 'Refer to the figure below',
          contextImageUrl: 'test/exam_images/passage_diagram.webp',
        ),
        equals('${AppConfig.supabaseUrl}/storage/v1/object/public/group-content/test/exam_images/passage_diagram.webp'),
      );

      // 5. No image anywhere
      expect(
        QuestionImageResolver.resolveEffectiveImageUrl(
          imageUrl: null,
          questionText: 'Solve for y: 2y = 8',
          contextImageUrl: null,
        ),
        isNull,
      );
    });

    test('shouldShowQuestionText suppresses redundant metadata and raw image URLs', () {
      // Raw image URL as text should be suppressed
      expect(
        QuestionImageResolver.shouldShowQuestionText(
          'https://example.com/q.png',
          'https://example.com/q.png',
        ),
        isFalse,
      );

      // Markdown image as text should be suppressed
      expect(
        QuestionImageResolver.shouldShowQuestionText(
          '![Image](https://example.com/q.png)',
          'https://example.com/q.png',
        ),
        isFalse,
      );

      // Placeholder titles like "Question 12" should be suppressed if image is present
      expect(
        QuestionImageResolver.shouldShowQuestionText(
          'Question 12',
          'https://example.com/q.png',
        ),
        isFalse,
      );
      expect(
        QuestionImageResolver.shouldShowQuestionText(
          'سؤال 5',
          'https://example.com/q.png',
        ),
        isFalse,
      );

      // Normal question text should be displayed
      expect(
        QuestionImageResolver.shouldShowQuestionText(
          'In the figure above, what is the area of circle O?',
          'https://example.com/circle.png',
        ),
        isTrue,
      );

      // Question without image should display text
      expect(
        QuestionImageResolver.shouldShowQuestionText(
          'Question 12',
          null,
        ),
        isTrue,
      );
    });
  });
}
