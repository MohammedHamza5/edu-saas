/// In-Memory Cache Manager for EduSaaS
///
/// Provides typed, TTL-based caching with LRU eviction.
/// Three cache tiers as per architecture doc §16:
///   - Short-lived (30s): notifications count, pending badges
///   - Cacheable (5min): students, groups, content lists
///   - Static (30min): tenant branding, config
///
/// Thread-safe for single-isolate Dart (Flutter main thread).
/// Supabase remains the single source of truth — cache is for instant display only.
library;

import '../utils/app_logger.dart';

// ── Cache Duration Tiers ──────────────────────────────────────────────────

/// Predefined TTL durations matching the architecture spec.
abstract final class CacheDuration {
  /// Notifications count, pending count badges.
  static const Duration shortLived = Duration(seconds: 30);

  /// Students list, groups list, content items.
  static const Duration cacheable = Duration(minutes: 5);

  /// Tenant branding, app config.
  static const Duration staticData = Duration(minutes: 30);
}

// ── Cache Entry ───────────────────────────────────────────────────────────

class _CacheEntry<T> {
  final T data;
  final DateTime storedAt;
  final Duration ttl;
  DateTime lastAccessed;

  _CacheEntry({
    required this.data,
    required this.ttl,
  })  : storedAt = DateTime.now(),
        lastAccessed = DateTime.now();

  bool get isExpired => DateTime.now().difference(storedAt) > ttl;

  /// Data is stale but still usable for stale-while-revalidate.
  bool get isStale {
    final age = DateTime.now().difference(storedAt);
    // Stale after 80% of TTL has passed
    return age > (ttl * 0.8);
  }

  void touch() => lastAccessed = DateTime.now();
}

// ── InMemoryCache ─────────────────────────────────────────────────────────

/// Generic in-memory cache with TTL and LRU eviction.
///
/// Usage:
/// ```dart
/// final cache = InMemoryCache<List<StudentEntity>>(
///   ttl: CacheDuration.cacheable,
///   maxEntries: 20,
/// );
///
/// // Store
/// cache.put('students_all', studentsList);
///
/// // Retrieve (null if expired or missing)
/// final cached = cache.get('students_all');
///
/// // Stale-while-revalidate check
/// if (cache.isStale('students_all')) {
///   // Refresh in background
/// }
/// ```
class InMemoryCache<T> {
  final Duration ttl;
  final int maxEntries;
  final String _label;
  final Map<String, _CacheEntry<T>> _store = {};

  InMemoryCache({
    required this.ttl,
    this.maxEntries = 50,
    String? label,
  }) : _label = label ?? T.toString();

  /// Returns cached data if valid (not expired), otherwise null.
  T? get(String key) {
    final entry = _store.remove(key);
    if (entry == null) return null;

    if (entry.isExpired) {
      // Re-insert to preserve for stale-while-revalidate within 2x TTL
      _store[key] = entry;
      return null;
    }

    // Re-insert at end of Map (most recently used in LinkedHashMap)
    _store[key] = entry;
    return entry.data;
  }

  /// Returns cached data even if stale (but not expired).
  /// Use for stale-while-revalidate pattern.
  T? getStale(String key) {
    final entry = _store.remove(key);
    if (entry == null) return null;

    // Discard only if older than 2x TTL
    final age = DateTime.now().difference(entry.storedAt);
    if (age > entry.ttl * 2) {
      return null;
    }

    // Re-insert at end (most recently used)
    _store[key] = entry;
    return entry.data;
  }

  /// Whether the cached data is stale and should be refreshed.
  bool isStale(String key) {
    final entry = _store[key];
    if (entry == null) return true;
    return entry.isStale || entry.isExpired;
  }

  /// Whether a valid (non-expired) entry exists.
  bool has(String key) {
    final entry = _store[key];
    if (entry == null) return false;
    return !entry.isExpired;
  }

  /// Stores data with the configured TTL and applies O(1) LRU eviction.
  void put(String key, T data) {
    // Remove if exists so new entry goes to the end (most recent)
    _store.remove(key);

    // O(1) LRU eviction: remove oldest key (first key in LinkedHashMap)
    if (_store.length >= maxEntries) {
      _store.remove(_store.keys.first);
    }

    _store[key] = _CacheEntry<T>(data: data, ttl: ttl);
  }

