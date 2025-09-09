import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

import 'query_options.dart';

/// Cache entry for storing query data and metadata
@immutable
class QueryCacheEntry<T> {
  const QueryCacheEntry({
    required this.data,
    required this.fetchedAt,
    required this.options,
    this.error,
    this.stackTrace,
  });

  final T? data;
  final DateTime fetchedAt;
  final QueryOptions<T> options;
  final Object? error;
  final StackTrace? stackTrace;

  /// Returns true if the cached data is stale
  bool get isStale {
    final now = DateTime.now();
    return now.difference(fetchedAt) > options.staleTime;
  }

  /// Returns true if the cache entry should be evicted
  bool get shouldEvict {
    final now = DateTime.now();
    return now.difference(fetchedAt) > options.cacheTime;
  }

  /// Returns true if this entry has valid data
  bool get hasData => data != null && error == null;

  /// Returns true if this entry has an error
  bool get hasError => error != null;

  QueryCacheEntry<T> copyWith({
    T? data,
    DateTime? fetchedAt,
    QueryOptions<T>? options,
    Object? error,
    StackTrace? stackTrace,
  }) => QueryCacheEntry<T>(
      data: data ?? this.data,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      options: options ?? this.options,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
    );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueryCacheEntry<T> &&
          other.data == data &&
          other.fetchedAt == fetchedAt &&
          other.error == error);

  @override
  int get hashCode => Object.hash(data, fetchedAt, error);

  @override
  String toString() => 'QueryCacheEntry<$T>('
      'data: $data, '
      'fetchedAt: $fetchedAt, '
      'hasError: $hasError, '
      'isStale: $isStale)';
}

/// Cache statistics for monitoring and debugging
@immutable
class QueryCacheStats {
  const QueryCacheStats({
    required this.totalEntries,
    required this.staleEntries,
    required this.hitCount,
    required this.missCount,
    required this.evictionCount,
  });

  final int totalEntries;
  final int staleEntries;
  final int hitCount;
  final int missCount;
  final int evictionCount;

  double get hitRate => hitCount + missCount > 0 ? hitCount / (hitCount + missCount) : 0.0;

  @override
  String toString() => 'QueryCacheStats('
      'entries: $totalEntries, '
      'stale: $staleEntries, '
      'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
      'evictions: $evictionCount)';
}

/// Event types for cache notifications
enum QueryCacheEventType {
  hit,
  miss,
  set,
  evict,
  clear,
}

/// Cache event for monitoring and debugging
@immutable
class QueryCacheEvent {
  const QueryCacheEvent({
    required this.type,
    required this.key,
    required this.timestamp,
    this.entry,
  });

  final QueryCacheEventType type;
  final String key;
  final DateTime timestamp;
  final QueryCacheEntry? entry;

  @override
  String toString() => 'QueryCacheEvent(${type.name}: $key at $timestamp)';
}

/// Callback for cache events
typedef QueryCacheEventCallback = void Function(QueryCacheEvent event);

/// Callback for cache data changes
typedef QueryCacheChangeCallback<T> = void Function(QueryCacheEntry<T>? entry);

/// In-memory cache implementation for query data
class QueryCache {
  QueryCache({
    this.maxSize = 100,
    this.defaultCacheTime = const Duration(minutes: 30),
    this.onEvent,
  }) {
    _startCleanupTimer();
  }

  /// Maximum number of entries to keep in cache
  final int maxSize;

  /// Default cache time for entries without specific options
  final Duration defaultCacheTime;

  /// Optional callback for cache events
  final QueryCacheEventCallback? onEvent;

  /// Internal cache storage
  final Map<String, QueryCacheEntry<dynamic>> _cache = <String, QueryCacheEntry<dynamic>>{};

  /// Cache change listeners by key
  final Map<String, Set<void Function(QueryCacheEntry<dynamic>?)>> _listeners = {};

  /// Cache statistics
  int _hitCount = 0;
  int _missCount = 0;
  int _evictionCount = 0;

  /// Cleanup timer
  Timer? _cleanupTimer;
  
  /// Next scheduled cleanup time (for debugging)
  DateTime? _nextCleanupTime;

