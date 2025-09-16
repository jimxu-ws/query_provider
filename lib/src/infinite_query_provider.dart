import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lifecycle_manager.dart';
import 'query_cache.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'state_query_provider.dart' show QueryFunctionWithParamsWithRef;
import 'window_focus_manager.dart';

/// Represents cached infinite query data
@immutable
class InfiniteQueryCacheData<T> {
  const InfiniteQueryCacheData({
    required this.pages,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
    this.fetchedAt,
  });

  final List<T> pages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final DateTime? fetchedAt;

  InfiniteQueryCacheData<T> copyWith({
    List<T>? pages,
    bool? hasNextPage,
    bool? hasPreviousPage,
    DateTime? fetchedAt,
  }) => InfiniteQueryCacheData<T>(
      pages: pages ?? this.pages,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfiniteQueryCacheData<T> &&
          other.pages == pages &&
          other.hasNextPage == hasNextPage &&
          other.hasPreviousPage == hasPreviousPage &&
          other.fetchedAt == fetchedAt);

  @override
  int get hashCode => Object.hash(pages, hasNextPage, hasPreviousPage, fetchedAt);

  @override
  String toString() => 'InfiniteQueryCacheData<$T>('
      'pages: ${pages.length}, '
      'hasNextPage: $hasNextPage, '
      'hasPreviousPage: $hasPreviousPage, '
      'fetchedAt: $fetchedAt)';
}

/// Represents the state of an infinite query
@immutable
sealed class InfiniteQueryState<T> {
  const InfiniteQueryState();

  /// Returns true if the query is currently loading the first page
  bool get isLoading => this is InfiniteQueryLoading<T>;

  /// Returns true if the query has data
  bool get hasData => this is InfiniteQuerySuccess<T> || this is InfiniteQueryRefetching<T>;

  /// Returns true if the query has an error
  bool get hasError => this is InfiniteQueryError<T>;

  /// Returns true if the query is idle
  bool get isIdle => this is InfiniteQueryIdle<T>;

  /// Returns true if the query is fetching the next page
  bool get isFetchingNextPage => this is InfiniteQueryFetchingNextPage<T>;

  /// Returns true if the query is fetching the previous page
  bool get isFetchingPreviousPage => this is InfiniteQueryFetchingPreviousPage<T>;

  /// Returns true if the query is refetching
  bool get isRefetching => this is InfiniteQueryRefetching<T>;

  /// Returns the pages if available
  List<T>? get pages => switch (this) {
        final InfiniteQuerySuccess<T> success => success.pages,
        final InfiniteQueryRefetching<T> refetching => refetching.pages,
        final InfiniteQueryFetchingNextPage<T> fetching => fetching.pages,
        final InfiniteQueryFetchingPreviousPage<T> fetching => fetching.pages,
        _ => null,
      };

  /// Returns the error if available
  Object? get error => switch (this) {
        final InfiniteQueryError<T> error => error.error,
        _ => null,
      };
}

/// Initial state before any query is executed
final class InfiniteQueryIdle<T> extends InfiniteQueryState<T> {
  const InfiniteQueryIdle();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InfiniteQueryIdle<T>;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'InfiniteQueryIdle<$T>()';
}

/// State when query is loading the first page
final class InfiniteQueryLoading<T> extends InfiniteQueryState<T> {
  const InfiniteQueryLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InfiniteQueryLoading<T>;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'InfiniteQueryLoading<$T>()';
}

/// State when query has successfully loaded pages
final class InfiniteQuerySuccess<T> extends InfiniteQueryState<T> {
  const InfiniteQuerySuccess({
    required this.pages,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
    this.fetchedAt,
  });

  final List<T> pages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final DateTime? fetchedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfiniteQuerySuccess<T> &&
          other.pages == pages &&
          other.hasNextPage == hasNextPage &&
          other.hasPreviousPage == hasPreviousPage &&
          other.fetchedAt == fetchedAt);

  @override
  int get hashCode => Object.hash(pages, hasNextPage, hasPreviousPage, fetchedAt);

  @override
  String toString() => 'InfiniteQuerySuccess<$T>('
      'pages: ${pages.length}, '
      'hasNextPage: $hasNextPage, '
      'hasPreviousPage: $hasPreviousPage, '
      'fetchedAt: $fetchedAt)';

  InfiniteQuerySuccess<T> copyWith({
    List<T>? pages,
    bool? hasNextPage,
    bool? hasPreviousPage,
    DateTime? fetchedAt,
  }) => InfiniteQuerySuccess<T>(
      pages: pages ?? this.pages,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
}

/// State when query has successfully loaded pages
final class InfiniteQueryRefetching<T> extends InfiniteQueryState<T> {
  const InfiniteQueryRefetching({
    required this.pages,
    this.hasNextPage = false,
    this.hasPreviousPage = false,
    this.fetchedAt,
  });

  final List<T> pages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final DateTime? fetchedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfiniteQueryRefetching<T> &&
          other.pages == pages &&
          other.hasNextPage == hasNextPage &&
          other.hasPreviousPage == hasPreviousPage &&
          other.fetchedAt == fetchedAt);

  @override
  int get hashCode => Object.hash(pages, hasNextPage, hasPreviousPage, fetchedAt);

  @override
  String toString() => 'InfiniteQueryRefetching<$T>('
      'pages: ${pages.length}, '
      'hasNextPage: $hasNextPage, '
      'hasPreviousPage: $hasPreviousPage, '
      'fetchedAt: $fetchedAt)';

  InfiniteQueryRefetching<T> copyWith({
    List<T>? pages,
    bool? hasNextPage,
    bool? hasPreviousPage,
    DateTime? fetchedAt,
  }) => InfiniteQueryRefetching<T>(
      pages: pages ?? this.pages,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
}

