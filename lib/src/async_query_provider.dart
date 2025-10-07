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

/// Base class for common query functionality
abstract class BaseQueryNotifier<T> extends AsyncNotifier<T> with QueryClientMixin {
  /// Constructor
  BaseQueryNotifier({
    required this.queryFn,
    required this.options,
    required this.queryKey,
  });

  /// Query function
  final QueryFunctionWithRef<T> queryFn;
  /// Query options
  final QueryOptions<T> options;
  /// Query key
  final String queryKey;

  /// Refetch timer
  Timer? _refetchTimer;
  /// Retry count
  int _retryCount = 0;

  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  /// Lifecycle manager
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  /// Window focus manager
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  /// Is refetch paused
  bool _isRefetchPaused = false;
  /// Is initialized
  bool _isInitialized = false;
  /// Is disposed
  bool _isDisposed = false;

  /// Initialize the query with common setup
  void initializeQuery(Ref ref) {
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
      state = newState;
    }
  }

  /// Has current value
  bool get hasCurrentValue => state.hasValue;

  /// Get current value
  T? get getCurrentValue => state.value;

  /// Perform the actual data fetch
  Future<T> performFetch() async {
    try {
      debugPrint('Performing fetch in query notifier $queryKey');
      final data = await queryFn(ref);
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

  /// Set cached entry
  void setCachedEntry(QueryCacheEntry<T> entry) {
    _cache.set(queryKey, entry);
  }

  /// Invalidate cache
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

/// Base class for family query functionality
abstract class BaseQueryFamilyNotifier<T, P> extends FamilyAsyncNotifier<T, P> with QueryClientMixin {
  /// Constructor
  BaseQueryFamilyNotifier({
    required this.queryFn,
    required this.options,
    required this.queryKey,
  });

  /// Query function
  final QueryFunctionWithParamsWithRef<T, P> queryFn;
  /// Query options
  final QueryOptions<T> options;
  final String queryKey;

  /// Refetch timer
  Timer? _refetchTimer;
  /// Retry count
  int _retryCount = 0;

  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  /// Is refetch paused
  bool _isRefetchPaused = false;
  /// Is initialized
  bool _isInitialized = false;
  /// Is disposed
  bool _isDisposed = false;

  /// Initialize the family query with common setup
  void initializeFamilyQuery(Ref ref) {
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
      state = newState;
    }
  }

  /// Has current value
  bool get hasCurrentValue => state.hasValue;

  /// Get current value
  T? get getCurrentValue => state.value;

  /// Get parameter key for caching
  String getParamKey(P param) => '$queryKey-$param';

  /// Perform the actual data fetch with parameter
  Future<T> performFetch(P param) async {
    try {
      debugPrint('Performing fetch in family query notifier $queryKey with param $param');
      final data = await queryFn(ref, param);
      final now = DateTime.now();

      // Cache the result with parameter key
      final paramKey = getParamKey(param);
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
        return performFetch(param);
      }

      rethrow;
    }
  }

  /// Background refetch without changing loading state
  Future<void> backgroundRefetch(P param) async {
    try {
      debugPrint('Background refetching in family query notifier $queryKey with param $param');
      final data = await performFetch(param);
      safeStateUpdate(AsyncValue.data(data));
    } catch (error, stackTrace) {
      // Silent background refresh failure - don't update state
      debugPrint('Background refresh failed: $error in family query notifier $queryKey');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Public method to refetch data
  Future<void> refetch({bool background = false}) async {
    final param = arg; // Get current parameter from FamilyAsyncNotifier
    debugPrint('Refetching in family query notifier $queryKey with param $param');
    if (background) {
      return backgroundRefetch(param);
    }
    safeStateUpdate(const AsyncValue.loading());
    try {
      final data = await performFetch(param);
      safeStateUpdate(AsyncValue.data(data));
    } catch (error, stackTrace) {
      safeStateUpdate(AsyncValue.error(error, stackTrace));
    }
  }

  /// Helper methods for cache operations
  QueryCacheEntry<T>? getCachedEntry(String paramKey) {
    return _cache.get<T>(paramKey);
  }

  void setCachedEntry(String paramKey, QueryCacheEntry<T> entry) {
    _cache.set(paramKey, entry);
  }

  void invalidateCache(String paramKey) {
    _cache.remove(paramKey);
  }

  /// Set up cache change listener for specific parameter
  void setupCacheListener(String paramKey) {
    _cache.addListener<T>(paramKey, (QueryCacheEntry<T>? entry) {
      debugPrint('Cache listener called for key $paramKey in family query notifier');
      if ((entry?.hasData ?? false) && !(hasCurrentValue && entry!.data == getCurrentValue)) {
        debugPrint('Cache data changed for key $paramKey in family query notifier');
        safeStateUpdate(AsyncValue.data(entry!.data as T));
      } else if (entry == null) {
        debugPrint('Cache entry removed for key $paramKey in family query notifier');
        if (options.onCacheEvicted != null) {
          options.onCacheEvicted!(paramKey);
        } else if (!_isDisposed) {
          refetch();
        }
      }
    });
  }

  /// Set up lifecycle callbacks
  void setupLifecycleCallbacks() {
    debugPrint('Setting up lifecycle callbacks in family query notifier $queryKey');
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResumed);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPaused);
    }
  }

  /// Set up window focus callbacks
  void setupWindowFocusCallbacks() {
    debugPrint('Setting up window focus callbacks in family query notifier $queryKey');
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocused);
    }
  }

  /// Schedule automatic refetching
  void scheduleRefetch(P param) {
    debugPrint('Scheduling automatic refetching in family query notifier $queryKey');
    final interval = options.refetchInterval;
    if (interval != null && !_isRefetchPaused) {
      _refetchTimer?.cancel();
      _refetchTimer = Timer.periodic(interval, (_) {
        if (!_isRefetchPaused && options.enabled) {
          backgroundRefetch(param);
        }
      });
    }
  }

  /// Callback for app resumed
  void _onAppResumed() {
    debugPrint('App resumed in family query notifier $queryKey');
    _isRefetchPaused = false;

    if (options.enabled) {
      final param = arg;
      final paramKey = getParamKey(param);
      final cachedEntry = getCachedEntry(paramKey);
      if (cachedEntry != null && cachedEntry.isStale) {
        backgroundRefetch(param);
      }
    }
  }

  /// Callback for app paused
  void _onAppPaused() {
    debugPrint('App paused in family query notifier $queryKey');
    _isRefetchPaused = true;
  }

  /// Callback for window focused
  void _onWindowFocused() {
    debugPrint('Window focused in family query notifier $queryKey');
    if (options.enabled && !_isRefetchPaused) {
      final param = arg;
      final paramKey = getParamKey(param);
      final cachedEntry = getCachedEntry(paramKey);
      if (cachedEntry != null && cachedEntry.isStale) {
        backgroundRefetch(param);
      }
    }
  }

  /// Pause automatic refetching
  void pauseRefetch() {
    debugPrint('Pausing automatic refetching in family query notifier $queryKey');
    _isRefetchPaused = true;
    _refetchTimer?.cancel();
  }

  /// Resume automatic refetching
  void resumeRefetch() {  
    debugPrint('Resuming automatic refetching in family query notifier $queryKey');
    _isRefetchPaused = false;
    if (options.refetchInterval != null) {
      scheduleRefetch(arg);
    }
  }
}

