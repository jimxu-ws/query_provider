import 'dart:async';

import 'package:flutter/foundation.dart';

import 'query_cache.dart';
import 'query_options.dart';

/// In-memory cache implementation for query data
class MemoryQueryCache extends QueryCache {
  /// Create a new memory query cache
  MemoryQueryCache({
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
  @override
  QueryCacheEntry<T>? get<T>(String key) {
    final entry = _cache[key];
    
    if (entry == null) {
      _missCount++;
      _emitEvent(QueryCacheEventType.miss, key);
      return null;
    }

    // Check if entry should be evicted
    if (entry.shouldEvict) {
      debugPrint('Evicting entry for key $key in query cache');
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
  @override
  void set<T>(String key, QueryCacheEntry<T> entry, {bool notify = true}) {
    // Remove existing entry if present
    _cache.remove(key);
    
    // Add new entry
    _cache[key] = entry;
    _emitEvent(QueryCacheEventType.set, key, entry);
    
    // Notify listeners of the change
    if (notify) {
      _notifyListeners<T>(key, entry);
    }
    
    // Evict oldest entries if cache is full
    _evictIfNecessary();
  }

  /// Set cache data with automatic entry creation
  @override
  void setData<T>(
    String key,
    T data, {
    QueryOptions<T>? options,
    DateTime? fetchedAt,
    bool notify = true
  }) {
    final entry = QueryCacheEntry<T>(
      data: data,
      fetchedAt: fetchedAt ?? DateTime.now(),
      options: options ?? QueryOptions<T>(cacheTime: defaultCacheTime),
    );
    set(key, entry, notify: notify);
  }

  /// Set cache error with automatic entry creation
  @override
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
  @override
  bool remove(String key, {bool notify = true}) {
    final entry = _cache.remove(key);
    if (entry != null) {
      _emitEvent(QueryCacheEventType.evict, key, entry);
      // Notify listeners that entry was removed
      if (notify) {
        _notifyListeners<dynamic>(key, null);
      }
      return true;
    }
    return false;
  }

  /// Clear all cache entries
  @override
  void clear() {
    final keys = _cache.keys.toList();
    _cache.clear();
    
    for (final key in keys) {
      _emitEvent(QueryCacheEventType.clear, key);
    }
  }

  /// Remove entries matching a key pattern
  @override
  int removeByPattern(String pattern, {bool notify = true}) {
    final keysToRemove = _cache.keys
        .where((key) => key.contains(pattern))
        .toList();
    
    for (final key in keysToRemove) {
      remove(key, notify: notify);
    }
    
    return keysToRemove.length;
  }

  /// Remove entries matching a key pattern
  @override
  int markAsStaleByPattern(String pattern) {
    final keysToStale = _cache.keys
        .where((key) => key.contains(pattern))
        .toList();
    
    for (final key in keysToStale) {
      final entry = _cache[key];
      if (entry != null) {
        set(key, entry.copyAsStale(), notify: false);
      }
    }
    
    return keysToStale.length;
  }

  /// Get all cache keys
  @override
  List<String> get keys => _cache.keys.toList();

  /// Get cache size
  @override
  int get size => _cache.length;

  /// Check if cache contains a key
  @override
  bool containsKey(String key) => _cache.containsKey(key);

  /// Get cache statistics
  @override
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
  @override
  DateTime? get nextCleanupTime => _nextCleanupTime;

  /// Reset statistics
  @override
  void resetStats() {
    _hitCount = 0;
    _missCount = 0;
    _evictionCount = 0;
  }

  /// Manually trigger cleanup of expired entries
  @override
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
    final DateTime now = DateTime.now();
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
  @override
  void addListener<T>(String key, QueryCacheChangeCallback<T> callback) {
    _listeners.putIfAbsent(key, () => <void Function(QueryCacheEntry<dynamic>?)>{});
    _listeners[key]!.add((entry) => callback(entry as QueryCacheEntry<T>?));
  }

  /// Remove a listener for a specific key
  @override
  void removeListener<T>(String key, QueryCacheChangeCallback<T> callback) {
    // Note: This won't work perfectly because we're storing wrapped functions
    // For now, use removeAllListeners instead for cleanup
    if (_listeners[key]?.isEmpty ?? false) {
      _listeners.remove(key);
    }
  }

  /// Remove all listeners for a specific key
  @override
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
    debugPrint('Emitting cache event for key $key in query cache, type: $type');
    onEvent?.call(QueryCacheEvent(
      type: type,
      key: key,
      timestamp: DateTime.now(),
      entry: entry,
    ));
  }

  /// Dispose the cache and cleanup resources
  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _listeners.clear();
    clear();
  }

  @override
  String toString() => 'MemoryQueryCache(size: $size/$maxSize, stats: $stats)';
}