  /// Get a cache entry by key
  QueryCacheEntry<T>? get<T>(String key) {
    final entry = _cache[key];
    
    if (entry == null) {
      _missCount++;
      _emitEvent(QueryCacheEventType.miss, key);
      return null;
    }

    // Check if entry should be evicted
    if (entry.shouldEvict) {
      _cache.remove(key);
      _evictionCount++;
      _emitEvent(QueryCacheEventType.evict, key, entry);
      _missCount++;
      _emitEvent(QueryCacheEventType.miss, key);
      return null;
    }

    // Move to end (LRU)
    // FIXME: i think it might be unnecessary to remove the entry and then add it back
    _cache.remove(key);
    _cache[key] = entry;
    
    _hitCount++;
    _emitEvent(QueryCacheEventType.hit, key, entry);
    
    return entry as QueryCacheEntry<T>?;
  }

  /// Set a cache entry
  void set<T>(String key, QueryCacheEntry<T> entry) {
    // Remove existing entry if present
    _cache.remove(key);
    
    // Add new entry
    _cache[key] = entry;
    _emitEvent(QueryCacheEventType.set, key, entry);
    
    // Notify listeners of the change
    _notifyListeners<T>(key, entry);
    
    // Evict oldest entries if cache is full
    _evictIfNecessary();
  }

  /// Set cache data with automatic entry creation
  void setData<T>(
    String key,
    T data, {
    QueryOptions<T>? options,
    DateTime? fetchedAt,
  }) {
    final entry = QueryCacheEntry<T>(
      data: data,
      fetchedAt: fetchedAt ?? DateTime.now(),
      options: options ?? QueryOptions<T>(cacheTime: defaultCacheTime),
    );
    set(key, entry);
  }

  /// Set cache error with automatic entry creation
  void setError<T>(
    String key,
    Object error, {
    StackTrace? stackTrace,
    QueryOptions<T>? options,
    DateTime? fetchedAt,
  }) {
    final entry = QueryCacheEntry<T>(
      data: null,
      fetchedAt: fetchedAt ?? DateTime.now(),
      options: options ?? QueryOptions<T>(cacheTime: defaultCacheTime),
      error: error,
      stackTrace: stackTrace,
    );
    set(key, entry);
  }

