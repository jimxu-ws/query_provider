import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lifecycle_manager.dart';
import 'query_cache.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'query_provider.dart' show QueryFunction, QueryFunctionWithParams;
import 'window_focus_manager.dart';

/// 🔥 Modern AsyncNotifier-based query implementation
class AsyncQueryNotifier<T> extends AsyncNotifier<T> with QueryClientMixin {
  AsyncQueryNotifier({
    required this.queryFn,
    required this.options,
    required this.queryKey,
  });

  final QueryFunction<T> queryFn;
  final QueryOptions<T> options;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;
  late final QueryCache _cache;
  late final AppLifecycleManager _lifecycleManager;
  late final WindowFocusManager _windowFocusManager;
  bool _isRefetchPaused = false;

  @override
  FutureOr<T> build() async {
    // Initialize cache, lifecycle manager, and window focus manager
    _cache = getGlobalQueryCache();
    _lifecycleManager = AppLifecycleManager.instance;
    _windowFocusManager = WindowFocusManager.instance;
    
    // Set up cache change listener for automatic UI updates
    _setupCacheListener();
    
    // Set up lifecycle and window focus callbacks
    _setupLifecycleCallbacks();
    _setupWindowFocusCallbacks();
    
    // Set up automatic refetching if configured
    if (options.refetchInterval != null) {
      _scheduleRefetch();
    }

    // Set up cleanup when the notifier is disposed
    ref.onDispose(() {
      _refetchTimer?.cancel();
      _cache.removeAllListeners(queryKey);
      
      // Clean up lifecycle callbacks
      if (options.refetchOnAppFocus) {
        _lifecycleManager.removeOnResumeCallback(_onAppResumed);
      }
      if (options.pauseRefetchInBackground) {
        _lifecycleManager.removeOnPauseCallback(_onAppPaused);
      }
      
      // Clean up window focus callbacks
      if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
        _windowFocusManager.removeOnFocusCallback(_onWindowFocused);
      }
    });

