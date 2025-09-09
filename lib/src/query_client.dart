import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'query_cache.dart';

/// A client for managing query cache and global operations
class QueryClient {
  QueryClient({
    ProviderContainer? container,
    QueryCache? cache,
  })  : _container = container,
        _cache = cache ?? getGlobalQueryCache();
  
  // Private constructor for singleton
  QueryClient._internal() : _container = null, _cache = getGlobalQueryCache();

  // Singleton instance
  static QueryClient? _instance;
  static QueryClient get instance => _instance ??= QueryClient._internal();
  
  /// Set the container for provider invalidation support
  /// This should be called once during app initialization
  static void setContainer(ProviderContainer container) {
    if (_instance != null) {
      _instance!._setContainer(container);
    }
  }
  
  void _setContainer(ProviderContainer container) {
    _container ??= container;
  }

  ProviderContainer? _container;
  final QueryCache _cache;
  final Map<String, Timer> _refetchTimers = {};

  /// Check if provider invalidation is supported
  bool get supportsProviderInvalidation => _container != null;
  
  /// Invalidate queries by key pattern
  void invalidateQueries(String keyPattern) {
    // Always clear cache entries matching the pattern
    _cache.removeByPattern(keyPattern);
    
    // If no container, cache clearing is all we can do
    if (_container == null) {
      debugPrint('⚠️ QueryClient: Provider invalidation not available. Only cache cleared for pattern: $keyPattern');
      return;
    }
    
    // Find all providers that match the pattern and invalidate them
    final matchingKeys = _container!.getAllProviderElements()
        .where((element) => element.provider.name?.contains(keyPattern) ?? false)
        .map((element) => element.provider)
        .toList();

    for (final provider in matchingKeys) {
      _container!.invalidate(provider);
    }
    
    debugPrint('✅ QueryClient: Invalidated ${matchingKeys.length} providers for pattern: $keyPattern');
  }

  /// Invalidate all queries
  void invalidateAll() {
    // Always clear all cache
    _cache.clear();
    
    // If no container, cache clearing is all we can do
    if (_container == null) {
      debugPrint('⚠️ QueryClient: Provider invalidation not available. Only cache cleared.');
      return;
    }
    
    // Invalidate all providers in the container
    final elements = _container!.getAllProviderElements();
    for (final element in elements) {
      _container!.invalidate(element.provider);
    }
    
    debugPrint('✅ QueryClient: Invalidated all ${elements.length} providers and cleared cache.');
  }

  /// Remove queries from cache by key pattern
  void removeQueries(String keyPattern) {
    // Remove from cache
    _cache.removeByPattern(keyPattern);
    
    // Invalidate matching providers
    invalidateQueries(keyPattern);
    
    // Cancel any associated timers
    _refetchTimers.removeWhere((key, timer) {
      if (key.contains(keyPattern)) {
        timer.cancel();
        return true;
      }
      return false;
    });
  }

  /// Set query data manually in cache
  void setQueryData<T>(String queryKey, T data) {
    _cache.setData(queryKey, data);
  }

  /// Get query data from cache
  T? getQueryData<T>(String queryKey) {
    final entry = _cache.get<T>(queryKey);
    return entry?.hasData??false ? entry!.data as T : null;
  }

  /// Get cache entry with metadata
  QueryCacheEntry<T>? getCacheEntry<T>(String queryKey) {
    return _cache.get<T>(queryKey);
  }

  /// Check if query data exists in cache
  bool hasQueryData(String queryKey) {
    return _cache.containsKey(queryKey);
  }

  /// Get cache statistics
  QueryCacheStats getCacheStats() {
    return _cache.stats;
  }

  /// Clear all cache entries
  void clearCache() {
    _cache.clear();
  }

  /// Cleanup expired cache entries
  int cleanupCache() {
    return _cache.cleanup();
  }

  /// Get all cache keys
  List<String> getCacheKeys() {
    return _cache.keys;
  }

  /// Schedule automatic refetch for a query
  void scheduleRefetch(String key, Duration interval, VoidCallback refetch) {
    _refetchTimers[key]?.cancel();
    _refetchTimers[key] = Timer.periodic(interval, (_) => refetch());
  }

  /// Cancel scheduled refetch
  void cancelRefetch(String key) {
    _refetchTimers[key]?.cancel();
    _refetchTimers.remove(key);
  }

  /// Clean up timers only (for singleton usage)
  void _cleanupTimers() {
    for (final timer in _refetchTimers.values) {
      timer.cancel();
    }
    _refetchTimers.clear();
  }

  /// Dispose the client and clean up resources
  void dispose() {
    _cleanupTimers();
    // Note: We don't dispose the container here as it's shared with the widget tree
    // Note: We don't dispose the cache here as it might be shared
  }
}

/// Global query client provider - Singleton pattern with auto container setup
final queryClientProvider = Provider<QueryClient>((ref) {
  // Create a singleton instance and automatically set the container
  final client = QueryClient.instance;
  
  // Automatically set the container for provider invalidation support
  QueryClient.setContainer(ref.container);
  
  ref.onDispose(client._cleanupTimers);
  return client;
});

/// Mixin for providers that support query client operations
mixin QueryClientMixin {
  /// Get the query client from the provider ref
  QueryClient getQueryClient(Ref ref) => ref.read(queryClientProvider);
}
