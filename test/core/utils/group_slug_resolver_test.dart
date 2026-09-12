import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/utils/group_slug_resolver.dart';

void main() {
  group('GroupSlugResolver Tests', () {
    test('resolves known group UUIDs to aesthetic slugs', () {
      expect(
        GroupSlugResolver.toSlug('22222222-2222-2222-2222-222222222222'),
        'sat-advanced',
      );
      expect(
        GroupSlugResolver.toSlug('33333333-3333-3333-3333-333333333333'),
        'est-foundation',
      );
      expect(
        GroupSlugResolver.toSlug('44444444-4444-4444-4444-444444444444'),
        'act-intensive',
      );
    });

    test('resolves slugs back to correct database UUIDs', () {
      expect(
        GroupSlugResolver.toId('sat-advanced'),
        '22222222-2222-2222-2222-222222222222',
      );
      expect(
        GroupSlugResolver.toId('est-foundation'),
        '33333333-3333-3333-3333-333333333333',
      );
      expect(
        GroupSlugResolver.toId('act-intensive'),
        '44444444-4444-4444-4444-444444444444',
      );
      expect(
        GroupSlugResolver.toId('sat-prep'),
        '22222222-2222-2222-2222-222222222222',
      );
    });

    test('falls back safely to original ID when unknown', () {
      const customId = 'custom-uuid-9999';
      expect(GroupSlugResolver.toId(customId), customId);
      expect(GroupSlugResolver.toSlug(customId), customId);
    });

    test('dynamically generates slugs from group names if not pre-registered', () {
      const newGroupId = 'new-group-1234';
      final slug = GroupSlugResolver.toSlug(newGroupId, 'Physics & Mechanics Level 1');
      expect(slug, 'physics-mechanics-level-1');
      expect(GroupSlugResolver.toId('physics-mechanics-level-1'), newGroupId);
    });
  });
}