    // Check cache first
    if (options.enabled) {
      final cachedEntry = _getCachedEntry();
      if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
        // Return cached data immediately, optionally trigger background refresh
        if (options.refetchOnMount) {
          Future.microtask(() => _backgroundRefetch());
        }
        return cachedEntry.data as T;
      }
    }

    // No cache or disabled - fetch fresh data
    if (!options.enabled) {
      throw StateError('Query is disabled and no cached data available');
    }

    return await _performFetch();
  }

  /// Perform the actual data fetch
  Future<T> _performFetch() async {
    try {
      final data = await queryFn();
      final now = DateTime.now();
      
      // Cache the result
      _setCachedEntry(QueryCacheEntry<T>(
        data: data,
        fetchedAt: now,
        options: options,
      ));

      _retryCount = 0;
      options.onSuccess?.call(data);
      
      return data;
    } catch (error, stackTrace) {
      options.onError?.call(error, stackTrace);
      
      // Handle retry logic
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return await _performFetch();
      }
      
      rethrow;
    }
  }

  /// Background refetch without changing loading state
  Future<void> _backgroundRefetch() async {
    try {
      final data = await _performFetch();
      state = AsyncValue.data(data);
    } catch (error, stackTrace) {
      // Silent background refresh failure - don't update state
      debugPrint('Background refresh failed: $error');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Public method to refetch data
  Future<void> refetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await _performFetch();
      state = AsyncValue.data(data);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Force refresh (ignore cache)
  Future<void> refresh() async {
    _invalidateCache();
    await refetch();
  }

  /// Helper methods for cache operations
  QueryCacheEntry<T>? _getCachedEntry() {
    return _cache.get<T>(queryKey);
  }

  void _setCachedEntry(QueryCacheEntry<T> entry) {
    _cache.set(queryKey, entry);
  }

  void _invalidateCache() {
    _cache.remove(queryKey);
  }

  /// Set up cache change listener
  void _setupCacheListener() {
    _cache.addListener<T>(queryKey, (QueryCacheEntry<T>? entry) {
      if (entry?.hasData ?? false) {
        state = AsyncValue.data(entry!.data as T);
      }
    });
  }

  /// Set up lifecycle callbacks
  void _setupLifecycleCallbacks() {
    // Refetch when app comes to foreground (if enabled and data is stale)
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResumed);
    }
    
    // Pause refetching when app goes to background (if enabled)
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPaused);
    }
  }

  /// Set up window focus callbacks
  void _setupWindowFocusCallbacks() {
    // Refetch when window gains focus (if enabled and data is stale)
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocused);
    }
  }

  /// Schedule automatic refetching
  void _scheduleRefetch() {
    final interval = options.refetchInterval;
    if (interval != null && !_isRefetchPaused) {
      _refetchTimer?.cancel();
      _refetchTimer = Timer.periodic(interval, (_) {
        if (!_isRefetchPaused && options.enabled) {
          _backgroundRefetch();
        }
      });
    }
  }

  /// Callback for app resumed
  void _onAppResumed() {
    // Resume refetching and check if we need to refetch stale data
    _isRefetchPaused = false;
    
    if (options.enabled) {
      final cachedEntry = _getCachedEntry();
      if (cachedEntry != null && cachedEntry.isStale) {
        _backgroundRefetch();
      }
    }
  }

  /// Callback for app paused
  void _onAppPaused() {
    // Mark refetching as paused
    _isRefetchPaused = true;
  }

  /// Callback for window focused
  void _onWindowFocused() {
    if (options.enabled && !_isRefetchPaused) {
      final cachedEntry = _getCachedEntry();
      if (cachedEntry != null && cachedEntry.isStale) {
        _backgroundRefetch();
      }
    }
  }

  /// Pause automatic refetching
  void pauseRefetch() {
    _isRefetchPaused = true;
    _refetchTimer?.cancel();
  }

  /// Resume automatic refetching
  void resumeRefetch() {
    _isRefetchPaused = false;
    if (options.refetchInterval != null) {
      _scheduleRefetch();
    }
  }
}

/// AsyncNotifier with parameters - focuses on core functionality
class AsyncQueryNotifierFamily<T, P> extends FamilyAsyncNotifier<T, P> {
  AsyncQueryNotifierFamily({
    required this.queryFn,
    required this.options,
    required this.queryKey,
  });

  final QueryFunctionWithParams<T, P> queryFn;
  final QueryOptions<T> options;
  final String queryKey;

  @override
  FutureOr<T> build(P arg) async {
    ref.read(queryClientProvider);
    // Simple implementation - just fetch the data
    if (!options.enabled) {
      throw StateError('Query is disabled');
    }
    
    try {
      final data = await queryFn(arg);
      options.onSuccess?.call(data);
      return data;
    } catch (error, stackTrace) {
      options.onError?.call(error, stackTrace);
      rethrow;
    }
  }

  /// Public method to refetch data
  Future<void> refetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await queryFn(arg);
      state = AsyncValue.data(data);
      options.onSuccess?.call(data);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      options.onError?.call(error, stackTrace);
    }
  }
}

/// AutoDispose AsyncNotifier without parameters - focuses on core functionality with automatic cleanup
class AutoDisposeAsyncQueryNotifier<T> extends AutoDisposeAsyncNotifier<T> with QueryClientMixin {
  AutoDisposeAsyncQueryNotifier({
    required this.queryFn,
    required this.options,
    required this.queryKey,
  });

  final QueryFunction<T> queryFn;
  final QueryOptions<T> options;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;
  late final QueryCache _cache;
  late final AppLifecycleManager _lifecycleManager;
  late final WindowFocusManager _windowFocusManager;
  bool _isRefetchPaused = false;

