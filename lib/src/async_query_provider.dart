import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lifecycle_manager.dart';
import 'query_cache.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'state_query_provider.dart'
    show QueryFunctionWithParamsWithRef, QueryFunctionWithRef;
import 'window_focus_manager.dart';

/// Base mixin for common query functionality
mixin BaseQueryMixin<T> {
  // Common fields
  late final QueryFunctionWithRef<T> queryFn;
  late final QueryOptions<T> options;
  late final String queryKey;
  late Ref _ref;

  Timer? _refetchTimer;
  int _retryCount = 0;

  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Initialize the query with common setup
  void initializeQuery({
    required QueryFunctionWithRef<T> queryFn,
    required QueryOptions<T> options,
    required String queryKey,
    required Ref ref,
  }) {
    this.queryFn = queryFn;
    this.options = options;
    this.queryKey = queryKey;
    _ref = ref;
    
    if (!_isInitialized) {
      _isInitialized = true;
      _isDisposed = false;

      _setupCacheListener();
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();

      ref.onDispose(() {
        _isDisposed = true;
        _refetchTimer?.cancel();
        _cache.removeAllListeners(queryKey);

        if (options.refetchOnAppFocus) {
          _lifecycleManager.removeOnResumeCallback(_onAppResumed);
        }
        if (options.pauseRefetchInBackground) {
          _lifecycleManager.removeOnPauseCallback(_onAppPaused);
        }
        if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
          _windowFocusManager.removeOnFocusCallback(_onWindowFocused);
        }

        _isInitialized = false;
      });
    }
  }

  /// Safe state update that checks if disposed
  void safeStateUpdate(AsyncValue<T> newState) {
    if (!_isDisposed) {
      // This will be implemented by the concrete class
      updateState(newState);
    }
  }

  /// Abstract method to update state - implemented by concrete classes
  void updateState(AsyncValue<T> newState);

  /// Perform the actual data fetch
  Future<T> performFetch() async {
    try {
      debugPrint('Performing fetch in query notifier $queryKey');
      final data = await queryFn(_ref);
      final now = DateTime.now();

      // Cache the result
      setCachedEntry(QueryCacheEntry<T>(
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
        return performFetch();
      }

      rethrow;
    }
  }

  /// Background refetch without changing loading state
  Future<void> backgroundRefetch() async {
    try {
      debugPrint('Background refetching in query notifier $queryKey');
      final data = await performFetch();
      safeStateUpdate(AsyncValue.data(data));
    } catch (error, stackTrace) {
      // Silent background refresh failure - don't update state
      debugPrint('Background refresh failed: $error in query notifier $queryKey');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Public method to refetch data
  Future<void> refetch({bool background = false}) async {
    debugPrint('Refetching in query notifier $queryKey');
    if (background) {
      return backgroundRefetch();
    }
    safeStateUpdate(const AsyncValue.loading());
    try {
      final data = await performFetch();
      safeStateUpdate(AsyncValue.data(data));
    } catch (error, stackTrace) {
      safeStateUpdate(AsyncValue.error(error, stackTrace));
    }
  }

  /// Force refresh (ignore cache)
  Future<void> refresh() async {
    invalidateCache();
    await refetch();
  }

  /// Helper methods for cache operations
  QueryCacheEntry<T>? getCachedEntry() {
    return _cache.get<T>(queryKey);
  }

  void setCachedEntry(QueryCacheEntry<T> entry) {
    _cache.set(queryKey, entry);
  }

  void invalidateCache() {
    _cache.remove(queryKey);
  }

  /// Set up cache change listener
  void _setupCacheListener() {
    _cache.addListener<T>(queryKey, (QueryCacheEntry<T>? entry) {
      debugPrint('Cache listener called for key $queryKey in query notifier');
      if ((entry?.hasData ?? false) && !(hasCurrentValue && entry!.data == getCurrentValue)) {
        debugPrint('Cache data changed for key $queryKey in query notifier');
        safeStateUpdate(AsyncValue.data(entry!.data as T));
      } else if (entry == null) {
        debugPrint('Cache entry removed for key $queryKey in query notifier');
        if (options.onCacheEvicted != null) {
          options.onCacheEvicted!(queryKey);
        } else if (!_isDisposed) {
          refetch();
        }
      }
    });
  }

  /// Abstract methods for state access - implemented by concrete classes
  bool get hasCurrentValue;
  T? get getCurrentValue;

  /// Set up lifecycle callbacks
  void _setupLifecycleCallbacks() {
    debugPrint('Setting up lifecycle callbacks in query notifier $queryKey');
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResumed);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPaused);
    }
  }

  /// Set up window focus callbacks
  void _setupWindowFocusCallbacks() {
    debugPrint('Setting up window focus callbacks in query notifier $queryKey');
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocused);
    }
  }

  /// Schedule automatic refetching
  void scheduleRefetch() {
    debugPrint('Scheduling automatic refetching in query notifier $queryKey');
    final interval = options.refetchInterval;
    if (interval != null && !_isRefetchPaused) {
      _refetchTimer?.cancel();
      _refetchTimer = Timer.periodic(interval, (_) {
        if (!_isRefetchPaused && options.enabled) {
          backgroundRefetch();
        }
      });
    }
  }

  /// Callback for app resumed
  void _onAppResumed() {
    debugPrint('App resumed in query notifier $queryKey');
    _isRefetchPaused = false;

    if (options.enabled) {
      final cachedEntry = getCachedEntry();
      if (cachedEntry != null && cachedEntry.isStale) {
        backgroundRefetch();
      }
    }
  }

  /// Callback for app paused
  void _onAppPaused() {
    debugPrint('App paused in query notifier $queryKey');
    _isRefetchPaused = true;
  }

  /// Callback for window focused
  void _onWindowFocused() {
    debugPrint('Window focused in query notifier $queryKey');
    if (options.enabled && !_isRefetchPaused) {
      final cachedEntry = getCachedEntry();
      if (cachedEntry != null && cachedEntry.isStale) {
        backgroundRefetch();
      }
    }
  }

  /// Pause automatic refetching
  void pauseRefetch() {
    debugPrint('Pausing automatic refetching in query notifier $queryKey');
    _isRefetchPaused = true;
    _refetchTimer?.cancel();
  }

  /// Resume automatic refetching
  void resumeRefetch() {  
    debugPrint('Resuming automatic refetching in query notifier $queryKey');
    _isRefetchPaused = false;
    if (options.refetchInterval != null) {
      scheduleRefetch();
    }
  }
}