/// State when query has failed with an error
final class InfiniteQueryError<T> extends InfiniteQueryState<T> {
  const InfiniteQueryError(this.error, {this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfiniteQueryError<T> &&
          other.error == error &&
          other.stackTrace == stackTrace);

  @override
  int get hashCode => Object.hash(error, stackTrace);

  @override
  String toString() => 'InfiniteQueryError<$T>(error: $error)';
}

/// State when query is fetching the next page
final class InfiniteQueryFetchingNextPage<T> extends InfiniteQueryState<T> {
  const InfiniteQueryFetchingNextPage({
    required this.pages,
    this.hasNextPage = true,
    this.hasPreviousPage = false,
    this.fetchedAt,
  });

  final List<T> pages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final DateTime? fetchedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfiniteQueryFetchingNextPage<T> &&
          other.pages == pages &&
          other.hasNextPage == hasNextPage &&
          other.hasPreviousPage == hasPreviousPage &&
          other.fetchedAt == fetchedAt);

  @override
  int get hashCode => Object.hash(pages, hasNextPage, hasPreviousPage, fetchedAt);

  @override
  String toString() => 'InfiniteQueryFetchingNextPage<$T>(pages: ${pages.length})';
}

/// State when query is fetching the previous page
final class InfiniteQueryFetchingPreviousPage<T> extends InfiniteQueryState<T> {
  const InfiniteQueryFetchingPreviousPage({
    required this.pages,
    this.hasNextPage = false,
    this.hasPreviousPage = true,
    this.fetchedAt,
  });

  final List<T> pages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final DateTime? fetchedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfiniteQueryFetchingPreviousPage<T> &&
          other.pages == pages &&
          other.hasNextPage == hasNextPage &&
          other.hasPreviousPage == hasPreviousPage &&
          other.fetchedAt == fetchedAt);

  @override
  int get hashCode => Object.hash(pages, hasNextPage, hasPreviousPage, fetchedAt);

  @override
  String toString() => 'InfiniteQueryFetchingPreviousPage<$T>(pages: ${pages.length})';
}