/// Auto-dispose base class for common query functionality
abstract class BaseQueryNotifierAutoDispose<T> extends AutoDisposeAsyncNotifier<T> with QueryClientMixin {
  /// Constructor
  BaseQueryNotifierAutoDispose({
    required this.queryFn,
    required this.options,
    required this.queryKey,
  });

  /// Query function
  final QueryFunctionWithRef<T> queryFn;
  /// Query options
  final QueryOptions<T> options;
  final String queryKey;

  /// Refetch timer
  Timer? _refetchTimer;
  /// Retry count
  int _retryCount = 0;

  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  /// Is refetch paused
  bool _isRefetchPaused = false;
  /// Is initialized
  bool _isInitialized = false;
  /// Is disposed
  bool _isDisposed = false;

  /// Initialize the query with common setup
  void initializeQuery(Ref ref) {
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
      state = newState;
    }
  }

  /// Has current value
  bool get hasCurrentValue => state.hasValue;

  /// Get current value
  T? get getCurrentValue => state.value;

  /// Perform the actual data fetch
  Future<T> performFetch() async {
    try {
      debugPrint('Performing fetch in auto-dispose query notifier $queryKey');
      final data = await queryFn(ref);
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
      debugPrint('Background refetching in auto-dispose query notifier $queryKey');
      final data = await performFetch();
      safeStateUpdate(AsyncValue.data(data));
    } catch (error, stackTrace) {
      // Silent background refresh failure - don't update state
      debugPrint('Background refresh failed: $error in auto-dispose query notifier $queryKey');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Public method to refetch data
  Future<void> refetch({bool background = false}) async {
    debugPrint('Refetching in auto-dispose query notifier $queryKey');
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
      debugPrint('Cache listener called for key $queryKey in auto-dispose query notifier');
      if ((entry?.hasData ?? false) && !(hasCurrentValue && entry!.data == getCurrentValue)) {
        debugPrint('Cache data changed for key $queryKey in auto-dispose query notifier');
        safeStateUpdate(AsyncValue.data(entry!.data as T));
      } else if (entry == null) {
        debugPrint('Cache entry removed for key $queryKey in auto-dispose query notifier');
        if (options.onCacheEvicted != null) {
          options.onCacheEvicted!(queryKey);
        } else if (!_isDisposed) {
          refetch();
        }
      }
    });
  }

  /// Set up lifecycle callbacks
  void _setupLifecycleCallbacks() {
    debugPrint('Setting up lifecycle callbacks in auto-dispose query notifier $queryKey');
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResumed);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPaused);
    }
  }

  /// Set up window focus callbacks
  void _setupWindowFocusCallbacks() {
    debugPrint('Setting up window focus callbacks in auto-dispose query notifier $queryKey');
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocused);
    }
  }

  /// Schedule automatic refetching
  void scheduleRefetch() {
    debugPrint('Scheduling automatic refetching in auto-dispose query notifier $queryKey');
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
    debugPrint('App resumed in auto-dispose query notifier $queryKey');
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
    debugPrint('App paused in auto-dispose query notifier $queryKey');
    _isRefetchPaused = true;
  }

  /// Callback for window focused
  void _onWindowFocused() {
    debugPrint('Window focused in auto-dispose query notifier $queryKey');
    if (options.enabled && !_isRefetchPaused) {
      final cachedEntry = getCachedEntry();
      if (cachedEntry != null && cachedEntry.isStale) {
        backgroundRefetch();
      }
    }
  }

  /// Pause automatic refetching
  void pauseRefetch() {
    debugPrint('Pausing automatic refetching in auto-dispose query notifier $queryKey');
    _isRefetchPaused = true;
    _refetchTimer?.cancel();
  }

  /// Resume automatic refetching
  void resumeRefetch() {  
    debugPrint('Resuming automatic refetching in auto-dispose query notifier $queryKey');
    _isRefetchPaused = false;
    if (options.refetchInterval != null) {
      scheduleRefetch();
    }
  }
}

