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

  /// Create a copy of the entry
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

  /// Create a stale copy of the entry
    QueryCacheEntry<T> copyAsStale() => QueryCacheEntry<T>(
      data: this.data,
      fetchedAt: this.fetchedAt.subtract(this.options.staleTime + const Duration(minutes: 1)),
      options: this.options,
      error: this.error,
      stackTrace: this.stackTrace,
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
abstract class QueryCache {
  
  /// Get a cache entry by key
  QueryCacheEntry<T>? get<T>(String key);

  /// Set a cache entry
  void set<T>(String key, QueryCacheEntry<T> entry, {bool notify = true});

  /// Set cache data with automatic entry creation
  void setData<T>(
    String key,
    T data, {
    QueryOptions<T>? options,
    DateTime? fetchedAt,
    bool notify = true
  });

  /// Set cache error with automatic entry creation
  void setError<T>(
    String key,
    Object error, {
    StackTrace? stackTrace,
    QueryOptions<T>? options,
    DateTime? fetchedAt,
  });

  /// Remove a specific cache entry
  bool remove(String key, {bool notify = true});

  /// Clear all cache entries
  void clear();

  /// Remove entries matching a key pattern
  int removeByPattern(String pattern, {bool notify = true});

  /// Remove entries matching a key pattern
  int markAsStaleByPattern(String pattern);

  /// Get all cache keys
  List<String> get keys;

  /// Get cache size
  int get size;

  /// Check if cache contains a key
  bool containsKey(String key);

  /// Get cache statistics
  QueryCacheStats get stats;

  /// Get next cleanup time (for debugging)
  DateTime? get nextCleanupTime;

  /// Reset statistics
  void resetStats();

  /// Manually trigger cleanup of expired entries
  int cleanup();

  /// Add a listener for cache changes on a specific key
  void addListener<T>(String key, QueryCacheChangeCallback<T> callback);

  /// Remove a listener for a specific key
  void removeListener<T>(String key, QueryCacheChangeCallback<T> callback);

  /// Remove all listeners for a specific key
  void removeAllListeners(String key);

  /// Dispose the cache and cleanup resources
  void dispose();
}

