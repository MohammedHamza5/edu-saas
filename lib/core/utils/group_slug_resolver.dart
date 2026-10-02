import 'cache_manager.dart';

/// Utility class to map group UUIDs to clean, human-readable URL slugs
/// (e.g. 'sat-advanced' instead of '22222222-2222-2222-2222-222222222222').
class GroupSlugResolver {
  GroupSlugResolver._();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

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

  /// Checks whether a given string is a valid standard RFC UUID
  static bool isUuid(String value) {
    return _uuidRegex.hasMatch(value.trim());
  }

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
    final trimmed = slugOrId.trim();
    if (_slugToId.containsKey(trimmed)) {
      return _slugToId[trimmed]!;
    }
    final lower = trimmed.toLowerCase();
    if (_slugToId.containsKey(lower)) {
      return _slugToId[lower]!;
    }

    // Attempt dynamic lookup in AppCache.groups
    try {
      final cached = AppCache.groups.getStale('groups_all') ??
          AppCache.groups.get('all');
      if (cached is List) {
        for (final item in cached) {
          final id = (item as dynamic).id as String?;
          final name = (item as dynamic).name as String?;
          if (id != null && name != null) {
            final genSlug = name
                .toLowerCase()
                .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
                .replaceAll(RegExp(r'^-|-$'), '');
            if (genSlug == lower || name.toLowerCase() == lower || id == trimmed) {
              register(id, genSlug.isNotEmpty ? genSlug : id);
              return id;
            }
          }
        }
      }
    } catch (_) {}

    return trimmed;
  }

  /// Registers a runtime mapping between a UUID and a custom slug
  static void register(String groupId, String slug) {
    _idToSlug[groupId] = slug;
    _slugToId[slug] = groupId;
  }

  /// Convenience method to register a group entity's id and name
  static void registerGroup(String groupId, String groupName) {
    register(groupId, groupId);
    final slug = groupName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    if (slug.isNotEmpty) {
      register(groupId, slug);
    }
  }
}