/// Auto-dispose base class for family query functionality
abstract class BaseQueryFamilyNotifierAutoDispose<T, P> extends AutoDisposeFamilyAsyncNotifier<T, P> with QueryClientMixin {
  /// Constructor
  BaseQueryFamilyNotifierAutoDispose({
    required this.queryFn,
    required this.options,
    required this.queryKey,
  });

  final QueryFunctionWithParamsWithRef<T, P> queryFn;
  final QueryOptions<T> options;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;

  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  /// Is refetch paused
  bool _isRefetchPaused = false;
  /// Is initialized
  bool _isInitialized = false;
  /// Is disposed
  bool _isDisposed = false;

  /// Initialize the family query with common setup
  void initializeFamilyQuery(Ref ref) {
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
      state = newState;
    }
  }

  /// Has current value
  bool get hasCurrentValue => state.hasValue;

  /// Get current value
  T? get getCurrentValue => state.value;

  /// Get parameter key for caching
  String getParamKey(P param) => '$queryKey-$param';

  /// Perform the actual data fetch with parameter
  Future<T> performFetch(P param) async {
    try {
      debugPrint('Performing fetch in auto-dispose family query notifier $queryKey with param $param');
      final data = await queryFn(ref, param);
      final now = DateTime.now();

      // Cache the result with parameter key
      final paramKey = getParamKey(param);
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
        return performFetch(param);
      }

      rethrow;
    }
  }

  /// Background refetch without changing loading state
  Future<void> backgroundRefetch(P param) async {
    try {
      debugPrint('Background refetching in auto-dispose family query notifier $queryKey with param $param');
      final data = await performFetch(param);
      safeStateUpdate(AsyncValue.data(data));
    } catch (error, stackTrace) {
      // Silent background refresh failure - don't update state
      debugPrint('Background refresh failed: $error in auto-dispose family query notifier $queryKey');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Public method to refetch data
  Future<void> refetch({bool background = false}) async {
    final param = arg; // Get current parameter from AutoDisposeFamilyAsyncNotifier
    debugPrint('Refetching in auto-dispose family query notifier $queryKey with param $param');
    if (background) {
      return backgroundRefetch(param);
    }
    safeStateUpdate(const AsyncValue.loading());
    try {
      final data = await performFetch(param);
      safeStateUpdate(AsyncValue.data(data));
    } catch (error, stackTrace) {
      safeStateUpdate(AsyncValue.error(error, stackTrace));
    }
  }

  /// Helper methods for cache operations
  QueryCacheEntry<T>? getCachedEntry(String paramKey) {
    return _cache.get<T>(paramKey);
  }

  void setCachedEntry(String paramKey, QueryCacheEntry<T> entry) {
    _cache.set(paramKey, entry);
  }

  void invalidateCache(String paramKey) {
    _cache.remove(paramKey);
  }

  /// Set up cache change listener for specific parameter
  void setupCacheListener(String paramKey) {
    _cache.addListener<T>(paramKey, (QueryCacheEntry<T>? entry) {
      debugPrint('Cache listener called for key $paramKey in auto-dispose family query notifier');
      if ((entry?.hasData ?? false) && !(hasCurrentValue && entry!.data == getCurrentValue)) {
        debugPrint('Cache data changed for key $paramKey in auto-dispose family query notifier');
        safeStateUpdate(AsyncValue.data(entry!.data as T));
      } else if (entry == null) {
        debugPrint('Cache entry removed for key $paramKey in auto-dispose family query notifier');
        if (options.onCacheEvicted != null) {
          options.onCacheEvicted!(paramKey);
        } else if (!_isDisposed) {
          refetch();
        }
      }
    });
  }

  /// Set up lifecycle callbacks
  void setupLifecycleCallbacks() {
    debugPrint('Setting up lifecycle callbacks in auto-dispose family query notifier $queryKey');
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResumed);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPaused);
    }
  }

  /// Set up window focus callbacks
  void setupWindowFocusCallbacks() {
    debugPrint('Setting up window focus callbacks in auto-dispose family query notifier $queryKey');
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocused);
    }
  }

  /// Schedule automatic refetching
  void scheduleRefetch(P param) {
    debugPrint('Scheduling automatic refetching in auto-dispose family query notifier $queryKey');
    final interval = options.refetchInterval;
    if (interval != null && !_isRefetchPaused) {
      _refetchTimer?.cancel();
      _refetchTimer = Timer.periodic(interval, (_) {
        if (!_isRefetchPaused && options.enabled) {
          backgroundRefetch(param);
        }
      });
    }
  }

  /// Callback for app resumed
  void _onAppResumed() {
    debugPrint('App resumed in auto-dispose family query notifier $queryKey');
    _isRefetchPaused = false;

    if (options.enabled) {
      final param = arg;
      final paramKey = getParamKey(param);
      final cachedEntry = getCachedEntry(paramKey);
      if (cachedEntry != null && cachedEntry.isStale) {
        backgroundRefetch(param);
      }
    }
  }

  /// Callback for app paused
  void _onAppPaused() {
    debugPrint('App paused in auto-dispose family query notifier $queryKey');
    _isRefetchPaused = true;
  }

  /// Callback for window focused
  void _onWindowFocused() {
    debugPrint('Window focused in auto-dispose family query notifier $queryKey');
    if (options.enabled && !_isRefetchPaused) {
      final param = arg;
      final paramKey = getParamKey(param);
      final cachedEntry = getCachedEntry(paramKey);
      if (cachedEntry != null && cachedEntry.isStale) {
        backgroundRefetch(param);
      }
    }
  }

  /// Pause automatic refetching
  void pauseRefetch() {
    debugPrint('Pausing automatic refetching in auto-dispose family query notifier $queryKey');
    _isRefetchPaused = true;
    _refetchTimer?.cancel();
  }

  /// Resume automatic refetching
  void resumeRefetch() {  
    debugPrint('Resuming automatic refetching in auto-dispose family query notifier $queryKey');
    _isRefetchPaused = false;
    if (options.refetchInterval != null) {
      scheduleRefetch(arg);
    }
  }
}