/// Modern FamilyNotifier for managing infinite query state
class InfiniteQueryNotifier<T, TPageParam> extends Notifier<InfiniteQueryState<T>>
    with QueryClientMixin {
  InfiniteQueryNotifier({
    required this.queryFn,
    required this.options,
    required this.initialPageParam,
    required this.queryKey,
  });

  @override
  InfiniteQueryState<T> build() {
    _initialize();
    _setupDispose();
    return const InfiniteQueryIdle();
  }

  void _setupDispose() {
    ref.onDispose(() {
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
      
      debugPrint('InfiniteQueryNotifier disposed for key $queryKey');
    });
  }

  final QueryFunctionWithParamsWithRef<T, TPageParam> queryFn;
  final InfiniteQueryOptions<T, TPageParam> options;
  final TPageParam initialPageParam;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;
  bool _isInitialized = false;
  
  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;

  void _initialize() {
    if (!_isInitialized) {
      _isInitialized = true;
      // Set up cache change listener for automatic UI updates
      _setupCacheListener();
      
      // Set up lifecycle and window focus callbacks
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();
    }
    
    if (options.enabled && options.refetchOnMount) {
      _fetchFirstPage();
    }

    // Set up automatic refetching if configured
    if (options.enabled && options.refetchInterval != null) {
      //TODO: it costs time to refetch all pages
      _scheduleRefetch();
    }
  }

  void _safeState(InfiniteQueryState<T> newState) {
    // In modern Notifier, we don't need to check if it's mounted
    // The framework handles this automatically
    state = newState;
  }

  /// Fetch the first page
  Future<void> _fetchFirstPage() async {
    if (!options.enabled) {
      return;
    }

    debugPrint('Fetching first page for infinite query key $queryKey');

    // Check cache first
    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      debugPrint('Using cached data for infinite query key $queryKey');
      final cacheData = cachedEntry.data!;
      _safeState(InfiniteQuerySuccess<T>(
        pages: cacheData.pages,
        hasNextPage: cacheData.hasNextPage,
        hasPreviousPage: cacheData.hasPreviousPage,
        fetchedAt: cacheData.fetchedAt,
      ));
      return;
    }

    // If keepPreviousData is enabled and we have stale cached data, use it while fetching fresh data
    if (options.keepPreviousData && cachedEntry != null && cachedEntry.hasData) {
      debugPrint('Using stale cached data with keepPreviousData for infinite query key $queryKey');
      final staleData = cachedEntry.data!;
      _safeState(InfiniteQuerySuccess<T>(
        pages: staleData.pages,
        hasNextPage: staleData.hasNextPage,
        hasPreviousPage: staleData.hasPreviousPage,
        fetchedAt: staleData.fetchedAt,
      ));
      
      // Start fetching fresh data in the background
      _fetchFirstPageInBackground();
      return;
    }

    // Show loading state if no cached data or keepPreviousData is disabled
    _safeState(const InfiniteQueryLoading());

    try {
      final firstPage = await queryFn(ref, initialPageParam);
      final now = DateTime.now();
      final pages = [firstPage];

      final hasNextPage = options.getNextPageParam(firstPage, pages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(firstPage, pages) != null;

      final cacheData = InfiniteQueryCacheData<T>(
        pages: pages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      // Cache the result
      _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
        data: cacheData,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      _safeState(InfiniteQuerySuccess<T>(
        pages: pages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      ));

      _retryCount = 0;
      options.onSuccess?.call(firstPage);
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _fetchFirstPage();
      }

      // Cache the error
      _cache.setError<InfiniteQueryCacheData<T>>(
        queryKey,
        error,
        stackTrace: stackTrace,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      );

      _safeState(InfiniteQueryError(error, stackTrace: stackTrace));
      _retryCount = 0;
      options.onError?.call(error, stackTrace);
    }
  }

  /// Fetch the first page in background (for keepPreviousData)
  void _fetchFirstPageInBackground() {
    _fetchFirstPageCore().then((result) {
      if (result != null) {
        final (pages, hasNextPage, hasPreviousPage, fetchedAt) = result;
        _safeState(InfiniteQuerySuccess<T>(
          pages: pages,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
          fetchedAt: fetchedAt,
        ));
      }
    }).catchError((Object error, StackTrace stackTrace) {
      // On error, keep the current stale data but log the error
      debugPrint('Background fetch failed for infinite query key $queryKey: $error');
      // Don't update state on error to keep showing stale data
    });
  }

  /// Core fetch logic that can be reused
  Future<(List<T>, bool, bool, DateTime)?> _fetchFirstPageCore() async {
    try {
      final firstPage = await queryFn(ref, initialPageParam);
      final now = DateTime.now();
      final pages = [firstPage];

      final hasNextPage = options.getNextPageParam(firstPage, pages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(firstPage, pages) != null;

      final cacheData = InfiniteQueryCacheData<T>(
        pages: pages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      // Cache the result
      _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
        data: cacheData,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      options.onSuccess?.call(firstPage);
      return (pages, hasNextPage, hasPreviousPage, now);
    } catch (error, stackTrace) {
      options.onError?.call(error, stackTrace);
      rethrow;
    }
  }

  /// Fetch the next page
  Future<void> fetchNextPage() async {
    final currentState = state;
    if (currentState is! InfiniteQuerySuccess<T> || !currentState.hasNextPage) {
      return;
    }

    final nextPageParam = options.getNextPageParam(
      currentState.pages.last,
      currentState.pages,
    );

    if (nextPageParam == null) {
      return;
    }

    _safeState(InfiniteQueryFetchingNextPage<T>(
      pages: currentState.pages,
      hasNextPage: currentState.hasNextPage,
      hasPreviousPage: currentState.hasPreviousPage,
      fetchedAt: currentState.fetchedAt,
    ));

    try {
      final nextPage = await queryFn(ref, nextPageParam);
      final newPages = [...currentState.pages, nextPage];
      final now = DateTime.now();

      final hasNextPage = options.getNextPageParam(nextPage, newPages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(newPages.first, newPages) != null;

      final cacheData = InfiniteQueryCacheData<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      // Update cache
      _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
        data: cacheData,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      _safeState(InfiniteQuerySuccess<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      ));

      options.onSuccess?.call(nextPage);
    } catch (error, stackTrace) {
      // Revert to previous success state on error
      _safeState(currentState);
      options.onError?.call(error, stackTrace);
    }
  }

  /// Fetch the previous page
  Future<void> fetchPreviousPage() async {
    final currentState = state;
    if (currentState is! InfiniteQuerySuccess<T> || 
        !currentState.hasPreviousPage ||
        options.getPreviousPageParam == null) {
      return;
    }

    final previousPageParam = options.getPreviousPageParam!(
      currentState.pages.first,
      currentState.pages,
    );

    if (previousPageParam == null) {
      return;
    }

    _safeState(InfiniteQueryFetchingPreviousPage<T>(
      pages: currentState.pages,
      hasNextPage: currentState.hasNextPage,
      hasPreviousPage: currentState.hasPreviousPage,
      fetchedAt: currentState.fetchedAt,
    ));

    try {
      final previousPage = await queryFn(ref, previousPageParam);
      final newPages = [previousPage, ...currentState.pages];
      final now = DateTime.now();

      final hasNextPage = options.getNextPageParam(newPages.last, newPages) != null;
      final hasPreviousPage = options.getPreviousPageParam!(newPages.first, newPages) != null;

      final cacheData = InfiniteQueryCacheData<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      // Update cache
      _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
        data: cacheData,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      _safeState(InfiniteQuerySuccess<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      ));

      options.onSuccess?.call(previousPage);
    } catch (error, stackTrace) {
      // Revert to previous success state on error
      _safeState(currentState);
      options.onError?.call(error, stackTrace);
    }
  }

  /// Refetch all pages
  Future<void> refetch() async {
    final currentState = state;
    if (currentState is InfiniteQuerySuccess<T>) {
      // Refetch all existing pages
      if(options.keepPreviousData){
        _safeState(InfiniteQueryRefetching<T>(
          pages: currentState.pages,
          hasNextPage: currentState.hasNextPage,
          hasPreviousPage: currentState.hasPreviousPage,
          fetchedAt: currentState.fetchedAt,
        ));
      }else{
        _safeState(const InfiniteQueryLoading());
      }
      
      try {
        final List<T> newPages = [];
        TPageParam pageParam = initialPageParam;

        // Fetch the same number of pages as currently loaded
        for (int i = 0; i < currentState.pages.length; i++) {
          final page = await queryFn(ref, pageParam);
          newPages.add(page);

          if (i < currentState.pages.length - 1) {
            final nextParam = options.getNextPageParam(page, newPages);
            if (nextParam == null) {
              break;
            }
            pageParam = nextParam;
          }
        }

        final now = DateTime.now();
        final hasNextPage = options.getNextPageParam(newPages.last, newPages) != null;
        final hasPreviousPage = options.getPreviousPageParam?.call(newPages.first, newPages) != null;

        final cacheData = InfiniteQueryCacheData<T>(
          pages: newPages,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
          fetchedAt: now,
        );

        // Update cache
        _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
          data: cacheData,
          fetchedAt: now,
          options: QueryOptions<InfiniteQueryCacheData<T>>(
            staleTime: options.staleTime,
            cacheTime: options.cacheTime,
            enabled: options.enabled,
          ),
        ));

        _safeState(InfiniteQuerySuccess<T>(
          pages: newPages,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
          fetchedAt: now,
        ));
      } catch (error, stackTrace) {
        // If keepPreviousData is enabled, don't show error state
        // Keep showing the current data
        // if (options.keepPreviousData) {
          debugPrint('Refetch failed but keeping previous data for infinite query key $queryKey: $error');
          // Don't update state, keep current data
        // } else {
          _safeState(InfiniteQueryError(error, stackTrace: stackTrace));
        // }
      }
    } else {
      await _fetchFirstPage();
    }
  }

  /// Invalidate and refetch
  Future<void> refresh() {
    _clearCache();
    return refetch();
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
    debugPrint('App resumed in infinite query notifier');
    // Resume refetching and check if we need to refetch stale data
    _isRefetchPaused = false;
    
    if (_shouldRefetchOnFocus()) {
      refetch();
    }
  }

  void _onAppPause() {
    debugPrint('App paused in infinite query notifier');
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
    debugPrint('Window focused in infinite query notifier');
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
    if (currentState is InfiniteQuerySuccess<T>) {
      // Check if data is stale based on stale time
      final now = DateTime.now();
      final fetchedAt = currentState.fetchedAt;
      if (fetchedAt != null) {
        final age = now.difference(fetchedAt);
        return age > options.staleTime;
      }
    }
    
    return false;
  }

  /// Get cached entry
  QueryCacheEntry<InfiniteQueryCacheData<T>>? _getCachedEntry() => _cache.get<InfiniteQueryCacheData<T>>(queryKey);

  /// Set cached entry
  void _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>> entry) {
    _cache.set(queryKey, entry);
  }

  /// Clear cache
  void _clearCache() {
    _cache.remove(queryKey);
  }

  /// Set query data manually (for optimistic updates)
  void setData(List<T> pages, {bool? hasNextPage, bool? hasPreviousPage}) {
    final now = DateTime.now();
    final cacheData = InfiniteQueryCacheData<T>(
      pages: pages,
      hasNextPage: hasNextPage ?? false,
      hasPreviousPage: hasPreviousPage ?? false,
      fetchedAt: now,
    );
    
    _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
      data: cacheData,
      fetchedAt: now,
      options: QueryOptions<InfiniteQueryCacheData<T>>(
        staleTime: options.staleTime,
        cacheTime: options.cacheTime,
        enabled: options.enabled,
      ),
    ));
    
    _safeState(InfiniteQuerySuccess<T>(
      pages: pages,
      hasNextPage: hasNextPage ?? false,
      hasPreviousPage: hasPreviousPage ?? false,
      fetchedAt: now,
    ));
  }

  /// Get current cached data
  InfiniteQueryCacheData<T>? getCachedData() {
    final entry = _getCachedEntry();
    return entry?.hasData??false ? entry!.data : null;
  }

  /// Set up cache change listener for automatic UI updates
  void _setupCacheListener() {
    _cache.addListener<InfiniteQueryCacheData<T>>(queryKey, (entry) {
      debugPrint('Cache listener called for key $queryKey in infinite query notifier');
      if ((entry?.hasData??false) && !(state.hasData && listEquals(entry!.data!.pages, state.pages))) {
        debugPrint('Cache data changed for key $queryKey in infinite query notifier');
        // Update state when cache data changes externally (e.g., optimistic updates)
        final cacheData = entry!.data!;
        _safeState(InfiniteQuerySuccess(
          pages: cacheData.pages,
          hasNextPage: cacheData.hasNextPage,
          hasPreviousPage: cacheData.hasPreviousPage,
          fetchedAt: cacheData.fetchedAt,
        ));
      } else if (entry == null) {
        debugPrint('Cache entry removed for key $queryKey in infinite query notifier');
        // Cache entry was removed, reset to idle
        if(options.onCacheEvicted != null){
          options.onCacheEvicted?.call(queryKey);
        }else{
          refetch();
        }
      }
    });
  }

}

