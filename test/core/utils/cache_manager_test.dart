import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryCache Tests', () {
    late InMemoryCache<String> cache;

    setUp(() {
      cache = InMemoryCache<String>(
        ttl: const Duration(milliseconds: 100),
        maxEntries: 3,
        label: 'TestCache',
      );
    });

    test('stores and retrieves data before expiration', () {
      cache.put('key1', 'value1');

      expect(cache.has('key1'), isTrue);
      expect(cache.get('key1'), equals('value1'));
      expect(cache.length, equals(1));
    });

    test('returns null and prunes expired data after TTL', () async {
      cache.put('key1', 'value1');

      // Wait past TTL
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(cache.has('key1'), isFalse);
      expect(cache.get('key1'), isNull);
    });

    test('getStale returns data within 2x TTL even if expired', () async {
      cache.put('key1', 'value1');

      // Wait past 1x TTL (100ms) but less than 2x TTL (200ms)
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(cache.get('key1'), isNull); // Normal get is expired
      expect(cache.getStale('key1'), equals('value1')); // Stale still returns
      expect(cache.isStale('key1'), isTrue);
    });

    test('evicts oldest accessed entry when maxEntries is exceeded (LRU)', () {
      cache.put('k1', 'v1');
      cache.put('k2', 'v2');
      cache.put('k3', 'v3');

      // Touch k1 to make k2 the least recently used
      cache.get('k1');

      // Put 4th item -> should evict k2
      cache.put('k4', 'v4');

      expect(cache.has('k1'), isTrue);
      expect(cache.has('k2'), isFalse);
      expect(cache.has('k3'), isTrue);
      expect(cache.has('k4'), isTrue);
    });

    test('invalidate removes specific key', () {
      cache.put('k1', 'v1');
      cache.put('k2', 'v2');

      cache.invalidate('k1');

      expect(cache.has('k1'), isFalse);
      expect(cache.has('k2'), isTrue);
    });

    test('invalidatePrefix removes all matching keys', () {
      cache.put('group_1', 'val1');
      cache.put('group_2', 'val2');
      cache.put('user_1', 'val3');

      cache.invalidatePrefix('group_');

      expect(cache.has('group_1'), isFalse);
      expect(cache.has('group_2'), isFalse);
      expect(cache.has('user_1'), isTrue);
    });

    test('clear wipes all entries', () {
      cache.put('k1', 'v1');
      cache.put('k2', 'v2');

      cache.clear();

      expect(cache.length, equals(0));
      expect(cache.has('k1'), isFalse);
    });
  });

  group('AppCache Registry Tests', () {
    setUp(() {
      AppCache.clearAll();
    });

    tearDown(() {
      AppCache.clearAll();
    });

    test('invalidateOnWrite clears domain caches', () {
      AppCache.students.put('s1', 'student_data');
      AppCache.groups.put('g1', 'group_data');
      AppCache.notifications.put('n1', 'notif_data');

      AppCache.invalidateOnWrite();

      expect(AppCache.students.has('s1'), isFalse);
      expect(AppCache.groups.has('g1'), isFalse);
      expect(AppCache.notifications.has('n1'), isFalse);
    });

    test('clearAll clears tenant cache along with domain caches', () {
      AppCache.students.put('s1', 'student_data');
      AppCache.tenant.put('t1', 'tenant_data');

      AppCache.clearAll();

      expect(AppCache.students.has('s1'), isFalse);
      expect(AppCache.tenant.has('t1'), isFalse);
    });
  });
}