// ========================================
// CONCRETE IMPLEMENTATIONS
// ========================================

/// 🔥 Modern AsyncNotifier-based query implementation
class AsyncQueryNotifier<T> extends BaseQueryNotifier<T> {
  /// Constructor
  AsyncQueryNotifier({
    required super.queryFn,
    required super.options,
    required super.queryKey,
  });

  /// Build the query
  @override
  FutureOr<T> build() async {
    // Initialize the query now that ref is available
    if (!_isInitialized) {
      initializeQuery(ref);
    }
    
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
}

/// AsyncNotifier with parameters - full-featured implementation
class AsyncQueryNotifierFamily<T, P> extends BaseQueryFamilyNotifier<T, P> {
  AsyncQueryNotifierFamily({
    required super.queryFn,
    required super.options,
    required super.queryKey,
  });

  @override
  FutureOr<T> build(P arg) async {
    // Initialize the query now that ref is available
    if (!_isInitialized) {
      initializeFamilyQuery(ref);
    }
    
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
}

/// Auto-dispose AsyncNotifier
class AsyncQueryNotifierAutoDispose<T> extends BaseQueryNotifierAutoDispose<T> {
  AsyncQueryNotifierAutoDispose({
    required super.queryFn,
    required super.options,
    required super.queryKey,
  });

