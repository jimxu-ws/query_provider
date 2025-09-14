import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lifecycle_manager.dart';
import 'query_cache.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'window_focus_manager.dart';

/// A function that fetches a page of data with ref
typedef AsyncInfiniteQueryFunction<T, TPageParam> = Future<T> Function(Ref ref, TPageParam pageParam);

/// A function that fetches a page of data with ref and additional parameters
typedef AsyncInfiniteQueryFunctionWithParams<T, TPageParam, P> = Future<T> Function(Ref ref, TPageParam pageParam, P params);

/// Represents the data structure for infinite query results
@immutable
class InfiniteQueryData<T> {
  const InfiniteQueryData({
    required this.pages,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
    this.fetchedAt,
  });

  final List<T> pages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final DateTime? fetchedAt;

  InfiniteQueryData<T> copyWith({
    List<T>? pages,
    bool? hasNextPage,
    bool? hasPreviousPage,
    DateTime? fetchedAt,
  }) => InfiniteQueryData<T>(
      pages: pages ?? this.pages,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfiniteQueryData<T> &&
          other.pages == pages &&
          other.hasNextPage == hasNextPage &&
          other.hasPreviousPage == hasPreviousPage &&
          other.fetchedAt == fetchedAt);

  @override
  int get hashCode => Object.hash(pages, hasNextPage, hasPreviousPage, fetchedAt);

  @override
  String toString() => 'InfiniteQueryData<$T>('
      'pages: ${pages.length}, '
      'hasNextPage: $hasNextPage, '
      'hasPreviousPage: $hasPreviousPage, '
      'fetchedAt: $fetchedAt)';
}

/// 🔥 Modern AsyncNotifier-based infinite query implementation
/// 
/// Features:
/// - Background refetch and lifecycle management
/// - Cache integration with automatic invalidation
/// - Window focus refetch support
/// - keepPreviousData: Shows stale data while fetching fresh data for better UX
/// - Automatic retry with exponential backoff
/// - Optimistic updates support
class AsyncInfiniteQueryNotifier<T, TPageParam> extends AsyncNotifier<InfiniteQueryData<T>> with QueryClientMixin {
  AsyncInfiniteQueryNotifier({
    required this.queryFn,
    required this.options,
    required this.initialPageParam,
    required this.queryKey,
  });

  final AsyncInfiniteQueryFunction<T, TPageParam> queryFn;
  final InfiniteQueryOptions<T, TPageParam> options;
  final TPageParam initialPageParam;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;

  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  FutureOr<InfiniteQueryData<T>> build() async {
    _isDisposed = false;
    // Prevent duplicate initialization
    if (!_isInitialized) {
      _isInitialized = true;
      
      // Set up cache change listener for automatic UI updates
      _setupCacheListener();
      
      // Set up lifecycle and window focus callbacks
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();
      
      // Set up cleanup when the notifier is disposed
      ref.onDispose(_dispose);
    }

    // Set up automatic refetching if configured
    if (options.enabled && options.refetchInterval != null) {
      _scheduleRefetch();
    }

    if (!options.enabled) {
      return const InfiniteQueryData(pages: []);
    }

    // Check cache first
    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      debugPrint('Using cached data in async infinite query notifier for key $queryKey');
      final cachedData = cachedEntry.data!;
      return cachedData;
    }

    // If keepPreviousData is enabled and we have stale cached data, use it while fetching fresh data
    if (options.keepPreviousData && cachedEntry != null && cachedEntry.hasData) {
      debugPrint('Using stale cached data with keepPreviousData in async infinite query notifier for key $queryKey');
      final staleData = cachedEntry.data!;
      
      // Start fetching fresh data in the background
      _fetchFirstPageInBackground();
      
      return staleData;
    }