  @override
  FutureOr<T> build() async {
    // Initialize cache, lifecycle manager, and window focus manager
    _cache = getGlobalQueryCache();
    _lifecycleManager = AppLifecycleManager.instance;
    _windowFocusManager = WindowFocusManager.instance;
    
    // Set up cache change listener for automatic UI updates
    _setupCacheListener();
    
    // Set up lifecycle and window focus callbacks
    _setupLifecycleCallbacks();
    _setupWindowFocusCallbacks();
    
    // Set up automatic refetching if configured
    if (options.refetchInterval != null) {
      _scheduleRefetch();
    }

    // Set up cleanup when the notifier is disposed
    ref.onDispose(() {
      _refetchTimer?.cancel();
      _cache.removeAllListeners(queryKey);
      
      // Clean up lifecycle callbacks
      if (options.refetchOnAppFocus) {
        _lifecycleManager.removeOnResumeCallback(_onAppResumed);
      }
      if (options.pauseRefetchInBackground) {
        _lifecycleManager.removeOnPauseCallback(_onAppPaused);
      }
      
      // Clean up window focus callbacks
      if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
        _windowFocusManager.removeOnFocusCallback(_onWindowFocused);
      }
    });

    // Check cache first
    if (options.enabled) {
      final cachedEntry = _getCachedEntry();
      if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
        // Return cached data immediately, optionally trigger background refresh
        if (options.refetchOnMount) {
          Future.microtask(() => _backgroundRefetch());
        }
        return cachedEntry.data as T;
      }
    }

    // No cache or disabled - fetch fresh data
    if (!options.enabled) {
      throw StateError('Query is disabled and no cached data available');
    }

    return await _performFetch();
  }

  /// Perform the actual data fetch
  Future<T> _performFetch() async {
    try {
      final data = await queryFn();
      final now = DateTime.now();
      
      // Cache the result
      _setCachedEntry(QueryCacheEntry<T>(
        data: data,
        fetchedAt: now,
        options: options,
      ));

      _retryCount = 0;
      options.onSuccess?.call(data);
      
      return data;
    } catch (error, stackTrace) {
      options.onError?.call(error, stackTrace);
      
      // Handle retry logic
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return await _performFetch();
      }
      
      rethrow;
    }
  }

  /// Background refetch without changing loading state
  Future<void> _backgroundRefetch() async {
    try {
      final data = await _performFetch();
      state = AsyncValue.data(data);
    } catch (error, stackTrace) {
      // Silent background refresh failure - don't update state
      debugPrint('Background refresh failed: $error');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Public method to refetch data
  Future<void> refetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await _performFetch();
      state = AsyncValue.data(data);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Force refresh (ignore cache)
  Future<void> refresh() async {
    _invalidateCache();
    await refetch();
  }

  /// Helper methods for cache operations
  QueryCacheEntry<T>? _getCachedEntry() {
    return _cache.get<T>(queryKey);
  }

  void _setCachedEntry(QueryCacheEntry<T> entry) {
    _cache.set(queryKey, entry);
  }

  void _invalidateCache() {
    _cache.remove(queryKey);
  }

  /// Set up cache change listener
  void _setupCacheListener() {
    _cache.addListener<T>(queryKey, (QueryCacheEntry<T>? entry) {
      if (entry?.hasData ?? false) {
        state = AsyncValue.data(entry!.data as T);
      }
    });
  }

  /// Set up lifecycle callbacks
  void _setupLifecycleCallbacks() {
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResumed);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPaused);
    }
  }

  /// Set up window focus callbacks
  void _setupWindowFocusCallbacks() {
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocused);
    }
  }

  /// Schedule automatic refetching
  void _scheduleRefetch() {
    final interval = options.refetchInterval;
    if (interval != null && !_isRefetchPaused) {
      _refetchTimer?.cancel();
      _refetchTimer = Timer.periodic(interval, (_) {
        if (!_isRefetchPaused && options.enabled) {
          _backgroundRefetch();
        }
      });
    }
  }

  /// Callback for app resumed
  void _onAppResumed() {
    _isRefetchPaused = false;
    if (options.enabled) {
      final cachedEntry = _getCachedEntry();
      if (cachedEntry != null && cachedEntry.isStale) {
        _backgroundRefetch();
      }
    }
  }

  /// Callback for app paused
  void _onAppPaused() {
    _isRefetchPaused = true;
  }

  /// Callback for window focused
  void _onWindowFocused() {
    if (options.enabled && !_isRefetchPaused) {
      final cachedEntry = _getCachedEntry();
      if (cachedEntry != null && cachedEntry.isStale) {
        _backgroundRefetch();
      }
    }
  }
}

