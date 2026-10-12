import 'package:edu_saas/core/network/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cache_manager.dart';

/// Utility class to map group UUIDs to clean, human-readable URL slugs
/// (e.g. 'sat' or 'sat-advanced' instead of raw database UUIDs).
class GroupSlugResolver {
  GroupSlugResolver._();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  // Runtime dynamic bidirectional caches
  static final Map<String, String> _idToSlug = {};
  static final Map<String, String> _slugToId = {};

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

  /// Resolves an aesthetic URL slug back to its database UUID from in-memory cache
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
      final cached =
          AppCache.groups.getStale(AppCache.userKey('groups')) ??
          AppCache.groups.getStale('groups_all') ??
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
            if (genSlug == lower ||
                name.toLowerCase() == lower ||
                id == trimmed) {
              register(id, genSlug.isNotEmpty ? genSlug : id);
              return id;
            }
          }
        }
      }
    } catch (_) {}

    return trimmed;
  }

  /// Asynchronously resolves a slug to its database UUID by querying Supabase
  /// if not found in memory, and registers the mapping dynamically.
  static Future<String> toIdAsync(
    String slugOrId, [
    SupabaseClient? client,
  ]) async {
    final cached = toId(slugOrId);
    if (isUuid(cached)) return cached;

    try {
      final sc = client ?? SupabaseService.client;
      final row = await sc
          .from('groups')
          .select('id, name')
          .ilike('name', slugOrId.trim())
          .limit(1)
          .maybeSingle();
      if (row != null && row['id'] != null) {
        final realId = row['id'] as String;
        final name = row['name'] as String? ?? slugOrId;
        registerGroup(realId, name);
        return realId;
      }
    } catch (_) {}

    return slugOrId;
  }

  /// Registers a runtime mapping between a UUID and a custom slug
  static void register(String groupId, String slug) {
    _idToSlug[groupId] = slug;
    _slugToId[slug] = groupId;
  }

  /// Registers an alternative slug pointing to a UUID without changing its primary canonical slug
  static void registerAlias(String slug, String groupId) {
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

  /// Clears in-memory mappings (mainly for unit tests)
  static void clear() {
    _idToSlug.clear();
    _slugToId.clear();
  }
}