/// Base mixin for family query functionality
mixin BaseQueryFamilyMixin<T, P> {
  // Common fields
  late final QueryFunctionWithParamsWithRef<T, P> queryFn;
  late final QueryOptions<T> options;
  late final String queryKey;
  late Ref _ref;

  Timer? _refetchTimer;
  int _retryCount = 0;

  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  /// Initialize the family query with common setup
  void initializeFamilyQuery({
    required QueryFunctionWithParamsWithRef<T, P> queryFn,
    required QueryOptions<T> options,
    required String queryKey,
    required Ref ref,
  }) {
    this.queryFn = queryFn;
    this.options = options;
    this.queryKey = queryKey;
    _ref = ref;
    
    if (!_isInitialized) {
      _isInitialized = true;
      _isDisposed = false;
      
      ref.onDispose(() {
        _isDisposed = true;
        _refetchTimer?.cancel();
        // Note: Cache listeners are removed per-parameter in the concrete implementations

        if (options.refetchOnAppFocus) {
          _lifecycleManager.removeOnResumeCallback(_onAppResumed);
        }
        if (options.pauseRefetchInBackground) {
          _lifecycleManager.removeOnPauseCallback(_onAppPaused);
        }
        if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
          _windowFocusManager.removeOnFocusCallback(_onWindowFocused);
        }

        _isInitialized = false;
      });
    }
  }

  /// Safe state update that checks if disposed
  void safeStateUpdate(AsyncValue<T> newState) {
    if (!_isDisposed) {
      updateState(newState);
    }
  }

  /// Abstract method to update state - implemented by concrete classes
  void updateState(AsyncValue<T> newState);

  /// Get parameterized cache key
  String getParamKey(P arg) => '$queryKey-$arg';

  /// Perform the actual data fetch with parameter
  Future<T> performFetch(P arg) async {
    try {
      debugPrint('Performing fetch in query notifier family $queryKey');
      final data = await queryFn(_ref, arg);
      final now = DateTime.now();
      final paramKey = getParamKey(arg);

      // Cache the result
      setCachedEntry(paramKey, QueryCacheEntry<T>(
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
        return performFetch(arg);
      }

      rethrow;
    }
  }

  /// Background refetch without changing loading state
  Future<void> backgroundRefetch(P arg) async {
    try {
      debugPrint('Background refetching in query notifier family $queryKey');
      final data = await performFetch(arg);
      safeStateUpdate(AsyncValue.data(data));
    } catch (error, stackTrace) {
      // Silent background refresh failure - don't update state
      debugPrint('Background refresh failed: $error in query notifier family $queryKey');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Public method to refetch data
  Future<void> refetch({bool background = false});

  /// Force refresh (ignore cache)
  Future<void> refresh(P arg) async {
    invalidateCache(getParamKey(arg));
    await refetch();
  }

  /// Helper methods for cache operations
  QueryCacheEntry<T>? getCachedEntry(String key) {
    return _cache.get<T>(key);
  }

  void setCachedEntry(String key, QueryCacheEntry<T> entry) {
    _cache.set(key, entry);
  }

  void invalidateCache(String key) {
    _cache.remove(key);
  }

  /// Set up cache change listener for parameterized queries
  void setupCacheListener(String key) {
    _cache.addListener<T>(key, (QueryCacheEntry<T>? entry) {
      debugPrint('Cache listener called for key $key in query notifier family');
      if ((entry?.hasData ?? false) && !(hasCurrentValue && entry!.data == getCurrentValue)) {
        debugPrint('Cache data changed for key $key in query notifier family');
        safeStateUpdate(AsyncValue.data(entry!.data as T));
      } else if (entry == null) {
        debugPrint('Cache entry removed for key $key in query notifier family');
        if (options.onCacheEvicted != null) {
          options.onCacheEvicted!(key);
        } else if (!_isDisposed) {
          // Note: This would need the current arg, but we can't access it here
          // This is a limitation of the current design
        }
      }
    });
  }

  /// Abstract methods for state access - implemented by concrete classes
  bool get hasCurrentValue;
  T? get getCurrentValue;

  /// Set up lifecycle callbacks
  void setupLifecycleCallbacks() {
    debugPrint('Setting up lifecycle callbacks in query notifier family $queryKey');
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResumed);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPaused);
    }
  }

  /// Set up window focus callbacks
  void setupWindowFocusCallbacks() {
    debugPrint('Setting up window focus callbacks in query notifier family $queryKey');
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocused);
    }
  }

  /// Schedule automatic refetching
  void scheduleRefetch(P arg) {
    debugPrint('Scheduling automatic refetching in query notifier family $queryKey');
    final interval = options.refetchInterval;
    if (interval != null && !_isRefetchPaused) {
      _refetchTimer?.cancel();
      _refetchTimer = Timer.periodic(interval, (_) {
        if (!_isRefetchPaused && options.enabled) {
          backgroundRefetch(arg);
        }
      });
    }
  }

  /// Callback for app resumed
  void _onAppResumed() {
    debugPrint('App resumed in query notifier family $queryKey');
    _isRefetchPaused = false;

    if (options.enabled) {
      // Note: This would need the current arg, but we can't access it here
      // This is a limitation of the current design
    }
  }

  /// Callback for app paused
  void _onAppPaused() {
    debugPrint('App paused in query notifier family $queryKey');
    _isRefetchPaused = true;
  }

  /// Callback for window focused
  void _onWindowFocused() {
    debugPrint('Window focused in query notifier family $queryKey');
    if (options.enabled && !_isRefetchPaused) {
      // Note: This would need the current arg, but we can't access it here
      // This is a limitation of the current design
    }
  }

  /// Pause automatic refetching
  void pauseRefetch() {
    _isRefetchPaused = true;
    _refetchTimer?.cancel();
  }

  /// Resume automatic refetching
  void resumeRefetch(P arg) {
    _isRefetchPaused = false;
    if (options.refetchInterval != null) {
      scheduleRefetch(arg);
    }
  }
}