/// Full-featured AsyncNotifier with parameters and auto-dispose
class AutoDisposeAsyncQueryNotifierFamily<T, P> extends AutoDisposeFamilyAsyncNotifier<T, P> with QueryClientMixin {
  AutoDisposeAsyncQueryNotifierFamily({
    required this.queryFn,
    required this.options,
    required this.queryKey,
  });

  final QueryFunctionWithParams<T, P> queryFn;
  final QueryOptions<T> options;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;
  late final QueryCache _cache;
  late final AppLifecycleManager _lifecycleManager;
  late final WindowFocusManager _windowFocusManager;
  bool _isRefetchPaused = false;

  @override
  FutureOr<T> build(P arg) async {
    // Initialize cache, lifecycle manager, and window focus manager
    _cache = getGlobalQueryCache();
    _lifecycleManager = AppLifecycleManager.instance;
    _windowFocusManager = WindowFocusManager.instance;
    
    final paramKey = '$queryKey-$arg';
    
    // Set up cache change listener for automatic UI updates
    _setupCacheListener(paramKey);
    
    // Set up lifecycle and window focus callbacks
    _setupLifecycleCallbacks();
    _setupWindowFocusCallbacks();
    
    // Set up automatic refetching if configured
    if (options.refetchInterval != null) {
      _scheduleRefetch(arg);
    }

    // Set up cleanup when the notifier is disposed
    ref.onDispose(() {
      _refetchTimer?.cancel();
      _cache.removeAllListeners(paramKey);
      
      // Clean up lifecycle callbacks
      if (options.refetchOnAppFocus) {
        _lifecycleManager.removeOnResumeCallback(_onAppResumed);
      }
      if (options.pauseRefetchInBackground) {
        _lifecycleManager.removeOnPauseCallback(_onAppPaused);
      }
      
      // Clean up window focus callbacks
      if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
        _windowFocusManager.removeOnFocusCallback(_onWindowFocused);
      }
    });

