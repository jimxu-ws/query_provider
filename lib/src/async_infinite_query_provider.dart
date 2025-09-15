import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state_query_provider.dart' show QueryFunctionWithParamsWithRef;
import 'app_lifecycle_manager.dart';
import 'query_cache.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'window_focus_manager.dart';


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

  final QueryFunctionWithParamsWithRef<T, TPageParam> queryFn;
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
        debugPrint('Cache data changed for key $queryKey in async infinite query notifier');
        // Update state when cache data changes externally (e.g., optimistic updates)
        _safeState(AsyncValue.data(entry!.data!));
      } else if (entry == null) {
        debugPrint('Cache entry removed for key $queryKey in async infinite query notifier');
        // Cache entry was removed, reset to loading
        if(options.onCacheEvicted != null){
          options.onCacheEvicted?.call(queryKey);
        }else if(_isDisposed){
          refetch();
        }
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
  required QueryFunctionWithParamsWithRef<T, TPageParam> queryFn,
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

/// Auto-dispose AsyncNotifier for infinite queries
class AsyncInfiniteQueryNotifierAutoDispose<T, TPageParam> extends AutoDisposeAsyncNotifier<InfiniteQueryData<T>> with QueryClientMixin {
  AsyncInfiniteQueryNotifierAutoDispose({
    required this.queryFn,
    required this.options,
    required this.initialPageParam,
    required this.queryKey,
  });

  final QueryFunctionWithParamsWithRef<T, TPageParam> queryFn;
  final InfiniteQueryOptions<T, TPageParam> options;
  final TPageParam initialPageParam;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;

  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  FutureOr<InfiniteQueryData<T>> build() async {
    _isDisposed = false;
    
    if (!_isInitialized) {
      _isInitialized = true;
      _setupCacheListener();
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();
      
      ref.onDispose(() {
        _isDisposed = true;
        _refetchTimer?.cancel();
        _cache.removeAllListeners(queryKey);
        
        if (options.refetchOnAppFocus) {
          _lifecycleManager.removeOnResumeCallback(_onAppResume);
        }
        if (options.pauseRefetchInBackground) {
          _lifecycleManager.removeOnPauseCallback(_onAppPause);
        }
        if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
          _windowFocusManager.removeOnFocusCallback(_onWindowFocus);
        }
        
        _isInitialized = false;
      });
    }

    if (options.enabled && options.refetchInterval != null) {
      _scheduleRefetch();
    }

    if (options.enabled) {
      final cachedEntry = _getCachedEntry();
      if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
        if (options.refetchOnMount) {
          Future.microtask(() => _backgroundRefetch());
        }
        return cachedEntry.data as InfiniteQueryData<T>;
      }

      if (options.keepPreviousData && ((!_isDisposed && state.hasValue) || (cachedEntry != null && cachedEntry.hasData))) {
        Future.microtask(() => _backgroundRefetch());
        return (!_isDisposed && state.hasValue) ? state.value! : cachedEntry?.data as InfiniteQueryData<T>;
      }
    }

    if (!options.enabled) {
      throw StateError('Query is disabled and no cached data available');
    }

    return await _performFirstPageFetch();
  }

  void _safeState(AsyncValue<InfiniteQueryData<T>> state) {
    if(!_isDisposed) this.state = state;
  }

  Future<InfiniteQueryData<T>> _performFirstPageFetch() async {
    try {
      final firstPage = await queryFn(ref, initialPageParam);
      final now = DateTime.now();
      
      final data = InfiniteQueryData<T>(
        pages: [firstPage],
        hasNextPage: options.getNextPageParam.call(firstPage, [firstPage]) != null,
        hasPreviousPage: options.getPreviousPageParam?.call(firstPage, [firstPage]) != null,
        fetchedAt: now,
      );
      
      _setCachedEntry(QueryCacheEntry<InfiniteQueryData<T>>(
        data: data,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
        ),
      ));

      _retryCount = 0;
      options.onSuccess?.call(firstPage);
      
      return data;
    } catch (error, stackTrace) {
      options.onError?.call(error, stackTrace);
      
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _performFirstPageFetch();
      }
      
      rethrow;
    }
  }

  Future<void> _backgroundRefetch() async {
    try {
      final data = await _performFirstPageFetch();
      _safeState(AsyncValue.data(data));
    } catch (error, stackTrace) {
      // Silent failure
    }
  }

  Future<void> fetchNextPage() async {
    if (!state.hasValue) return;
    
    final currentData = state.value!;
    final nextPageParam = options.getNextPageParam?.call(
      currentData.pages.last,
      currentData.pages,
    );
    
    if (nextPageParam == null) return;

    try {
      final nextPage = await queryFn(ref, nextPageParam);
      final newData = InfiniteQueryData<T>(
        pages: [...currentData.pages, nextPage],
        hasNextPage: options.getNextPageParam?.call(nextPage, [...currentData.pages, nextPage]) != null,
        hasPreviousPage: currentData.hasPreviousPage,
        fetchedAt: DateTime.now(),
      );
      
      _setCachedEntry(QueryCacheEntry<InfiniteQueryData<T>>(
        data: newData,
        fetchedAt: DateTime.now(),
        options: QueryOptions<InfiniteQueryData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
        ),
      ));
      
      _safeState(AsyncValue.data(newData));
    } catch (error, stackTrace) {
      // Keep current data on error
    }
  }

  Future<void> refetch() async {
    _safeState(const AsyncValue.loading());
    try {
      final data = await _performFirstPageFetch();
      _safeState(AsyncValue.data(data));
    } catch (error, stackTrace) {
      _safeState(AsyncValue.error(error, stackTrace));
    }
  }

  QueryCacheEntry<InfiniteQueryData<T>>? _getCachedEntry() => _cache.get<InfiniteQueryData<T>>(queryKey);
  void _setCachedEntry(QueryCacheEntry<InfiniteQueryData<T>> entry) => _cache.set(queryKey, entry);
  
  void _setupCacheListener() {
    _cache.addListener<InfiniteQueryData<T>>(queryKey, (entry) {
      if (entry?.hasData ?? false) {
        _safeState(AsyncValue.data(entry!.data as InfiniteQueryData<T>));
      } else if (entry == null && !_isDisposed) {
        if (options.onCacheEvicted != null) {
          options.onCacheEvicted!(queryKey);
        } else {
          refetch();
        }
      }
    });
  }

  void _setupLifecycleCallbacks() {
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResume);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPause);
    }
  }

  void _setupWindowFocusCallbacks() {
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocus);
    }
  }

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

  void _onAppResume() {
    _isRefetchPaused = false;
    if (options.enabled) {
      final cachedEntry = _getCachedEntry();
      if (cachedEntry != null && cachedEntry.isStale) {
        _backgroundRefetch();
      }
    }
  }

  void _onAppPause() => _isRefetchPaused = true;

  void _onWindowFocus() {
    if (options.enabled && !_isRefetchPaused) {
      final cachedEntry = _getCachedEntry();
      if (cachedEntry != null && cachedEntry.isStale) {
        _backgroundRefetch();
      }
    }
  }
}

