import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lifecycle_manager.dart';
import 'query_cache.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'query_state.dart';
import 'window_focus_manager.dart';

/// A function that fetches data for a query
typedef QueryFunction<T> = Future<T> Function();
typedef QueryFunctionWithRef<T> = Future<T> Function(Ref ref);

/// A function that fetches data with parameters
typedef QueryFunctionWithParams<T, P> = Future<T> Function(P params);
/// A function that fetches data with parameters and a reference
typedef QueryFunctionWithParamsWithRef<T, P> = Future<T> Function(Ref ref, P params);

// QueryCacheEntry is now defined in query_cache.dart

/// Notifier for managing query state
class QueryNotifier<T> extends StateNotifier<QueryState<T>>
    with QueryClientMixin {
  QueryNotifier({
    required this.queryFunction,
    required this.options,
    required this.queryKey,
  }) : super(const QueryIdle()) {
    _initialize();
  }

  final QueryFunction<T> queryFunction;
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

  void _initialize() {
    // Prevent duplicate initialization
    if (!_isInitialized) {
      _isInitialized = true;
      
      // Set up cache change listener for automatic UI updates
      _setupCacheListener();
      
      // Set up lifecycle and window focus callbacks
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();
    }
    
    if (options.enabled && options.refetchOnMount) {
      _fetch();
    }

    // Set up automatic refetching if configured
    if (options.enabled && options.refetchInterval != null) {
      _scheduleRefetch();
    }
  }

  void _safeState(QueryState<T> state) {
    if(mounted){
      this.state = state;
    }
  }

  /// Fetch data
  Future<void> _fetch({bool forceFetchRemote = false}) async {
    if (!options.enabled) {
      return;
    }

    debugPrint('Fetching data in query notifier for key $queryKey');

    // Check cache first
    final cachedEntry = _getCachedEntry();
    if (!forceFetchRemote && cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      debugPrint('Using cached data in query notifier for key $queryKey');
      _safeState(QuerySuccess(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt));
      return;
    }

    // Determine loading state
    if (mounted && options.keepPreviousData && state.hasData) {
      debugPrint('Using state data in query notifier for key $queryKey');
      _safeState(QueryRefetching(state.data as T, fetchedAt: cachedEntry?.fetchedAt));
    }else if(options.keepPreviousData && cachedEntry != null && cachedEntry.hasData){
      debugPrint('Using stale cached data in query notifier for key $queryKey');
      _safeState(QueryRefetching(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt));
    }else {
      _safeState(const QueryLoading());
    }

    try {
      debugPrint('Querying data from server in query notifier for key $queryKey');

      final data = await queryFunction();
      final now = DateTime.now();
      
      // Cache the result
      _setCachedEntry(QueryCacheEntry<T>(
        data: data,
        fetchedAt: now,
        options: options,
      ));

      _safeState(QuerySuccess(data, fetchedAt: now));
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(data);
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _fetch();
      }

      // Cache the error
      _cache.setError<T>(
        queryKey,
        error,
        stackTrace: stackTrace,
        options: options,
      );

      _safeState(QueryError(error, stackTrace: stackTrace));
      _retryCount = 0;

      // Call error callback
      options.onError?.call(error, stackTrace);
    }
  }

  /// Refetch the query
  Future<void> refetch({bool forceFetchRemote = false}) => _fetch(forceFetchRemote: forceFetchRemote);

  /// Invalidate and refetch
  Future<void> refresh() {
    _clearCache();
    return _fetch();
  }

  /// Set query data manually (for optimistic updates)
  void setData(T data) {
    final now = DateTime.now();
    _setCachedEntry(QueryCacheEntry<T>(
      data: data,
      fetchedAt: now,
      options: options,
    ));
    _safeState(QuerySuccess(data, fetchedAt: now));
  }

  /// Get current cached data
  T? getCachedData() {
    final entry = _getCachedEntry();
    return entry?.hasData??false ? entry!.data as T : null;
  }

  void _scheduleRefetch() {
    _refetchTimer?.cancel();
    if (options.refetchInterval != null) {
      _refetchTimer = Timer.periodic(options.refetchInterval!, (_) {
        if (options.enabled && _shouldRefetch()) {
          _fetch();
        }
      });
    }
  }

  /// Check if refetch should proceed based on app state
  bool _shouldRefetch() {
    // If refetching is explicitly paused, don't refetch
    if (_isRefetchPaused) {
      return false;
    }
    
    // If pausing in background is enabled and app is in background, don't refetch
    if (options.pauseRefetchInBackground && _lifecycleManager.isInBackground) {
      return false;
    }
    
    return true;
  }

  /// Set up app lifecycle callbacks
  void _setupLifecycleCallbacks() {
    // Refetch when app comes to foreground (if enabled and data is stale)
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResume);
    }
    
    // Pause refetching when app goes to background (if enabled)
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPause);
    }
  }

  void _onAppResume() {
    debugPrint('App resumed in query notifier');
    // Resume refetching and check if we need to refetch stale data
    _isRefetchPaused = false;
    
    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && cachedEntry.isStale && options.enabled) {
      _fetch();
    }
  }

  void _onAppPause() {
    debugPrint('App paused in query notifier');
    // Mark refetching as paused
    _isRefetchPaused = true;
  }

  /// Set up window focus callbacks
  void _setupWindowFocusCallbacks() {
    // Refetch when window gains focus (if enabled and data is stale)
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocus);
    }
  }

  void _onWindowFocus() {
    debugPrint('Window focused in query notifier');
    // Refetch stale data when window gains focus
    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && cachedEntry.isStale && options.enabled) {
      _fetch();
    }
  }

  QueryCacheEntry<T>? _getCachedEntry() => _cache.get<T>(queryKey);

  void _setCachedEntry(QueryCacheEntry<T> entry) {
    _cache.set(queryKey, entry);
  }

  void _clearCache() {
    _cache.remove(queryKey);
  }

  /// Set up cache change listener for automatic UI updates
  void _setupCacheListener() {
    _cache.addListener<T>(queryKey, (entry) {
      if (entry?.hasData ?? false) {
        // Update state when cache data changes externally (e.g., optimistic updates)
        _safeState(QuerySuccess(entry!.data as T, fetchedAt: entry.fetchedAt));
      } else if (entry == null) {
        // Cache entry was removed, reset to idle
        if(options.onCacheEvicted != null){
          options.onCacheEvicted!(queryKey);
        }else if(mounted){
          refetch();
        }else{
          _safeState(const QueryIdle());
        }
      }
      debugPrint('Cache listener called for key $queryKey in query notifier, change state to ${state.runtimeType}');
    });
  }

  @override
  void dispose() {
    _refetchTimer?.cancel();
    
    // Clean up cache listener (removes ALL listeners for this queryKey)
    _cache.removeAllListeners(queryKey);
    
    // Clean up lifecycle callbacks
    if (options.refetchOnAppFocus) {
      _lifecycleManager.removeOnResumeCallback(_onAppResume);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.removeOnPauseCallback(_onAppPause);
    }
    
    // Clean up window focus callbacks
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.removeOnFocusCallback(_onWindowFocus);
    }
    
    // Reset initialization flag
    _isInitialized = false;
    
    super.dispose();
  }
}