    // Check cache first
    if (options.enabled) {
      final cachedEntry = _getCachedEntry(paramKey);
      if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
        // Return cached data immediately, optionally trigger background refresh
        if (options.refetchOnMount) {
          Future.microtask(() => _backgroundRefetch(arg));
        }
        return cachedEntry.data as T;
      }
    }

    // No cache or disabled - fetch fresh data
    if (!options.enabled) {
      throw StateError('Query is disabled and no cached data available');
    }

    return await _performFetch(arg);
  }

  /// Perform the actual data fetch
  Future<T> _performFetch(P arg) async {
    try {
      final data = await queryFn(arg);
      final now = DateTime.now();
      final paramKey = '$queryKey-$arg';
      
      // Cache the result
      _setCachedEntry(paramKey, QueryCacheEntry<T>(
        data: data,
        fetchedAt: now,
        options: options,
      ));

      _retryCount = 0;
      options.onSuccess?.call(data);
      
      return data;
    } catch (error, stackTrace) {
      options.onError?.call(error, stackTrace);
      
      // Handle retry logic
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return await _performFetch(arg);
      }
      
      rethrow;
    }
  }

  /// Background refetch without changing loading state
  Future<void> _backgroundRefetch(P arg) async {
    try {
      final data = await _performFetch(arg);
      state = AsyncValue.data(data);
    } catch (error, stackTrace) {
      // Silent background refresh failure - don't update state
      debugPrint('Background refresh failed: $error');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Public method to refetch data
  Future<void> refetch() async {
    state = const AsyncValue.loading();
    try {
      final data = await _performFetch(arg);
      state = AsyncValue.data(data);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Force refresh (ignore cache)
  Future<void> refresh() async {
    _invalidateCache('$queryKey-$arg');
    await refetch();
  }

  /// Helper methods for cache operations
  QueryCacheEntry<T>? _getCachedEntry(String key) {
    return _cache.get<T>(key);
  }

  void _setCachedEntry(String key, QueryCacheEntry<T> entry) {
    _cache.set(key, entry);
  }

  void _invalidateCache(String key) {
    _cache.remove(key);
  }

  /// Set up cache change listener
  void _setupCacheListener(String key) {
    _cache.addListener<T>(key, (QueryCacheEntry<T>? entry) {
      if (entry?.hasData ?? false) {
        state = AsyncValue.data(entry!.data as T);
      }
    });
  }

  /// Set up lifecycle callbacks
  void _setupLifecycleCallbacks() {
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResumed);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPaused);
    }
  }

  /// Set up window focus callbacks
  void _setupWindowFocusCallbacks() {
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocused);
    }
  }

  /// Schedule automatic refetching
  void _scheduleRefetch(P arg) {
    final interval = options.refetchInterval;
    if (interval != null && !_isRefetchPaused) {
      _refetchTimer?.cancel();
      _refetchTimer = Timer.periodic(interval, (_) {
        if (!_isRefetchPaused && options.enabled) {
          _backgroundRefetch(arg);
        }
      });
    }
  }

  /// Callback for app resumed
  void _onAppResumed() {
    _isRefetchPaused = false;
    if (options.enabled) {
      final cachedEntry = _getCachedEntry('$queryKey-$arg');
      if (cachedEntry != null && cachedEntry.isStale) {
        _backgroundRefetch(arg);
      }
    }
  }

  /// Callback for app paused
  void _onAppPaused() {
    _isRefetchPaused = true;
  }

  /// Callback for window focused
  void _onWindowFocused() {
    if (options.enabled && !_isRefetchPaused) {
      final cachedEntry = _getCachedEntry('$queryKey-$arg');
      if (cachedEntry != null && cachedEntry.isStale) {
        _backgroundRefetch(arg);
      }
    }
  }
}

/// 🔥 NEW: Create an autodisposed AsyncNotifier-based query provider
/// 
/// **Use this when:**
/// - Data is only needed temporarily
/// - You want automatic cleanup when widget is disposed
/// - Memory management is critical
/// - Data doesn't need to persist across widget rebuilds
/// 
/// Example:
/// ```dart
/// final dashboardDataProvider = autoDisposeAsyncQueryProvider<DashboardData>(
///   name: 'dashboardData',
///   queryFn: ApiService.fetchDashboardData,
///   options: QueryOptions(
///     staleTime: Duration(minutes: 5),
///     refetchOnWindowFocus: true,
///   ),
/// );
/// ```
AutoDisposeAsyncNotifierProvider<AutoDisposeAsyncQueryNotifier<T>, T> autoDisposeAsyncQueryProvider<T>({
  required String name,
  required QueryFunction<T> queryFn,
  QueryOptions<T>? options,
}) {
  return AsyncNotifierProvider.autoDispose<AutoDisposeAsyncQueryNotifier<T>, T>(() {
    return AutoDisposeAsyncQueryNotifier<T>(
      queryFn: queryFn,
      options: options ?? QueryOptions<T>(),
      queryKey: name,
    );
  });
}