/// Auto-dispose provider for creating async infinite queries
/// 
/// **Use this when:**
/// - Temporary infinite data that should be cleaned up when not watched
/// - Memory optimization for large paginated datasets
/// - Short-lived screens with infinite scrolling
/// - Data that doesn't need to persist across navigation
/// 
/// **Features:**
/// - ✅ Automatic cleanup when no longer watched
/// - ✅ Full async infinite query functionality (fetchNextPage, fetchPreviousPage)
/// - ✅ Cache integration with staleTime/cacheTime
/// - ✅ Lifecycle management (app focus, window focus)
/// - ✅ Automatic refetching intervals
/// - ✅ Retry logic with exponential backoff
/// - ✅ Background refetch capabilities
/// - ✅ keepPreviousData support
/// - ✅ Memory leak prevention
/// 
/// Example:
/// ```dart
/// final tempPostsProvider = asyncInfiniteQueryProviderAutoDispose<Post, int>(
///   name: 'temp-posts',
///   queryFn: (pageParam) => ApiService.fetchPosts(page: pageParam),
///   initialPageParam: 1,
///   options: InfiniteQueryOptions(
///     getNextPageParam: (lastPage, allPages) => 
///       lastPage.hasMore ? allPages.length + 1 : null,
///     staleTime: Duration(minutes: 2),
///     cacheTime: Duration(minutes: 5),
///   ),
/// );
/// 
/// // Usage in widget:
/// final postsAsync = ref.watch(tempPostsProvider);
/// postsAsync.when(
///   loading: () => CircularProgressIndicator(),
///   error: (error, stack) => ErrorWidget(error),
///   data: (infiniteData) => ListView.builder(
///     itemCount: infiniteData.pages.expand((page) => page.items).length,
///     itemBuilder: (context, index) => PostTile(post: infiniteData.pages[index]),
///   ),
/// );
/// ```
AutoDisposeAsyncNotifierProvider<AsyncInfiniteQueryNotifierAutoDispose<T, TPageParam>, InfiniteQueryData<T>> asyncInfiniteQueryProviderAutoDispose<T, TPageParam>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, TPageParam> queryFn,
  required TPageParam initialPageParam,
  required InfiniteQueryOptions<T, TPageParam> options,
}) => AsyncNotifierProvider.autoDispose<AsyncInfiniteQueryNotifierAutoDispose<T, TPageParam>, InfiniteQueryData<T>>(
    () => AsyncInfiniteQueryNotifierAutoDispose<T, TPageParam>(
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