/// 🔥 Modern AsyncNotifier-based query implementation
class AsyncQueryNotifier<T> extends AsyncNotifier<T> with QueryClientMixin, BaseQueryMixin<T> {
  AsyncQueryNotifier({
    required QueryFunctionWithRef<T> queryFn,
    required QueryOptions<T> options,
    required String queryKey,
  }) {
    initializeQuery(
      queryFn: queryFn,
      options: options,
      queryKey: queryKey,
      ref: ref,
    );
  }

  @override
  FutureOr<T> build() async {
    debugPrint('Building async query notifier with cached data, $queryKey');
    
    // Set up automatic refetching if configured
    if (options.enabled && options.refetchInterval != null) {
      scheduleRefetch();
    }

    // Check cache first
    if (options.enabled) {
      final cachedEntry = getCachedEntry();
      if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
        // Return cached data immediately, optionally trigger background refresh
        if (options.refetchOnMount) {
          unawaited(Future.microtask(() => backgroundRefetch().catchError((Object error) {
            debugPrint('Error in background refetch: $error');
          })));
        }
        debugPrint('Returning cached data in async query notifier');
        return cachedEntry.data as T;
      }

      if (options.keepPreviousData &&
          ((!_isDisposed && state.hasValue) ||
              (cachedEntry != null && cachedEntry.hasData))) {
        unawaited(Future.microtask(() => backgroundRefetch().catchError((Object error) {
          debugPrint('Error in background refetch: $error');
        })));

        debugPrint('Keeping previous data in async query notifier');
        return (!_isDisposed && state.hasValue)
            ? state.value as T
            : cachedEntry?.data as T;
      }
    }