/// 🔥 Regular AsyncNotifier-based query provider
/// 
/// **Use this when:**
/// - Data should persist across widget rebuilds
/// - Shared data across multiple widgets
/// - Long-lived cache requirements
/// 
/// Example:
/// ```dart
/// final usersProvider = asyncQueryProvider<List<User>>(
///   name: 'users',
///   queryFn: ApiService.fetchUsers,
///   options: QueryOptions(
///     staleTime: Duration(minutes: 5),
///     cacheTime: Duration(minutes: 10),
///   ),
/// );
/// 
/// // Usage in widget:
/// Widget build(BuildContext context, WidgetRef ref) {
///   final usersAsync = ref.watch(usersProvider);
///   return usersAsync.when(
///     loading: () => CircularProgressIndicator(),
///     error: (error, stack) => Text('Error: $error'),
///     data: (users) => ListView.builder(
///       itemCount: users.length,
///       itemBuilder: (context, index) => ListTile(
///         title: Text(users[index].name),
///       ),
///     ),
///   );
/// }
/// ```
AsyncNotifierProvider<AsyncQueryNotifier<T>, T> asyncQueryProvider<T>({
  required String name,
  required QueryFunction<T> queryFn,
  QueryOptions<T>? options,
}) {
  return AsyncNotifierProvider<AsyncQueryNotifier<T>, T>(() {
    return AsyncQueryNotifier<T>(
      queryFn: queryFn,
      options: options ?? QueryOptions<T>(),
      queryKey: name,
    );
  });
}

/// 🔥 NEW: Create an autodisposed AsyncNotifier-based query provider with parameters
/// 
/// **Use this when:**
/// - Parameters change frequently (user IDs, search queries, pagination)
/// - You want automatic cleanup when no longer watched
/// - Memory management is important
/// 
/// Example:
/// ```dart
/// final userProvider = autoDisposeAsyncQueryProviderFamily<User, int>(
///   name: 'user',
///   queryFn: ApiService.fetchUser,
///   options: QueryOptions(
///     staleTime: Duration(minutes: 5),
///     refetchOnWindowFocus: true,
///   ),
/// );
/// 
/// // Usage:
/// final userAsync = ref.watch(userProvider(userId));
/// ```
AutoDisposeAsyncNotifierProviderFamily<AutoDisposeAsyncQueryNotifierFamily<T, P>, T, P> autoDisposeAsyncQueryProviderFamily<T, P>({
  required String name,
  required QueryFunctionWithParams<T, P> queryFn,
  QueryOptions<T>? options,
}) {
  return AsyncNotifierProvider.autoDispose.family<AutoDisposeAsyncQueryNotifierFamily<T, P>, T, P>(() {
    return AutoDisposeAsyncQueryNotifierFamily<T, P>(
      queryFn: queryFn,
      options: options ?? QueryOptions<T>(),
      queryKey: name,
    );
  });
}

/// 🔥 Regular (non-autodisposed) AsyncNotifier-based query provider with parameters
/// 
/// **Use this when:**
/// - Parameters are relatively stable
/// - You want to keep data cached across widget rebuilds
/// - Shared data across multiple widgets
/// 
/// Example:
/// ```dart
/// final userProvider = asyncQueryProviderFamily<User, int>(
///   name: 'user',
///   queryFn: ApiService.fetchUser,
/// );
/// ```
AsyncNotifierProviderFamily<AsyncQueryNotifierFamily<T, P>, T, P> asyncQueryProviderFamily<T, P>({
  required String name,
  required QueryFunctionWithParams<T, P> queryFn,
  QueryOptions<T>? options,
}) {
  return AsyncNotifierProvider.family<AsyncQueryNotifierFamily<T, P>, T, P>(() {
    return AsyncQueryNotifierFamily<T, P>(
      queryFn: queryFn,
      options: options ?? QueryOptions<T>(),
      queryKey: name,
    );
  });
}