  @override
  FutureOr<T> build() async {
    // Initialize the query now that ref is available
    if (!_isInitialized) {
      initializeQuery(ref);
    }
    
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
}

/// Auto-dispose AsyncNotifier with parameters
class AsyncQueryNotifierFamilyAutoDispose<T, P> extends BaseQueryFamilyNotifierAutoDispose<T, P> {
  /// Constructor
  AsyncQueryNotifierFamilyAutoDispose({
    required super.queryFn,
    required super.options,
    required super.queryKey,
  });

  @override
  FutureOr<T> build(P arg) async {
    // Initialize the query now that ref is available
    if (!_isInitialized) {
      initializeFamilyQuery(ref);
    }
    
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
/// - Query should be disposed when no longer watched
/// - Memory optimization is important
/// - Short-lived or page-specific data
///
/// Example:
/// ```dart
/// final userProvider = asyncQueryProviderAutoDispose<User>(
///   name: 'user',
///   queryFn: (ref) => ApiService.fetchCurrentUser(),
/// );
/// ```
AutoDisposeAsyncNotifierProvider<AsyncQueryNotifierAutoDispose<T>, T> asyncQueryProviderAutoDispose<T>({
  required String name,
  required QueryFunctionWithRef<T> queryFn,
  QueryOptions<T>? options,
}) {
  return AutoDisposeAsyncNotifierProvider<AsyncQueryNotifierAutoDispose<T>, T>(
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

/// 🔥 AsyncNotifier-based query provider with parameters
///
/// **Use this when:**
/// - Query depends on parameters (e.g., user ID, filters)
/// - Need persistent caching per parameter combination
/// - Shared parameterized data across widgets
///
/// Example:
/// ```dart
/// final userByIdProvider = asyncQueryProviderFamily<User, String>(
///   name: 'userById',
///   queryFn: (ref, userId) => ApiService.fetchUser(userId),
/// );
/// 
/// // Usage:
/// final userAsync = ref.watch(userByIdProvider('123'));
/// ```
AsyncNotifierProviderFamily<AsyncQueryNotifierFamily<T, P>, T, P> asyncQueryProviderFamily<T, P>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, P> queryFn,
  QueryOptions<T>? options,
}) {
  return AsyncNotifierProviderFamily<AsyncQueryNotifierFamily<T, P>, T, P>(
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
/// - Query depends on parameters AND should auto-dispose
/// - Memory optimization for parameterized queries
/// - Page-specific parameterized data
///
/// Example:
/// ```dart
/// final postCommentsProvider = asyncQueryProviderFamilyAutoDispose<List<Comment>, String>(
///   name: 'postComments',
///   queryFn: (ref, postId) => ApiService.fetchComments(postId),
/// );
/// ```
AutoDisposeAsyncNotifierProviderFamily<AsyncQueryNotifierFamilyAutoDispose<T, P>, T, P> asyncQueryProviderFamilyAutoDispose<T, P>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, P> queryFn,
  QueryOptions<T>? options,
}) {
  return AutoDisposeAsyncNotifierProviderFamily<AsyncQueryNotifierFamilyAutoDispose<T, P>, T, P>(
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