    // No cache or disabled - fetch fresh data
    if (!options.enabled) {
      throw StateError('Query is disabled and no cached data available');
    }

    return await performFetch();
  }

  @override
  void updateState(AsyncValue<T> newState) {
    state = newState;
  }

  @override
  bool get hasCurrentValue => state.hasValue;

  @override
  T? get getCurrentValue => state.value;
}

/// AsyncNotifier with parameters - full-featured implementation
class AsyncQueryNotifierFamily<T, P> extends FamilyAsyncNotifier<T, P>
    with QueryClientMixin, BaseQueryFamilyMixin<T, P> {
  AsyncQueryNotifierFamily({
    required QueryFunctionWithParamsWithRef<T, P> queryFn,
    required QueryOptions<T> options,
    required String queryKey,
  }) {
    initializeFamilyQuery(
      queryFn: queryFn,
      options: options,
      queryKey: queryKey,
      ref: ref,
    );
  }

  @override
  FutureOr<T> build(P arg) async {
    final paramKey = getParamKey(arg);
    debugPrint('Building async query notifier family with cached data, $paramKey');
    
    // Set up cache listener for this specific parameter
    setupCacheListener(paramKey);
    setupLifecycleCallbacks();
    setupWindowFocusCallbacks();
    
    // Clean up cache listener when this specific parameter is disposed
    ref.onDispose(() {
      _cache.removeAllListeners(paramKey);
    });

    // Set up automatic refetching if configured
    if (options.enabled && options.refetchInterval != null) {
      scheduleRefetch(arg);
    }

    // Check cache first
    if (options.enabled) {
      final cachedEntry = getCachedEntry(paramKey);
      if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
        // Return cached data immediately, optionally trigger background refresh
        if (options.refetchOnMount) {
          unawaited(Future.microtask(() => backgroundRefetch(arg).catchError((Object error) {
            debugPrint('Error in background refetch: $error');
          })));
        }
        debugPrint('Returning cached data in async query notifier family $paramKey');
        return cachedEntry.data as T;
      }

      if (options.keepPreviousData &&
          ((!_isDisposed && state.hasValue) ||
              (cachedEntry != null && cachedEntry.hasData))) {
        unawaited(Future.microtask(() => backgroundRefetch(arg).catchError((Object error) {
          debugPrint('Error in background refetch: $error');
        })));
        debugPrint('Keeping previous data in async query notifier family $paramKey');
        return (!_isDisposed && state.hasValue)
            ? state.value as T
            : cachedEntry?.data as T;
      }
    }

    // No cache or disabled - fetch fresh data
    if (!options.enabled) {
      throw StateError('Query is disabled and no cached data available');
    }
    debugPrint('Fetching data in async query notifier family with cached data, $paramKey');
    return await performFetch(arg);
  }

  @override
  void updateState(AsyncValue<T> newState) {
    state = newState;
  }

  @override
  bool get hasCurrentValue => state.hasValue;

  @override
  T? get getCurrentValue => state.value;

  /// Public method to refetch data
  @override
  Future<void> refetch({bool background = false}) async {
    debugPrint('Refetching in query notifier family $queryKey');
    if (background) {
      return backgroundRefetch(arg);
    }
    safeStateUpdate(const AsyncValue.loading());
    try {
      final data = await performFetch(arg);
      safeStateUpdate(AsyncValue.data(data));
    } catch (error, stackTrace) {
      safeStateUpdate(AsyncValue.error(error, stackTrace));
    }
  }

}