  /// Remove a specific cache entry
  bool remove(String key) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _emitEvent(QueryCacheEventType.evict, key, entry);
      // Notify listeners that entry was removed
      _notifyListeners(key, null);
      return true;
    }
    return false;
  }

  /// Clear all cache entries
  void clear() {
    final keys = _cache.keys.toList();
    _cache.clear();
    
    for (final key in keys) {
      _emitEvent(QueryCacheEventType.clear, key);
    }
  }

  /// Remove entries matching a key pattern
  int removeByPattern(String pattern) {
    final keysToRemove = _cache.keys
        .where((key) => key.contains(pattern))
        .toList();
    
    for (final key in keysToRemove) {
      remove(key);
    }
    
    return keysToRemove.length;
  }

  /// Get all cache keys
  List<String> get keys => _cache.keys.toList();

  /// Get cache size
  int get size => _cache.length;

  /// Check if cache contains a key
  bool containsKey(String key) => _cache.containsKey(key);

  /// Get cache statistics
  QueryCacheStats get stats {
    final staleCount = _cache.values
        .where((entry) => entry.isStale)
        .length;
    
    return QueryCacheStats(
      totalEntries: _cache.length,
      staleEntries: staleCount,
      hitCount: _hitCount,
      missCount: _missCount,
      evictionCount: _evictionCount,
    );
  }

  /// Get next cleanup time (for debugging)
  DateTime? get nextCleanupTime => _nextCleanupTime;

  /// Reset statistics
  void resetStats() {
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
  }

  /// Manually trigger cleanup of expired entries
  int cleanup() {
    final keysToRemove = <String>[];
    
    for (final entry in _cache.entries) {
      if (entry.value.shouldEvict) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final key in keysToRemove) {
      remove(key);
    }
    
    return keysToRemove.length;
  }

  /// Evict oldest entries if cache exceeds max size
  void _evictIfNecessary() {
    while (_cache.length > maxSize) {
      final oldestKey = _cache.keys.first;
      final entry = _cache.remove(oldestKey);
      _evictionCount++;
      if (entry != null) {
        _emitEvent(QueryCacheEventType.evict, oldestKey, entry);
      }
    }
  }

  /// Start automatic cleanup timer with adaptive interval
  void _startCleanupTimer() {
    _scheduleNextCleanup();
  }

  /// Schedule the next cleanup based on current cache state
  void _scheduleNextCleanup() {
    _cleanupTimer?.cancel();
    
    final nextCleanupInterval = _calculateOptimalCleanupInterval();
    _nextCleanupTime = DateTime.now().add(nextCleanupInterval);
    
    _cleanupTimer = Timer(nextCleanupInterval, () {
      final cleanedCount = cleanup();
      
      // Emit debug info if there's a listener
      _emitEvent(
        QueryCacheEventType.evict,
        'cleanup-batch-$cleanedCount',
        null,
      );
      
      // Schedule next cleanup
      _scheduleNextCleanup();
    });
  }

  /// Calculate optimal cleanup interval based on cache contents
  Duration _calculateOptimalCleanupInterval() {
    if (_cache.isEmpty) {
      // No entries, check less frequently
      return const Duration(minutes: 30);
    }

    // Find the shortest cache time among current entries
    Duration shortestCacheTime = defaultCacheTime;
    DateTime now = DateTime.now();
    DateTime? nextExpiration;

    for (final entry in _cache.values) {
      final entryExpiration = entry.fetchedAt.add(entry.options.cacheTime);
      
      // Track the shortest cache time for future entries
      if (entry.options.cacheTime < shortestCacheTime) {
        shortestCacheTime = entry.options.cacheTime;
      }
      
      // Find the next expiration time
      if (entryExpiration.isAfter(now)) {
        if (nextExpiration == null || entryExpiration.isBefore(nextExpiration)) {
          nextExpiration = entryExpiration;
        }
      }
    }

    // If we have a specific next expiration, schedule cleanup slightly after it
    if (nextExpiration != null) {
      final timeUntilExpiration = nextExpiration.difference(now);
      // Add a small buffer (1 minute) and ensure minimum interval
      return Duration(
        milliseconds: (timeUntilExpiration.inMilliseconds + 60000).clamp(
          60000, // Minimum 1 minute
          shortestCacheTime.inMilliseconds ~/ 2, // Maximum half of shortest cache time
        ),
      );
    }

    // Fallback: use 1/4 of the shortest cache time, with reasonable bounds
    return Duration(
      minutes: (shortestCacheTime.inMinutes / 4).clamp(5, 30).round(),
    );
  }

  /// Add a listener for cache changes on a specific key
  void addListener<T>(String key, QueryCacheChangeCallback<T> callback) {
    _listeners.putIfAbsent(key, () => <void Function(QueryCacheEntry<dynamic>?)>{});
    _listeners[key]!.add((entry) => callback(entry as QueryCacheEntry<T>?));
  }

  /// Remove a listener for a specific key
  void removeListener<T>(String key, QueryCacheChangeCallback<T> callback) {
    // Note: This won't work perfectly because we're storing wrapped functions
    // For now, use removeAllListeners instead for cleanup
    if (_listeners[key]?.isEmpty == true) {
      _listeners.remove(key);
    }
  }

  /// Remove all listeners for a specific key
  void removeAllListeners(String key) {
    _listeners.remove(key);
  }

  /// Notify listeners of cache changes
  void _notifyListeners<T>(String key, QueryCacheEntry<T>? entry) {
    final listeners = _listeners[key];
    if (listeners != null) {
      for (final listener in listeners) {
        try {
          // Entry is already cast to dynamic in the stored wrapper function
          listener(entry as QueryCacheEntry<dynamic>?);
        } catch (e) {
          // Ignore listener errors to prevent cache corruption
          debugPrint('Cache listener error for key $key: $e');
        }
      }
    }
  }

  /// Emit cache event
  void _emitEvent(QueryCacheEventType type, String key, [QueryCacheEntry<dynamic>? entry]) {
    onEvent?.call(QueryCacheEvent(
      type: type,
      key: key,
      timestamp: DateTime.now(),
      entry: entry,
    ));
  }

  /// Dispose the cache and cleanup resources
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _listeners.clear();
    clear();
  }

  @override
  String toString() => 'QueryCache(size: $size/$maxSize, stats: $stats)';
}

/// Global cache instance
QueryCache? _globalCache;

/// Get or create the global cache instance
QueryCache getGlobalQueryCache() => _globalCache ??= QueryCache();

/// Set a custom global cache instance
void setGlobalQueryCache(QueryCache cache) {
  _globalCache?.dispose();
  _globalCache = cache;
}

/// Dispose the global cache
void disposeGlobalQueryCache() {
  _globalCache?.dispose();
  _globalCache = null;
}