  /// Invalidates a specific key.
  void invalidate(String key) {
    final removed = _store.remove(key);
    if (removed != null) {
      AppLogger.d('Cache:$_label', 'Invalidated key: $key');
    }
  }

  /// Invalidates all keys matching a prefix.
  void invalidatePrefix(String prefix) {
    final keysToRemove = _store.keys.where((k) => k.startsWith(prefix)).toList();
    for (final key in keysToRemove) {
      _store.remove(key);
    }
    if (keysToRemove.isNotEmpty) {
      AppLogger.d('Cache:$_label', 'Invalidated ${keysToRemove.length} keys with prefix: $prefix');
    }
  }

  /// Clears all cached entries.
  void clear() {
    final count = _store.length;
    _store.clear();
    if (count > 0) {
      AppLogger.d('Cache:$_label', 'Cleared $count entries');
    }
  }

  /// Number of valid (non-expired) entries.
  int get length {
    _pruneExpired();
    return _store.length;
  }

  // ── Internal ────────────────────────────────────────────────────────────

  void _pruneExpired() {
    _store.removeWhere((_, entry) => DateTime.now().difference(entry.storedAt) > entry.ttl * 2);
  }
}

// ── App Cache Registry ────────────────────────────────────────────────────

/// Central cache registry for the app. Provides pre-configured caches
/// for each data domain.
///
/// Usage:
/// ```dart
/// AppCache.students.put('all', studentsList);
/// final cached = AppCache.students.get('all');
/// AppCache.invalidateOnWrite(); // after any write operation
/// ```
abstract final class AppCache {
  // ── Domain Caches ─────────────────────────────────────────────────────

  /// Students list, filtered views, pending count.
  static final students = InMemoryCache<dynamic>(
    ttl: CacheDuration.cacheable,
    maxEntries: 20,
    label: 'Students',
  );

  /// Groups list, group detail, members.
  static final groups = InMemoryCache<dynamic>(
    ttl: CacheDuration.cacheable,
    maxEntries: 20,
    label: 'Groups',
  );

  /// Notifications list, unread count.
  static final notifications = InMemoryCache<dynamic>(
    ttl: CacheDuration.shortLived,
    maxEntries: 10,
    label: 'Notifications',
  );

  /// Content items per group.
  static final content = InMemoryCache<dynamic>(
    ttl: CacheDuration.cacheable,
    maxEntries: 30,
    label: 'Content',
  );

  /// Attendance records.
  static final attendance = InMemoryCache<dynamic>(
    ttl: CacheDuration.cacheable,
    maxEntries: 20,
    label: 'Attendance',
  );

  /// Assignments per group.
  static final assignments = InMemoryCache<dynamic>(
    ttl: CacheDuration.cacheable,
    maxEntries: 20,
    label: 'Assignments',
  );

  /// Exams per group.
  static final exams = InMemoryCache<dynamic>(
    ttl: CacheDuration.cacheable,
    maxEntries: 20,
    label: 'Exams',
  );

  /// Tenant branding, config.
  static final tenant = InMemoryCache<dynamic>(
    ttl: CacheDuration.staticData,
    maxEntries: 5,
    label: 'Tenant',
  );

  // ── Bulk Operations ─────────────────────────────────────────────────────

  /// Call after any write operation (create/update/delete) to ensure
  /// fresh data is fetched on next access.
  static void invalidateOnWrite() {
    students.clear();
    groups.clear();
    notifications.clear();
    content.clear();
    attendance.clear();
    assignments.clear();
    exams.clear();
    AppLogger.d('AppCache', '🧹 All domain caches invalidated after write');
  }

  /// Clears everything (e.g., on logout).
  static void clearAll() {
    students.clear();
    groups.clear();
    notifications.clear();
    content.clear();
    attendance.clear();
    assignments.clear();
    exams.clear();
    tenant.clear();
    AppLogger.d('AppCache', '🧹 All caches cleared (logout/reset)');
  }
}