/// Auto-dispose AsyncNotifier
class AsyncQueryNotifierAutoDispose<T> extends AutoDisposeAsyncNotifier<T>
    with QueryClientMixin, BaseQueryMixin<T> {
  AsyncQueryNotifierAutoDispose({
    required QueryFunctionWithRef<T> queryFn,
    required QueryOptions<T> options,
    required String queryKey,
  }) {
    initializeQuery(
      queryFn: queryFn,
      options: options,
      queryKey: queryKey,
      ref: ref,
    );
  }

  @override
  FutureOr<T> build() async {
    debugPrint('Building async query notifier auto dispose with cached data, $queryKey');

    if (options.enabled && options.refetchInterval != null) {
      scheduleRefetch();
    }

    if (options.enabled) {
      final cachedEntry = getCachedEntry();
      if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
        if (options.refetchOnMount) {
          unawaited(Future.microtask(() => backgroundRefetch().catchError((Object error) {
            debugPrint('Error in background refetch: $error');
          })));
        }
        return cachedEntry.data as T;
      }

      if (options.keepPreviousData &&
          ((!_isDisposed && state.hasValue) ||
              (cachedEntry != null && cachedEntry.hasData))) {
        unawaited(Future.microtask(() => backgroundRefetch().catchError((Object error) {
          debugPrint('Error in background refetch: $error');
        })));
        return (!_isDisposed && state.hasValue)
            ? state.value as T
            : cachedEntry?.data as T;
      }
    }

    if (!options.enabled) {
      throw StateError('Query is disabled and no cached data available');
    }
    debugPrint('Fetching data in async query notifier auto dispose with cached data, $queryKey');
    return await performFetch();
  }

  @override
  void updateState(AsyncValue<T> newState) {
    state = newState;
  }

  @override
  bool get hasCurrentValue => state.hasValue;

  @override
  T? get getCurrentValue => state.value;
}

/// Auto-dispose AsyncNotifier with parameters
class AsyncQueryNotifierFamilyAutoDispose<T, P>
    extends AutoDisposeFamilyAsyncNotifier<T, P> with QueryClientMixin, BaseQueryFamilyMixin<T, P> {
  AsyncQueryNotifierFamilyAutoDispose({
    required QueryFunctionWithParamsWithRef<T, P> queryFn,
    required QueryOptions<T> options,
    required String queryKey,
  }) {
    initializeFamilyQuery(
      queryFn: queryFn,
      options: options,
      queryKey: queryKey,
      ref: ref,
    );
  }

  @override
  FutureOr<T> build(P arg) async {
    final paramKey = getParamKey(arg);
    debugPrint('Building async query notifier family auto dispose with cached data, $paramKey');

    // Set up cache listener for this specific parameter
    setupCacheListener(paramKey);
    setupLifecycleCallbacks();
    setupWindowFocusCallbacks();
    
    // Clean up cache listener when this specific parameter is disposed
    ref.onDispose(() {
      _cache.removeAllListeners(paramKey);
    });

    if (options.enabled && options.refetchInterval != null) {
      scheduleRefetch(arg);
    }

    if (options.enabled) {
      final cachedEntry = getCachedEntry(paramKey);
      if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
        if (options.refetchOnMount) {
          unawaited(Future.microtask(() => backgroundRefetch(arg).catchError((Object error) {
            debugPrint('Error in background refetch: $error');
          })));
        }
        return cachedEntry.data as T;
      }

      if (options.keepPreviousData &&
          ((!_isDisposed && state.hasValue) ||
              (cachedEntry != null && cachedEntry.hasData))) {
        unawaited(Future.microtask(() => backgroundRefetch(arg).catchError((Object error) {
          debugPrint('Error in background refetch: $error');
        })));
        return (!_isDisposed && state.hasValue)
            ? state.value as T
            : cachedEntry?.data as T;
      }
    }

    if (!options.enabled) {
      throw StateError('Query is disabled and no cached data available');
    }

    return await performFetch(arg);
  }

  @override
  void updateState(AsyncValue<T> newState) {
    state = newState;
  }

  @override
  bool get hasCurrentValue => state.hasValue;

  @override
  T? get getCurrentValue => state.value;

  /// Public method to refetch data
  @override
  Future<void> refetch({bool background = false}) async {
    debugPrint('Refetching in query notifier family $queryKey');
    if (background) {
      return backgroundRefetch(arg);
    }
    safeStateUpdate(const AsyncValue.loading());
    try {
      final data = await performFetch(arg);
      safeStateUpdate(AsyncValue.data(data));
    } catch (error, stackTrace) {
      safeStateUpdate(AsyncValue.error(error, stackTrace));
    }
  }
}