/// Modern infinite query provider using Notifier.
NotifierProvider<InfiniteQueryNotifier<T, TPageParam>, InfiniteQueryState<T>> infiniteQueryProvider<T, TPageParam>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, TPageParam> queryFn,
  required TPageParam initialPageParam,
  required InfiniteQueryOptions<T, TPageParam> options
}) => NotifierProvider<InfiniteQueryNotifier<T, TPageParam>, InfiniteQueryState<T>>(
    () => InfiniteQueryNotifier<T, TPageParam>(
      queryFn: (ref,param) => queryFn(ref, param),
      options: options,
      initialPageParam: initialPageParam,
      queryKey: name,
    ),
    name: name,
  );

/// Auto-dispose Notifier for managing infinite query state
class InfiniteQueryNotifierAutoDispose<T, TPageParam> extends AutoDisposeNotifier<InfiniteQueryState<T>>
    with QueryClientMixin {
  InfiniteQueryNotifierAutoDispose({
    required this.queryFn,
    required this.options,
    required this.initialPageParam,
    required this.queryKey,
  });

  @override
  InfiniteQueryState<T> build() {
    _initialize();
    _setupDispose();
    return const InfiniteQueryIdle();
  }

  void _setupDispose() {
    ref.onDispose(() {
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
    
      debugPrint('InfiniteQueryNotifierAutoDispose disposed for key $queryKey');
    });
  }

  final QueryFunctionWithParamsWithRef<T, TPageParam> queryFn;
  final InfiniteQueryOptions<T, TPageParam> options;
  final TPageParam initialPageParam;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;
  bool _isInitialized = false;
  
  // Initialize cache, lifecycle manager, and window focus manager
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;

  void _initialize() {
    if (!_isInitialized) {
      _isInitialized = true;
      // Set up cache change listener for automatic UI updates
      _setupCacheListener();
      
      // Set up lifecycle and window focus callbacks
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();
    }
    
    if (options.enabled && options.refetchOnMount) {
      _fetchFirstPage();
    }

    // Set up automatic refetching if configured
    if (options.enabled && options.refetchInterval != null) {
      _scheduleRefetch();
    }
  }

  void _safeState(InfiniteQueryState<T> newState) {
    // In modern Notifier, we don't need to check if it's mounted
    // The framework handles this automatically
    state = newState;
  }

  /// Fetch the first page
  Future<void> _fetchFirstPage() async {
    if (!options.enabled) {
      return;
    }

    debugPrint('Fetching first page for infinite query key $queryKey');

    // Check cache first
    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      debugPrint('Using cached data for infinite query key $queryKey');
      final cacheData = cachedEntry.data!;
      _safeState(InfiniteQuerySuccess<T>(
        pages: cacheData.pages,
        hasNextPage: cacheData.hasNextPage,
        hasPreviousPage: cacheData.hasPreviousPage,
        fetchedAt: cacheData.fetchedAt,
      ));
      return;
    }

    // If keepPreviousData is enabled and we have stale cached data, use it while fetching fresh data
    if (options.keepPreviousData && cachedEntry != null && cachedEntry.hasData) {
      debugPrint('Using stale cached data with keepPreviousData for infinite query key $queryKey');
      final staleData = cachedEntry.data!;
      _safeState(InfiniteQuerySuccess<T>(
        pages: staleData.pages,
        hasNextPage: staleData.hasNextPage,
        hasPreviousPage: staleData.hasPreviousPage,
        fetchedAt: staleData.fetchedAt,
      ));
      
      // Start fetching fresh data in the background
      _fetchFirstPageInBackground();
      return;
    }

    // Show loading state if no cached data or keepPreviousData is disabled
    _safeState(const InfiniteQueryLoading());

    try {
      final firstPage = await queryFn(ref, initialPageParam);
      final now = DateTime.now();
      final pages = [firstPage];

      final hasNextPage = options.getNextPageParam(firstPage, pages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(firstPage, pages) != null;

      final cacheData = InfiniteQueryCacheData<T>(
        pages: pages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      // Cache the result
      _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
        data: cacheData,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      _safeState(InfiniteQuerySuccess<T>(
        pages: pages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      ));

      _retryCount = 0;
      options.onSuccess?.call(firstPage);
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _fetchFirstPage();
      }

      // Cache the error
      _cache.setError<InfiniteQueryCacheData<T>>(
        queryKey,
        error,
        stackTrace: stackTrace,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      );

      _safeState(InfiniteQueryError(error, stackTrace: stackTrace));
      _retryCount = 0;
      options.onError?.call(error, stackTrace);
    }
  }

  /// Fetch the first page in background (for keepPreviousData)
  void _fetchFirstPageInBackground() {
    _fetchFirstPageCore().then((result) {
      if (result != null) {
        final (pages, hasNextPage, hasPreviousPage, fetchedAt) = result;
        _safeState(InfiniteQuerySuccess<T>(
          pages: pages,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
          fetchedAt: fetchedAt,
        ));
      }
    }).catchError((Object error, StackTrace stackTrace) {
      // On error, keep the current stale data but log the error
      debugPrint('Background fetch failed for infinite query key $queryKey: $error');
      // Don't update state on error to keep showing stale data
    });
  }

  /// Core fetch logic that can be reused
  Future<(List<T>, bool, bool, DateTime)?> _fetchFirstPageCore() async {
    try {
      final firstPage = await queryFn(ref, initialPageParam);
      final now = DateTime.now();
      final pages = [firstPage];

      final hasNextPage = options.getNextPageParam(firstPage, pages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(firstPage, pages) != null;

      final cacheData = InfiniteQueryCacheData<T>(
        pages: pages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      // Cache the result
      _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
        data: cacheData,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      _retryCount = 0;
      options.onSuccess?.call(firstPage);

      return (pages, hasNextPage, hasPreviousPage, now);
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _fetchFirstPageCore();
      }

      // Cache the error
      _cache.setError<InfiniteQueryCacheData<T>>(
        queryKey,
        error,
        stackTrace: stackTrace,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      );

      _retryCount = 0;
      options.onError?.call(error, stackTrace);
      return null;
    }
  }

  /// Fetch the next page
  Future<void> fetchNextPage() async {
    final currentState = state;
    if (currentState is! InfiniteQuerySuccess<T> || !currentState.hasNextPage) {
      return;
    }

    final nextPageParam = options.getNextPageParam(currentState.pages.last, currentState.pages);
    if (nextPageParam == null) {
      return;
    }

    debugPrint('Fetching next page for infinite query key $queryKey');

    // Show fetching next page state
    _safeState(InfiniteQueryFetchingNextPage<T>(
      pages: currentState.pages,
      hasNextPage: currentState.hasNextPage,
      hasPreviousPage: currentState.hasPreviousPage,
      fetchedAt: currentState.fetchedAt,
    ));

    try {
      final nextPage = await queryFn(ref, nextPageParam);
      final newPages = [...currentState.pages, nextPage];
      final now = DateTime.now();

      final hasNextPage = options.getNextPageParam(nextPage, newPages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(newPages.first, newPages) != null;

      final cacheData = InfiniteQueryCacheData<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      // Cache the result
      _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
        data: cacheData,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      _safeState(InfiniteQuerySuccess<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      ));

      options.onSuccess?.call(nextPage);
    } catch (error, stackTrace) {
      _safeState(InfiniteQueryError(error, stackTrace: stackTrace));
      options.onError?.call(error, stackTrace);
    }
  }

  /// Fetch the previous page
  Future<void> fetchPreviousPage() async {
    final currentState = state;
    if (currentState is! InfiniteQuerySuccess<T> || 
        !currentState.hasPreviousPage ||
        options.getPreviousPageParam == null) {
      return;
    }

    final previousPageParam = options.getPreviousPageParam!(currentState.pages.first, currentState.pages);
    if (previousPageParam == null) {
      return;
    }

    debugPrint('Fetching previous page for infinite query key $queryKey');

    // Show fetching previous page state
    _safeState(InfiniteQueryFetchingPreviousPage<T>(
      pages: currentState.pages,
      hasNextPage: currentState.hasNextPage,
      hasPreviousPage: currentState.hasPreviousPage,
      fetchedAt: currentState.fetchedAt,
    ));

    try {
      final previousPage = await queryFn(ref, previousPageParam);
      final newPages = [previousPage, ...currentState.pages];
      final now = DateTime.now();

      final hasNextPage = options.getNextPageParam(newPages.last, newPages) != null;
      final hasPreviousPage = options.getPreviousPageParam!(newPages.first, newPages) != null;

      final cacheData = InfiniteQueryCacheData<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      // Cache the result
      _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
        data: cacheData,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      _safeState(InfiniteQuerySuccess<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      ));

      options.onSuccess?.call(previousPage);
    } catch (error, stackTrace) {
      _safeState(InfiniteQueryError(error, stackTrace: stackTrace));
      options.onError?.call(error, stackTrace);
    }
  }

  /// Refetch all pages
  Future<void> refetch() async {
    final currentState = state;
    if (currentState is InfiniteQuerySuccess<T>) {
      // Show refetching state with previous data
      _safeState(InfiniteQueryRefetching<T>(
        pages: currentState.pages,
        hasNextPage: currentState.hasNextPage,
        hasPreviousPage: currentState.hasPreviousPage,
        fetchedAt: currentState.fetchedAt,
      ));
    } else {
      _safeState(const InfiniteQueryLoading());
    }

    try {
      // Refetch all pages sequentially
      final List<T> newPages = [];
      TPageParam pageParam = initialPageParam;

      // Fetch the same number of pages as currently loaded
      final pagesToLoad = currentState is InfiniteQuerySuccess<T> ? currentState.pages.length : 1;
      for (int i = 0; i < pagesToLoad; i++) {
        final page = await queryFn(ref, pageParam);
        newPages.add(page);

        if (i < pagesToLoad - 1) {
          final nextParam = options.getNextPageParam(page, newPages);
          if (nextParam == null) {
            break; // No more pages available
          }
          pageParam = nextParam;
        }
      }

      final now = DateTime.now();
      final hasNextPage = options.getNextPageParam(newPages.last, newPages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(newPages.first, newPages) != null;

      final cacheData = InfiniteQueryCacheData<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      // Cache the result
      _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
        data: cacheData,
        fetchedAt: now,
        options: QueryOptions<InfiniteQueryCacheData<T>>(
          staleTime: options.staleTime,
          cacheTime: options.cacheTime,
          enabled: options.enabled,
        ),
      ));

      _safeState(InfiniteQuerySuccess<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      ));

      _retryCount = 0;
    } catch (error, stackTrace) {
      _safeState(InfiniteQueryError(error, stackTrace: stackTrace));
      _retryCount = 0;
      options.onError?.call(error, stackTrace);
    }
  }

  /// Invalidate and refetch
  Future<void> refresh() {
    _clearCache();
    return refetch();
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
    debugPrint('App resumed in infinite query notifier');
    // Resume refetching and check if we need to refetch stale data
    _isRefetchPaused = false;
    
    if (_shouldRefetchOnFocus()) {
      refetch();
    }
  }

  void _onAppPause() {
    debugPrint('App paused in infinite query notifier');
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
    debugPrint('Window focused in infinite query notifier');
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

    final cachedEntry = _getCachedEntry();
    if (cachedEntry == null) {
      return true; // No cached data, should refetch
    }

    // Check if data is stale based on staleTime
    return cachedEntry.isStale;
  }

  QueryCacheEntry<InfiniteQueryCacheData<T>>? _getCachedEntry() => _cache.get<InfiniteQueryCacheData<T>>(queryKey);

  void _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>> entry) {
    _cache.set(queryKey, entry);
  }

  void _clearCache() {
    _cache.remove(queryKey);
  }

  /// Manually set data for optimistic updates
  void setData(List<T> pages, {bool? hasNextPage, bool? hasPreviousPage}) {
    final now = DateTime.now();
    final cacheData = InfiniteQueryCacheData<T>(
      pages: pages,
      hasNextPage: hasNextPage ?? false,
      hasPreviousPage: hasPreviousPage ?? false,
      fetchedAt: now,
    );

    // Cache the result
    _setCachedEntry(QueryCacheEntry<InfiniteQueryCacheData<T>>(
      data: cacheData,
      fetchedAt: now,
      options: QueryOptions<InfiniteQueryCacheData<T>>(
        staleTime: options.staleTime,
        cacheTime: options.cacheTime,
        enabled: options.enabled,
      ),
    ));

    _safeState(InfiniteQuerySuccess<T>(
      pages: pages,
      hasNextPage: hasNextPage ?? false,
      hasPreviousPage: hasPreviousPage ?? false,
      fetchedAt: now,
    ));
  }

  /// Set up cache change listener for automatic UI updates
  void _setupCacheListener() {
    _cache.addListener<InfiniteQueryCacheData<T>>(queryKey, (entry) {
      debugPrint('Cache listener called for key $queryKey in infinite query notifier');
      if ((entry?.hasData??false) && !(state.hasData && listEquals(entry!.data!.pages, state.pages))) {
        debugPrint('Cache data changed for key $queryKey in infinite query notifier');
        // Update state when cache data changes externally (e.g., optimistic updates)
        final cacheData = entry!.data!;
        _safeState(InfiniteQuerySuccess(
          pages: cacheData.pages,
          hasNextPage: cacheData.hasNextPage,
          hasPreviousPage: cacheData.hasPreviousPage,
          fetchedAt: cacheData.fetchedAt,
        ));
      } else if (entry == null) {
        debugPrint('Cache entry removed for key $queryKey in infinite query notifier');
        // Cache entry was removed, reset to idle
        if(options.onCacheEvicted != null){
          options.onCacheEvicted?.call(queryKey);
        }else{
          refetch();
        }
      }
    });
  }
}

