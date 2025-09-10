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

  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;
  bool _isInitialized = false;

  @override
  FutureOr<T> build() async {
    // Prevent duplicate initialization
    if (!_isInitialized) {
      _isInitialized = true;
      
      // Set up cache change listener for automatic UI updates
      _setupCacheListener();
      
      // Set up lifecycle and window focus callbacks
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();
      
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
        
        // Reset initialization flag
        _isInitialized = false;
      });
    }

    // Set up automatic refetching if configured
    if (options.enabled && options.refetchInterval != null) {
      _scheduleRefetch();
    }

    // Check cache first
    if (options.enabled) {
      final cachedEntry = _getCachedEntry();
      if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
        // Return cached data immediately, optionally trigger background refresh
        if (options.refetchOnMount) {
          Future.microtask(() => _backgroundRefetch());
        }
        debugPrint('Returning cached data in async query notifier');
        return cachedEntry.data as T;
      }

      if(options.keepPreviousData && (state.hasValue || (cachedEntry != null && cachedEntry.hasData))){
        Future.microtask(() => _backgroundRefetch());

        debugPrint('Keeping previous data in async query notifier');
        return state.hasValue ? state.value as T : cachedEntry?.data as T;
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
      debugPrint('Performing fetch in async query notifier');
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
        return _performFetch();
      }
      
      rethrow;
    }
  }

  /// Background refetch without changing loading state
  Future<void> _backgroundRefetch() async {
    try {
      debugPrint('Background refetching in async query notifier');
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

/// AsyncNotifier with parameters - full-featured implementation
class AsyncQueryNotifierFamily<T, P> extends FamilyAsyncNotifier<T, P> with QueryClientMixin {
  AsyncQueryNotifierFamily({
    required this.queryFn,
    required this.options,
    required this.queryKey,
  });

  final QueryFunctionWithParams<T, P> queryFn;
  final QueryOptions<T> options;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;
  
  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;
  bool _isInitialized = false;

  @override
  FutureOr<T> build(P arg) async {
    final paramKey = '$queryKey-$arg';
    
    // Prevent duplicate initialization
    if (!_isInitialized) {
      _isInitialized = true;
      
      // Set up cache change listener for automatic UI updates
      _setupCacheListener(paramKey);
      
      // Set up lifecycle and window focus callbacks
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();
      
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
        
        // Reset initialization flag
        _isInitialized = false;
      });
    }

    // Set up automatic refetching if configured
    if (options.enabled && options.refetchInterval != null) {
      _scheduleRefetch(arg);
    }

    // Check cache first
    if (options.enabled) {
      final cachedEntry = _getCachedEntry(paramKey);
      if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
        // Return cached data immediately, optionally trigger background refresh
        if (options.refetchOnMount) {
          Future.microtask(() => _backgroundRefetch(arg));
        }
        debugPrint('Returning cached data in async query notifier family');
        return cachedEntry.data as T;
      }

      if (options.keepPreviousData && (state.hasValue || (cachedEntry != null && cachedEntry.hasData))) {
        Future.microtask(() => _backgroundRefetch(arg));
        debugPrint('Keeping previous data in async query notifier family');
        return state.hasValue ? state.value as T : cachedEntry?.data as T;
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
      debugPrint('Performing fetch in async query notifier family');
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
        return _performFetch(arg);
      }
      
      rethrow;
    }
  }

  /// Background refetch without changing loading state
  Future<void> _backgroundRefetch(P arg) async {
    try {
      debugPrint('Background refetching in async query notifier family');
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
      debugPrint('Cache listener called for key $key in async query notifier family, change state to ${state.runtimeType}');
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
    // Resume refetching and check if we need to refetch stale data
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
    // Mark refetching as paused
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

  /// Pause automatic refetching
  void pauseRefetch() {
    _isRefetchPaused = true;
    _refetchTimer?.cancel();
  }

  /// Resume automatic refetching
  void resumeRefetch() {
    _isRefetchPaused = false;
    if (options.refetchInterval != null) {
      _scheduleRefetch(arg);
    }
  }
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
  return AsyncNotifierProvider<AsyncQueryNotifier<T>, T>(
    () {
      return AsyncQueryNotifier<T>(
        queryFn: queryFn,
        options: options ?? QueryOptions<T>(),
        queryKey: name,
      );
    },
    name: name,
  );
}

/// 🔥 Full-featured AsyncNotifier-based query provider with parameters
/// 
/// **Use this when:**
/// - Parameters are relatively stable
/// - You want to keep data cached across widget rebuilds
/// - Shared data across multiple widgets
/// - You need all advanced query features (caching, lifecycle, retry, etc.)
/// 
/// **Features:**
/// - ✅ Full cache integration with staleTime/cacheTime
/// - ✅ Lifecycle management (app focus, window focus)
/// - ✅ Automatic refetching intervals
/// - ✅ Retry logic with exponential backoff
/// - ✅ Background refetch capabilities
/// - ✅ keepPreviousData support
/// - ✅ Memory leak prevention
/// 
/// Example:
/// ```dart
/// final userProvider = asyncQueryProviderFamily<User, int>(
///   name: 'user',
///   queryFn: ApiService.fetchUser,
///   options: QueryOptions(
///     staleTime: Duration(minutes: 5),
///     refetchInterval: Duration(minutes: 10),
///     refetchOnWindowFocus: true,
///     keepPreviousData: true,
///   ),
/// );
/// 
/// // Usage:
/// final userAsync = ref.watch(userProvider(userId));
/// userAsync.when(
///   loading: () => CircularProgressIndicator(),
///   error: (error, stack) => ErrorWidget(error),
///   data: (user) => UserWidget(user),
/// );
/// ```
AsyncNotifierProviderFamily<AsyncQueryNotifierFamily<T, P>, T, P> asyncQueryProviderFamily<T, P>({
  required String name,
  required QueryFunctionWithParams<T, P> queryFn,
  QueryOptions<T>? options,
}) {
  return AsyncNotifierProvider.family<AsyncQueryNotifierFamily<T, P>, T, P>(
    () {
      return AsyncQueryNotifierFamily<T, P>(
        queryFn: queryFn,
        options: options ?? QueryOptions<T>(),
        queryKey: name,
      );
    },
    name: name,
  );
}