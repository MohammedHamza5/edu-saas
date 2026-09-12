/// Utility class to map group UUIDs to clean, human-readable URL slugs
/// (e.g. 'sat-advanced' instead of '22222222-2222-2222-2222-222222222222').
class GroupSlugResolver {
  GroupSlugResolver._();

  static final Map<String, String> _idToSlug = {
    '22222222-2222-2222-2222-222222222222': 'sat-advanced',
    '33333333-3333-3333-3333-333333333333': 'est-foundation',
    '44444444-4444-4444-4444-444444444444': 'act-intensive',
  };

  static final Map<String, String> _slugToId = {
    'sat-advanced': '22222222-2222-2222-2222-222222222222',
    'est-foundation': '33333333-3333-3333-3333-333333333333',
    'act-intensive': '44444444-4444-4444-4444-444444444444',
    // Fallback aliases
    'sat-prep': '22222222-2222-2222-2222-222222222222',
    'sat': '22222222-2222-2222-2222-222222222222',
    'est-prep': '33333333-3333-3333-3333-333333333333',
    'est': '33333333-3333-3333-3333-333333333333',
    'act-prep': '44444444-4444-4444-4444-444444444444',
    'act': '44444444-4444-4444-4444-444444444444',
  };

  /// Converts a group UUID to an aesthetic URL slug
  static String toSlug(String groupId, [String? groupName]) {
    if (_idToSlug.containsKey(groupId)) {
      return _idToSlug[groupId]!;
    }
    if (groupName != null && groupName.trim().isNotEmpty) {
      final slug = groupName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      if (slug.isNotEmpty) {
        _idToSlug[groupId] = slug;
        _slugToId[slug] = groupId;
        return slug;
      }
    }
    return groupId;
  }

  /// Resolves an aesthetic URL slug back to its database UUID
  static String toId(String slugOrId) {
    return _slugToId[slugOrId] ?? slugOrId;
  }

  /// Registers a runtime mapping between a UUID and a custom slug
  static void register(String groupId, String slug) {
    _idToSlug[groupId] = slug;
    _slugToId[slug] = groupId;
  }
}
