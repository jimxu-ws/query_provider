import 'package:flutter_test/flutter_test.dart';
import 'package:query_provider/query_provider.dart';

void main() {
  group('QueryCacheEntry', () {
    test('should create entry with data', () {
      final now = DateTime.now();
      const options = QueryOptions<String>();
      
      final entry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: now,
        options: options,
      );
      
      expect(entry.data, 'test data');
      expect(entry.error, null);
      expect(entry.stackTrace, null);
      expect(entry.fetchedAt, now);
      expect(entry.options, options);
      expect(entry.hasData, true);
      expect(entry.hasError, false);
    });

    test('should create entry with error', () {
      final now = DateTime.now();
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      const options = QueryOptions<String>();
      
      final entry = QueryCacheEntry<String>(
        data: null,
        error: error,
        stackTrace: stackTrace,
        fetchedAt: now,
        options: options,
      );
      
      expect(entry.data, null);
      expect(entry.error, error);
      expect(entry.stackTrace, stackTrace);
      expect(entry.fetchedAt, now);
      expect(entry.options, options);
      expect(entry.hasData, false);
      expect(entry.hasError, true);
    });

    test('should calculate isStale correctly', () {
      final now = DateTime.now();
      const options = QueryOptions<String>(staleTime: Duration(minutes: 5));
      
      // Fresh entry
      final freshEntry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: now,
        options: options,
      );
      expect(freshEntry.isStale, false);
      
      // Stale entry
      final staleEntry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: now.subtract(const Duration(minutes: 10)),
        options: options,
      );
      expect(staleEntry.isStale, true);
    });

    test('should calculate isExpired correctly', () {
      final now = DateTime.now();
      const options = QueryOptions<String>(cacheTime: Duration(minutes: 30));
      
      // Fresh entry
      final freshEntry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: now,
        options: options,
      );
      expect(freshEntry.shouldEvict, false);
      
      // Expired entry
      final expiredEntry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: now.subtract(const Duration(minutes: 45)),
        options: options,
      );
      expect(expiredEntry.shouldEvict, true);
    });
  });

  group('QueryCacheStats', () {
    test('should create stats with values', () {
      const stats = QueryCacheStats(
        totalEntries: 10,
        staleEntries: 3,
        hitCount: 50,
        missCount: 20,
        evictionCount: 5,
      );
      
      expect(stats.totalEntries, 10);
      expect(stats.staleEntries, 3);
      expect(stats.hitCount, 50);
      expect(stats.missCount, 20);
      expect(stats.evictionCount, 5);
    });

    test('should calculate hit rate correctly', () {
      const stats = QueryCacheStats(
        totalEntries: 10,
        staleEntries: 3,
        hitCount: 80,
        missCount: 20,
        evictionCount: 5,
      );
      
      expect(stats.hitRate, 0.8); // 80 / (80 + 20)
    });

    test('should handle zero hits and misses', () {
      const stats = QueryCacheStats(
        totalEntries: 0,
        staleEntries: 0,
        hitCount: 0,
        missCount: 0,
        evictionCount: 0,
      );
      
      expect(stats.hitRate, 0.0);
    });

    test('should have correct string representation', () {
      const stats = QueryCacheStats(
        totalEntries: 10,
        staleEntries: 3,
        hitCount: 80,
        missCount: 20,
        evictionCount: 5,
      );
      
      final string = stats.toString();
      expect(string, contains('QueryCacheStats'));
      expect(string, contains('entries: 10'));
      expect(string, contains('stale: 3'));
      expect(string, contains('evictions: 5'));
      expect(string, contains('hitRate: 80.0%'));
    });
  });

  group('QueryCache', () {
    late QueryCache cache;

    setUp(() {
      cache = QueryCache(maxSize: 5);
    });

    tearDown(() {
      cache.clear();
    });

    test('should set and get cache entry', () {
      const options = QueryOptions<String>();
      final entry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: DateTime.now(),
        options: options,
      );
      
      cache.set('test-key', entry);
      final retrieved = cache.get<String>('test-key');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.data, 'test data');
      expect(retrieved.hasData, true);
    });

    test('should return null for non-existent key', () {
      final retrieved = cache.get<String>('non-existent');
      expect(retrieved, null);
    });

    test('should update hit and miss counts', () {
      const options = QueryOptions<String>();
      final entry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: DateTime.now(),
        options: options,
      );
      
      // Miss
      cache.get<String>('test-key');
      expect(cache.stats.missCount, 1);
      expect(cache.stats.hitCount, 0);
      
      // Set and hit
      cache.set('test-key', entry);
      cache.get<String>('test-key');
      expect(cache.stats.hitCount, 1);
      expect(cache.stats.missCount, 1);
    });

    test('should evict oldest entries when max size exceeded', () {
      const options = QueryOptions<String>();
      
      // Fill cache to max size
      for (int i = 0; i < 5; i++) {
        final entry = QueryCacheEntry<String>(
          data: 'data-$i',
          fetchedAt: DateTime.now(),
          options: options,
        );
        cache.set('key-$i', entry);
      }
      
      expect(cache.size, 5);
      
      // Add one more to trigger eviction
      final newEntry = QueryCacheEntry<String>(
        data: 'new-data',
        fetchedAt: DateTime.now(),
        options: options,
      );
      cache.set('new-key', newEntry);
      
      expect(cache.size, 5);
      expect(cache.get<String>('key-0'), null); // Should be evicted
      expect(cache.get<String>('new-key'), isNotNull); // Should exist
      expect(cache.stats.evictionCount, 1);
    });

    test('should remove entry by key', () {
      const options = QueryOptions<String>();
      final entry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: DateTime.now(),
        options: options,
      );
      
      cache.set('test-key', entry);
      expect(cache.containsKey('test-key'), true);
      
      cache.remove('test-key');
      expect(cache.containsKey('test-key'), false);
      expect(cache.get<String>('test-key'), null);
    });

    test('should clear all entries', () {
      const options = QueryOptions<String>();
      
      for (int i = 0; i < 3; i++) {
        final entry = QueryCacheEntry<String>(
          data: 'data-$i',
          fetchedAt: DateTime.now(),
          options: options,
        );
        cache.set('key-$i', entry);
      }
      
      expect(cache.size, 3);
      
      cache.clear();
      expect(cache.size, 0);
      expect(cache.keys, isEmpty);
    });

    test('should cleanup expired entries', () {
      const shortCacheOptions = QueryOptions<String>(cacheTime: Duration(milliseconds: 1));
      const longCacheOptions = QueryOptions<String>(cacheTime: Duration(hours: 1));
      
      final expiredEntry = QueryCacheEntry<String>(
        data: 'expired data',
        fetchedAt: DateTime.now().subtract(const Duration(minutes: 1)),
        options: shortCacheOptions,
      );
      
      final freshEntry = QueryCacheEntry<String>(
        data: 'fresh data',
        fetchedAt: DateTime.now(),
        options: longCacheOptions,
      );
      
      cache.set('expired-key', expiredEntry);
      cache.set('fresh-key', freshEntry);
      
      expect(cache.size, 2);
      
      final cleanedCount = cache.cleanup();
      
      expect(cleanedCount, 1);
      expect(cache.size, 1);
      expect(cache.containsKey('expired-key'), false);
      expect(cache.containsKey('fresh-key'), true);
    });

    test('should remove entries by pattern', () {
      const options = QueryOptions<String>();
      
      final entries = [
        ('user-1', 'user data 1'),
        ('user-2', 'user data 2'),
        ('post-1', 'post data 1'),
        ('post-2', 'post data 2'),
      ];
      
      for (final (key, data) in entries) {
        final entry = QueryCacheEntry<String>(
          data: data,
          fetchedAt: DateTime.now(),
          options: options,
        );
        cache.set(key, entry);
      }
      
      expect(cache.size, 4);
      
      final removedCount = cache.removeByPattern('user');
      
      expect(removedCount, 2);
      expect(cache.size, 2);
      expect(cache.containsKey('user-1'), false);
      expect(cache.containsKey('user-2'), false);
      expect(cache.containsKey('post-1'), true);
      expect(cache.containsKey('post-2'), true);
    });

    test('should set and get error entries', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      const options = QueryOptions<String>();
      
      cache.setError<String>('error-key', error, stackTrace: stackTrace, options: options);
      
      final retrieved = cache.get<String>('error-key');
      expect(retrieved, isNotNull);
      expect(retrieved!.hasError, true);
      expect(retrieved.error, error);
      expect(retrieved.stackTrace, stackTrace);
    });

    test('should reset statistics', () {
      const options = QueryOptions<String>();
      final entry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: DateTime.now(),
        options: options,
      );
      
      // Generate some stats
      cache.get<String>('missing-key'); // Miss
      cache.set('test-key', entry);
      cache.get<String>('test-key'); // Hit
      
      expect(cache.stats.hitCount, 1);
      expect(cache.stats.missCount, 1);
      
      cache.resetStats();
      
      expect(cache.stats.hitCount, 0);
      expect(cache.stats.missCount, 0);
      expect(cache.stats.evictionCount, 0);
    });

    test('should get all cache keys', () {
      const options = QueryOptions<String>();
      
      final keys = ['key-1', 'key-2', 'key-3'];
      for (final key in keys) {
        final entry = QueryCacheEntry<String>(
          data: 'data for $key',
          fetchedAt: DateTime.now(),
          options: options,
        );
        cache.set(key, entry);
      }
      
      final cacheKeys = cache.keys;
      expect(cacheKeys.length, 3);
      for (final key in keys) {
        expect(cacheKeys.contains(key), true);
      }
    });

    test('should handle cache operations correctly', () {
      const options = QueryOptions<String>();
      final entry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: DateTime.now(),
        options: options,
      );
      
      // Test basic operations
      cache.set('test-key', entry);
      expect(cache.containsKey('test-key'), true);
      
      final retrieved = cache.get<String>('test-key');
      expect(retrieved, isNotNull);
      expect(retrieved!.data, 'test data');
      
      cache.remove('test-key');
      expect(cache.containsKey('test-key'), false);
    });

    test('should move accessed entries to end (LRU)', () {
      const options = QueryOptions<String>();
      
      // Fill cache
      for (int i = 0; i < 3; i++) {
        final entry = QueryCacheEntry<String>(
          data: 'data-$i',
          fetchedAt: DateTime.now(),
          options: options,
        );
        cache.set('key-$i', entry);
      }
      
      // Access first entry to move it to end
      cache.get<String>('key-0');
      
      // Add entries until eviction
      for (int i = 3; i < 6; i++) {
        final entry = QueryCacheEntry<String>(
          data: 'data-$i',
          fetchedAt: DateTime.now(),
          options: options,
        );
        cache.set('key-$i', entry);
      }
      
      // key-0 should still exist because it was accessed recently
      expect(cache.get<String>('key-0'), isNotNull);
      // key-1 should be evicted because it wasn't accessed
      expect(cache.get<String>('key-1'), null);
    });
  });

  group('getGlobalQueryCache', () {
    test('should return singleton instance', () {
      final cache1 = getGlobalQueryCache();
      final cache2 = getGlobalQueryCache();
      
      expect(identical(cache1, cache2), true);
    });

    test('should maintain state across calls', () {
      final cache = getGlobalQueryCache();
      
      const options = QueryOptions<String>();
      final entry = QueryCacheEntry<String>(
        data: 'test data',
        fetchedAt: DateTime.now(),
        options: options,
      );
      
      cache.set('test-key', entry);
      
      final anotherCacheReference = getGlobalQueryCache();
      final retrieved = anotherCacheReference.get<String>('test-key');
      
      expect(retrieved, isNotNull);
      expect(retrieved!.data, 'test data');
    });
  });
}