// ========================================
// PROVIDER FACTORY FUNCTIONS
// ========================================

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
  required QueryFunctionWithRef<T> queryFn,
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

/// 🔥 Auto-dispose AsyncNotifier-based query provider
///
/// **Use this when:**
/// - Temporary data that should be cleaned up when not watched
/// - Memory optimization for large datasets
/// - Short-lived screens or components
/// - Data that doesn't need to persist across navigation
///
/// **Features:**
/// - ✅ Automatic cleanup when no longer watched
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
/// final tempDataProvider = asyncQueryProviderAutoDispose<TempData>(
///   name: 'temp-data',
///   queryFn: (ref) => ApiService.fetchTempData(),
///   options: QueryOptions(
///     staleTime: Duration(minutes: 2),
///     cacheTime: Duration(minutes: 5),
///   ),
/// );
///
/// // Usage in widget:
/// final tempDataAsync = ref.watch(tempDataProvider);
/// tempDataAsync.when(
///   loading: () => CircularProgressIndicator(),
///   error: (error, stack) => Text('Error: $error'),
///   data: (data) => DataWidget(data),
/// );
/// ```
AutoDisposeAsyncNotifierProvider<AsyncQueryNotifierAutoDispose<T>, T>
    asyncQueryProviderAutoDispose<T>({
  required String name,
  required QueryFunctionWithRef<T> queryFn,
  QueryOptions<T>? options,
}) {
  return AsyncNotifierProvider.autoDispose<AsyncQueryNotifierAutoDispose<T>, T>(
    () {
      return AsyncQueryNotifierAutoDispose<T>(
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
AsyncNotifierProviderFamily<AsyncQueryNotifierFamily<T, P>, T, P>
    asyncQueryProviderFamily<T, P>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, P> queryFn,
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

/// 🔥 Auto-dispose AsyncNotifier-based query provider with parameters
///
/// **Use this when:**
/// - Dynamic parameters that change frequently
/// - Temporary data that should be cleaned up when not watched
/// - Memory optimization for large datasets with many parameter variations
/// - Short-lived screens with parameterized data
/// - User-specific data that doesn't need to persist
///
/// **Features:**
/// - ✅ Automatic cleanup when no longer watched
/// - ✅ Parameter-based caching and invalidation
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
/// final userDetailProvider = asyncQueryProviderFamilyAutoDispose<User, int>(
///   name: 'user-detail',
///   queryFn: (ref, userId) => ApiService.fetchUser(userId),
///   options: QueryOptions(
///     staleTime: Duration(minutes: 5),
///     cacheTime: Duration(minutes: 10),
///     keepPreviousData: true,
///   ),
/// );
///
/// // Usage in widget:
/// final userAsync = ref.watch(userDetailProvider(userId));
/// userAsync.when(
///   loading: () => CircularProgressIndicator(),
///   error: (error, stack) => ErrorWidget(error),
///   data: (user) => UserDetailWidget(user),
/// );
/// ```
AutoDisposeAsyncNotifierProviderFamily<
    AsyncQueryNotifierFamilyAutoDispose<T, P>,
    T,
    P> asyncQueryProviderFamilyAutoDispose<T, P>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, P> queryFn,
  QueryOptions<T>? options,
}) {
  return AsyncNotifierProvider.autoDispose
      .family<AsyncQueryNotifierFamilyAutoDispose<T, P>, T, P>(
    () {
      return AsyncQueryNotifierFamilyAutoDispose<T, P>(
        queryFn: queryFn,
        options: options ?? QueryOptions<T>(),
        queryKey: name,
      );
    },
    name: name,
  );
}