/// Modern auto-dispose infinite query provider using Notifier
/// 
/// **Use this when:**
/// - Temporary infinite data that should be cleaned up when not watched
/// - Memory optimization for large paginated datasets
/// - Short-lived screens with infinite scrolling
/// - Data that doesn't need to persist across navigation
/// 
/// **Features:**
/// - ✅ Automatic cleanup when no longer watched
/// - ✅ Full infinite query functionality (fetchNextPage, fetchPreviousPage)
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
/// final tempPostsProvider = infiniteQueryProviderAutoDispose<Post, int>(
///   name: 'temp-posts',
///   queryFn: (ref, pageParam) => ApiService.fetchPosts(page: pageParam),
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
/// final postsResult = ref.readInfiniteQueryResult(tempPostsProvider);
/// postsResult.state.when(
///   idle: () => Text('Tap to load'),
///   loading: () => CircularProgressIndicator(),
///   success: (pages, hasNextPage, hasPreviousPage, fetchedAt) => 
///     ListView.builder(
///       itemCount: pages.expand((page) => page.items).length,
///       itemBuilder: (context, index) => PostTile(post: pages[index]),
///     ),
///   error: (error, stackTrace) => ErrorWidget(error),
/// );
/// ```
AutoDisposeNotifierProvider<InfiniteQueryNotifierAutoDispose<T, TPageParam>, InfiniteQueryState<T>> infiniteQueryProviderAutoDispose<T, TPageParam>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, TPageParam> queryFn,
  required TPageParam initialPageParam,
  required InfiniteQueryOptions<T, TPageParam> options,
}) => NotifierProvider.autoDispose<InfiniteQueryNotifierAutoDispose<T, TPageParam>, InfiniteQueryState<T>>(
    () => InfiniteQueryNotifierAutoDispose<T, TPageParam>(
      queryFn: (ref, param) => queryFn(ref, param),
      options: options,
      initialPageParam: initialPageParam,
      queryKey: name,
    ),
    name: name,
  );