    // Fetch first page
    return _fetchFirstPage();
  }

  /// Fetch the first page in background (for keepPreviousData)
  void _fetchFirstPageInBackground() {
    _fetchFirstPage().then((newData) {
      // Update state with fresh data
      _safeState(AsyncValue.data(newData));
    }).catchError((Object error, StackTrace stackTrace) {
      // On error, keep the current stale data but log the error
      debugPrint('Background fetch failed for key $queryKey: $error');
      // Don't update state on error to keep showing stale data
    });
  }

  /// Fetch the first page
  Future<InfiniteQueryData<T>> _fetchFirstPage() async {
    try {
      final firstPage = await queryFn(ref, initialPageParam);
      final now = DateTime.now();
      final pages = [firstPage];

      final hasNextPage = options.getNextPageParam(firstPage, pages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(firstPage, pages) != null;

      final result = InfiniteQueryData<T>(
        pages: pages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      // Cache the result
      _setCachedEntry(QueryCacheEntry<InfiniteQueryData<T>>(
        data: result,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      _retryCount = 0;
      options.onSuccess?.call(firstPage);
      return result;
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _fetchFirstPage();
      }

      // Cache the error
      _cache.setError<InfiniteQueryData<T>>(
        queryKey,
        error,
        stackTrace: stackTrace,
        options: QueryOptions<InfiniteQueryData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      );

      _retryCount = 0;
      options.onError?.call(error, stackTrace);
      rethrow;
    }
  }

  /// Fetch the next page
  Future<void> fetchNextPage() async {
    final currentState = state;
    if (!currentState.hasValue || !currentState.value!.hasNextPage) {
      return;
    }

    final currentData = currentState.value!;
    final nextPageParam = options.getNextPageParam(
      currentData.pages.last,
      currentData.pages,
    );

    if (nextPageParam == null) {
      return;
    }

    try {
      final nextPage = await queryFn(ref, nextPageParam);
      final newPages = [...currentData.pages, nextPage];

      final hasNextPage = options.getNextPageParam(nextPage, newPages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(newPages.first, newPages) != null;

      final newData = InfiniteQueryData<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: DateTime.now(),
      );

      // Update cache
      _setCachedEntry(QueryCacheEntry<InfiniteQueryData<T>>(
        data: newData,
        fetchedAt: newData.fetchedAt!,
        options: QueryOptions<InfiniteQueryData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      // Update state
      _safeState(AsyncValue.data(newData));
      options.onSuccess?.call(nextPage);
    } catch (error, stackTrace) {
      // Don't update state on error, keep current data
      // This behavior is consistent with keepPreviousData philosophy
      options.onError?.call(error, stackTrace);
      debugPrint('fetchNextPage failed but keeping current data for key $queryKey: $error');
      rethrow;
    }
  }

  /// Fetch the previous page
  Future<void> fetchPreviousPage() async {
    final currentState = state;
    if (!currentState.hasValue || 
        !currentState.value!.hasPreviousPage ||
        options.getPreviousPageParam == null) {
      return;
    }

    final currentData = currentState.value!;
    final previousPageParam = options.getPreviousPageParam!(
      currentData.pages.first,
      currentData.pages,
    );

    if (previousPageParam == null) {
      return;
    }

    try {
      final previousPage = await queryFn(ref, previousPageParam);
      final newPages = [previousPage, ...currentData.pages];

      final hasNextPage = options.getNextPageParam(newPages.last, newPages) != null;
      final hasPreviousPage = options.getPreviousPageParam!(newPages.first, newPages) != null;

      final newData = InfiniteQueryData<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: DateTime.now(),
      );

      // Update cache
      _setCachedEntry(QueryCacheEntry<InfiniteQueryData<T>>(
        data: newData,
        fetchedAt: newData.fetchedAt!,
        options: QueryOptions<InfiniteQueryData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      // Update state
      _safeState(AsyncValue.data(newData));
      options.onSuccess?.call(previousPage);
    } catch (error, stackTrace) {
      // Don't update state on error, keep current data
      // This behavior is consistent with keepPreviousData philosophy
      options.onError?.call(error, stackTrace);
      debugPrint('fetchPreviousPage failed but keeping current data for key $queryKey: $error');
      rethrow;
    }
  }

  /// Refetch all pages
  Future<void> refetch() async {
    final currentState = state;
    if (currentState.hasValue) {
      final currentData = currentState.value!;
      
      // If keepPreviousData is enabled, don't change the state to loading
      // Keep showing current data while fetching
      if (!options.keepPreviousData) {
        _safeState(const AsyncValue.loading());
      }
      
      try {
        // Refetch all existing pages
        final List<T> newPages = [];
        TPageParam pageParam = initialPageParam;

        // Fetch the same number of pages as currently loaded
        for (int i = 0; i < currentData.pages.length; i++) {
          final page = await queryFn(ref, pageParam);
          newPages.add(page);

          if (i < currentData.pages.length - 1) {
            final nextParam = options.getNextPageParam(page, newPages);
            if (nextParam == null) {
              break;
            }
            pageParam = nextParam;
          }
        }

        final hasNextPage = options.getNextPageParam(newPages.last, newPages) != null;
        final hasPreviousPage = options.getPreviousPageParam?.call(newPages.first, newPages) != null;

        final newData = InfiniteQueryData<T>(
          pages: newPages,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
          fetchedAt: DateTime.now(),
        );

        // Update cache
        _setCachedEntry(QueryCacheEntry<InfiniteQueryData<T>>(
          data: newData,
          fetchedAt: newData.fetchedAt!,
          options: QueryOptions<InfiniteQueryData<T>>(
            staleTime: options.staleTime,
            cacheTime: options.cacheTime,
            enabled: options.enabled,
          ),
        ));

        // Update state
        _safeState(AsyncValue.data(newData));
      } catch (error, stackTrace) {
        // If keepPreviousData is enabled and we have current data, don't show error state
        // Keep showing the current data
        if (options.keepPreviousData && currentState.hasValue) {
          debugPrint('Refetch failed but keeping previous data for key $queryKey: $error');
          // Don't update state, keep current data
        } else {
          _safeState(AsyncValue.error(error, stackTrace));
        }
      }
    } else {
      // If no current data, fetch first page
      _safeState(const AsyncValue.loading());
      try {
        final newData = await _fetchFirstPage();
        _safeState(AsyncValue.data(newData));
      } catch (error, stackTrace) {
        _safeState(AsyncValue.error(error, stackTrace));
      }
    }
  }

  /// Invalidate and refetch
  Future<void> refresh() {
    _clearCache();
    return refetch();
  }

  /// Set query data manually (for optimistic updates)
  void setData(InfiniteQueryData<T> data) {
    final now = DateTime.now();
    final updatedData = data.copyWith(fetchedAt: now);
    
    _setCachedEntry(QueryCacheEntry<InfiniteQueryData<T>>(
      data: updatedData,
      fetchedAt: now,
      options: QueryOptions<InfiniteQueryData<T>>(
        staleTime: options.staleTime,
        cacheTime: options.cacheTime,
        enabled: options.enabled,
      ),
    ));
    
    _safeState(AsyncValue.data(updatedData));
  }

  /// Get current cached data
  InfiniteQueryData<T>? getCachedData() {
    final entry = _getCachedEntry();
    return (entry?.hasData??false) ? entry!.data! : null;
  }

  void _scheduleRefetch() {
    _refetchTimer?.cancel();
    if (options.refetchInterval != null) {
      _refetchTimer = Timer.periodic(options.refetchInterval!, (_) {
        if (options.enabled && _shouldRefetch()) {
          refetch();
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
    debugPrint('App resumed in async infinite query notifier');
    // Resume refetching and check if we need to refetch stale data
    _isRefetchPaused = false;
    
    if (_shouldRefetchOnFocus()) {
      refetch();
    }
  }

  void _onAppPause() {
    debugPrint('App paused in async infinite query notifier');
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
    debugPrint('Window focused in async infinite query notifier');
    // Refetch stale data when window gains focus
    if (_shouldRefetchOnFocus()) {
      refetch();
    }
  }

  /// Check if we should refetch when focus is gained
  bool _shouldRefetchOnFocus() {
    if (!options.enabled) {
      return false;
    }

    final currentState = state;
    if (currentState.hasValue) {
      final currentData = currentState.value!;
      // Check if data is stale based on stale time
      final now = DateTime.now();
      final fetchedAt = currentData.fetchedAt;
      if (fetchedAt != null) {
        final age = now.difference(fetchedAt);
        return age > options.staleTime;
      }
    }
    
    return false;
  }

  QueryCacheEntry<InfiniteQueryData<T>>? _getCachedEntry() => _cache.get<InfiniteQueryData<T>>(queryKey);

  void _setCachedEntry(QueryCacheEntry<InfiniteQueryData<T>> entry) {
    _cache.set(queryKey, entry);
  }

  void _clearCache() {
    _cache.remove(queryKey);
  }

  /// Set up cache change listener for automatic UI updates
  void _setupCacheListener() {
    _cache.addListener<InfiniteQueryData<T>>(queryKey, (entry) {
      debugPrint('Cache listener called for key $queryKey in async infinite query notifier');
      if ((entry?.hasData??false) && !_isDisposed && !(!(state.isLoading || state.hasError) && state.hasValue && listEquals(entry!.data!.pages, state.value!.pages))) {
        // Update state when cache data changes externally (e.g., optimistic updates)
        _safeState(AsyncValue.data(entry!.data!));
      } else if (entry == null && !_isDisposed) {
        // Cache entry was removed, reset to loading
        _safeState(const AsyncValue.loading());
      }
    });
  }

  void _safeState(AsyncValue<InfiniteQueryData<T>> state) {
    if(!_isDisposed){
      this.state = state;
    }
  }

  void _dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    
    _refetchTimer?.cancel();
    
    // Clean up cache listener
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
  }
}

/// Provider for creating async infinite queries
AsyncNotifierProvider<AsyncInfiniteQueryNotifier<T, TPageParam>, InfiniteQueryData<T>> asyncInfiniteQueryProvider<T, TPageParam>({
  required String name,
  required AsyncInfiniteQueryFunction<T, TPageParam> queryFn,
  required TPageParam initialPageParam,
  required InfiniteQueryOptions<T, TPageParam> options,
}) => AsyncNotifierProvider<AsyncInfiniteQueryNotifier<T, TPageParam>, InfiniteQueryData<T>>(
    () => AsyncInfiniteQueryNotifier<T, TPageParam>(
      queryFn: queryFn,
      options: options,
      initialPageParam: initialPageParam,
      queryKey: name,
    ),
    name: name,
  );

/// Hook-like interface for using async infinite queries
@immutable
class AsyncInfiniteQueryResult<T> {
  const AsyncInfiniteQueryResult({
    required this.state,
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.refetch,
    required this.refresh,
  });

  final AsyncValue<InfiniteQueryData<T>> state;
  final Future<void> Function() fetchNextPage;
  final Future<void> Function() fetchPreviousPage;
  final Future<void> Function() refetch;
  final Future<void> Function() refresh;

  /// Returns true if the query is currently loading
  bool get isLoading => state.isLoading;

  /// Returns true if the query has data
  bool get hasData => state.hasValue;

  /// Returns true if the query has an error
  bool get hasError => state.hasError;

  /// Returns the pages if available
  List<T>? get pages => state.valueOrNull?.pages;

  /// Returns the error if available
  Object? get error => state.error;

  /// Returns true if there are more pages to fetch
  bool get hasNextPage => state.valueOrNull?.hasNextPage ?? false;

  /// Returns true if there are previous pages to fetch
  bool get hasPreviousPage => state.valueOrNull?.hasPreviousPage ?? false;

  /// Returns the fetch time
  DateTime? get fetchedAt => state.valueOrNull?.fetchedAt;
}

/// Extension for WidgetRef to read async infinite query results
extension WidgetRefAsyncInfiniteQueryResult on WidgetRef {
  /// Create an async infinite query result that can be used in widgets
  AsyncInfiniteQueryResult<T> readAsyncInfiniteQueryResult<T, TPageParam>(AsyncNotifierProvider<AsyncInfiniteQueryNotifier<T, TPageParam>, InfiniteQueryData<T>> provider) {
    final notifier = read(provider.notifier);
    final state = watch(provider);

    return AsyncInfiniteQueryResult<T>(
      state: state,
      fetchNextPage: notifier.fetchNextPage,
      fetchPreviousPage: notifier.fetchPreviousPage,
      refetch: notifier.refetch,
      refresh: notifier.refresh,
    );
  }

}