/// Provider for creating queries
StateNotifierProvider<QueryNotifier<T>, QueryState<T>> queryProvider<T>({
  required String name,
  required QueryFunctionWithRef<T> queryFn,
  QueryOptions<T> options = const QueryOptions(),
}) => StateNotifierProvider<QueryNotifier<T>, QueryState<T>>(
    (ref) => QueryNotifier<T>(
      queryFunction: (){
        return queryFn(ref);
      },
      options: options,
      queryKey: name,
    ),
    name: name,
  );

/// Auto-dispose provider for creating queries
AutoDisposeStateNotifierProvider<QueryNotifier<T>, QueryState<T>> queryProviderAutoDispose<T>({
  required String name,
  required QueryFunctionWithRef<T> queryFn,
  QueryOptions<T> options = const QueryOptions(),
}) => StateNotifierProvider.autoDispose<QueryNotifier<T>, QueryState<T>>(
    (ref) => QueryNotifier<T>(
      queryFunction: (){
        return queryFn(ref);
      },
      options: options,
      queryKey: name,
    ),
    name: name,
  );


/// Provider family for creating queries with parameters
StateNotifierProviderFamily<QueryNotifier<T>, QueryState<T>, P> queryProviderFamily<T, P>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, P> queryFn,
  QueryOptions<T> options = const QueryOptions(),
}) => StateNotifierProvider.family<QueryNotifier<T>, QueryState<T>, P>(
    (ref, param) => QueryNotifier<T>(
      queryFunction: () { 
        return queryFn(ref, param);
      },
      options: options,
      queryKey: '$name-$param',
    ),
    name: name,
  );

/// Auto-dispose provider family for creating queries with parameters
AutoDisposeStateNotifierProviderFamily<QueryNotifier<T>, QueryState<T>, P> queryProviderFamilyAutoDispose<T, P>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, P> queryFn,
  QueryOptions<T> options = const QueryOptions(),
}) => StateNotifierProvider.autoDispose.family<QueryNotifier<T>, QueryState<T>, P>(
    (ref, param) => QueryNotifier<T>(
      queryFunction: () { 
        return queryFn(ref, param);
      },
      options: options,
      queryKey: '$name-$param',
    ),
    name: name,
  );


/// Convenience function for creating parameterized queries with constant parameters
StateNotifierProvider<QueryNotifier<T>, QueryState<T>> queryProviderWithParams<T, P>({
  required String name,
  required P params, // Should be const for best practices
  required QueryFunctionWithParamsWithRef<T, P> queryFn,
  QueryOptions<T> options = const QueryOptions(),
}) => StateNotifierProvider<QueryNotifier<T>, QueryState<T>>(
    (ref) => QueryNotifier<T>(
      queryFunction: () {
        return queryFn(ref, params);
      },
      options: options,
      queryKey: '$name-$params',
    ),
    name: '$name-$params',
  );

/// Extension methods for easier query usage
extension QueryStateExtensions<T> on QueryState<T> {
  /// Execute a callback when the query has data
  R? when<R>({
    R Function()? idle,
    R Function()? loading,
    R Function(T data)? success,
    R Function(Object error, StackTrace? stackTrace)? error,
    R Function(T data)? refetching,
  }) => switch (this) {
      QueryIdle<T>() => idle?.call(),
      QueryLoading<T>() => loading?.call(),
      final QuerySuccess<T> successState => success?.call(successState.data),
      final QueryError<T> errorState => error?.call(errorState.error, errorState.stackTrace),
      final QueryRefetching<T> refetchingState => refetching?.call(refetchingState.previousData),
    };

  /// Map the data if the query is successful
  QueryState<R> map<R>(R Function(T data) mapper) => switch (this) {
      final QuerySuccess<T> success => QuerySuccess(mapper(success.data), fetchedAt: success.fetchedAt),
      final QueryRefetching<T> refetching => QueryRefetching(mapper(refetching.previousData), fetchedAt: refetching.fetchedAt),
      QueryIdle<T>() => QueryIdle<R>(),
      QueryLoading<T>() => QueryLoading<R>(),
      final QueryError<T> error => QueryError<R>(error.error, stackTrace: error.stackTrace),
    };
}