/// Hook-like interface for using infinite queries
@immutable
class InfiniteQueryResult<T> {
  const InfiniteQueryResult({
    required this.state,
    required this.fetchNextPage,
    required this.fetchPreviousPage,
    required this.refetch,
  });

  final InfiniteQueryState<T> state;
  final Future<void> Function() fetchNextPage;
  final Future<void> Function() fetchPreviousPage;
  final Future<void> Function() refetch;

  /// Returns true if the query is currently loading the first page
  bool get isLoading => state.isLoading;

  /// Returns true if the query has data
  bool get hasData => state.hasData;

  /// Returns true if the query has an error
  bool get hasError => state.hasError;

  /// Returns true if the query is fetching the next page
  bool get isFetchingNextPage => state.isFetchingNextPage;

  /// Returns true if the query is fetching the previous page
  bool get isFetchingPreviousPage => state.isFetchingPreviousPage;

  /// Returns the pages if available
  List<T>? get pages => state.pages;

  /// Returns the error if available
  Object? get error => state.error;

  /// Returns true if there are more pages to fetch
  bool get hasNextPage => switch (state) {
        final InfiniteQuerySuccess<T> success => success.hasNextPage,
        final InfiniteQueryFetchingNextPage<T> fetching => fetching.hasNextPage,
        final InfiniteQueryFetchingPreviousPage<T> fetching => fetching.hasNextPage,
        _ => false,
      };

  /// Returns true if there are previous pages to fetch
  bool get hasPreviousPage => switch (state) {
        InfiniteQuerySuccess<T> success => success.hasPreviousPage,
        InfiniteQueryFetchingNextPage<T> fetching => fetching.hasPreviousPage,
        InfiniteQueryFetchingPreviousPage<T> fetching => fetching.hasPreviousPage,
        _ => false,
      };
}

// /// Extension to create an infinite query result from a provider
// extension InfiniteQueryProviderExtension<T, TPageParam> on StateNotifierProvider<InfiniteQueryNotifier<T, TPageParam>, InfiniteQueryState<T>> {
//   /// Create an infinite query result that can be used in widgets
//   InfiniteQueryResult<T> use(WidgetRef ref) {
//     final notifier = ref.read(this.notifier);
//     final state = ref.watch(this);

//     return InfiniteQueryResult<T>(
//       state: state,
//       fetchNextPage: notifier.fetchNextPage,
//       fetchPreviousPage: notifier.fetchPreviousPage,
//       refetch: notifier.refetch,
//     );
//   }
// }

/// Extension to create an infinite query result from a provider
extension WidgetRefReadQueryResult on WidgetRef {
  /// Create an infinite query result that can be used in widgets (modern version)
  InfiniteQueryResult<T> readInfiniteQueryResult<T, TPageParam>(NotifierProvider<InfiniteQueryNotifier<T, TPageParam>, InfiniteQueryState<T>> provider) {
    final notifier = read(provider.notifier);
    final state = watch(provider);

    return InfiniteQueryResult<T>(
      state: state,
      fetchNextPage: notifier.fetchNextPage,
      fetchPreviousPage: notifier.fetchPreviousPage,
      refetch: notifier.refetch,
    );
  }

  /// Create an infinite query result from an auto-dispose provider
  InfiniteQueryResult<T> readInfiniteQueryResultAutoDispose<T, TPageParam>(AutoDisposeNotifierProvider<InfiniteQueryNotifierAutoDispose<T, TPageParam>, InfiniteQueryState<T>> provider) {
    final notifier = read(provider.notifier);
    final state = watch(provider);

    return InfiniteQueryResult<T>(
      state: state,
      fetchNextPage: notifier.fetchNextPage,
      fetchPreviousPage: notifier.fetchPreviousPage,
      refetch: notifier.refetch,
    );
  }
}

/// Extension to handle infinite query state more elegantly
extension InfiniteQueryStateExtension<T> on InfiniteQueryState<T> {
  R when<R>({
    required R Function() idle,
    required R Function() loading,
    required R Function(List<T> pages, bool hasNextPage, bool hasPreviousPage, DateTime? fetchedAt) success,
    required R Function(List<T> pages, bool hasNextPage, bool hasPreviousPage, DateTime? fetchedAt) refetching,
    required R Function(Object error, StackTrace? stackTrace) error,
    required R Function(List<T> pages, bool hasNextPage, bool hasPreviousPage, DateTime? fetchedAt) fetchingNextPage,
    required R Function(List<T> pages, bool hasNextPage, bool hasPreviousPage, DateTime? fetchedAt) fetchingPreviousPage,
  }) {
    return switch (this) {
      InfiniteQueryIdle<T>() => idle(),
      InfiniteQueryLoading<T>() => loading(),
      final InfiniteQuerySuccess<T> successState => success(successState.pages, successState.hasNextPage, successState.hasPreviousPage, successState.fetchedAt),
      final InfiniteQueryRefetching<T> refetchingState => refetching(refetchingState.pages, refetchingState.hasNextPage, refetchingState.hasPreviousPage, refetchingState.fetchedAt),
      final InfiniteQueryError<T> errorState => error(errorState.error, errorState.stackTrace),
      final InfiniteQueryFetchingNextPage<T> fetching => fetchingNextPage(fetching.pages, fetching.hasNextPage, fetching.hasPreviousPage, fetching.fetchedAt),
      final InfiniteQueryFetchingPreviousPage<T> fetching => fetchingPreviousPage(fetching.pages, fetching.hasNextPage, fetching.hasPreviousPage, fetching.fetchedAt),
    };
  }
}