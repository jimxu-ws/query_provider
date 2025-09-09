import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'query_cache.dart';
import 'query_client.dart';
import 'query_options.dart';

/// A function that fetches a page of data
typedef InfiniteQueryFunction<T, TPageParam> = Future<T> Function(TPageParam pageParam);

/// Represents the state of an infinite query
@immutable
sealed class InfiniteQueryState<T> {
  const InfiniteQueryState();

  /// Returns true if the query is currently loading the first page
  bool get isLoading => this is InfiniteQueryLoading<T>;

  /// Returns true if the query has data
  bool get hasData => this is InfiniteQuerySuccess<T>;

  /// Returns true if the query has an error
  bool get hasError => this is InfiniteQueryError<T>;

  /// Returns true if the query is idle
  bool get isIdle => this is InfiniteQueryIdle<T>;

  /// Returns true if the query is fetching the next page
  bool get isFetchingNextPage => this is InfiniteQueryFetchingNextPage<T>;

  /// Returns true if the query is fetching the previous page
  bool get isFetchingPreviousPage => this is InfiniteQueryFetchingPreviousPage<T>;

  /// Returns the pages if available
  List<T>? get pages => switch (this) {
        final InfiniteQuerySuccess<T> success => success.pages,
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

/// Notifier for managing infinite query state
class InfiniteQueryNotifier<T, TPageParam> extends StateNotifier<InfiniteQueryState<T>>
    with QueryClientMixin {
  InfiniteQueryNotifier({
    required this.queryFn,
    required this.options,
    required this.initialPageParam,
    required this.queryKey,
  }) : super(const InfiniteQueryIdle()) {
    _initialize();
  }

  final InfiniteQueryFunction<T, TPageParam> queryFn;
  final InfiniteQueryOptions<T, TPageParam> options;
  final TPageParam initialPageParam;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;

  void _initialize() {
    // Set up cache change listener for automatic UI updates
    _setupCacheListener();
    
    if (options.enabled && options.refetchOnMount) {
      _fetchFirstPage();
    }

    // Set up automatic refetching if configured
    if (options.refetchInterval != null) {
      _scheduleRefetch();
    }
  }

  /// Fetch the first page
  Future<void> _fetchFirstPage() async {
    if (!options.enabled) return;

    state = const InfiniteQueryLoading();

    try {
      final firstPage = await queryFn(initialPageParam);
      final now = DateTime.now();
      final pages = [firstPage];

      final hasNextPage = options.getNextPageParam(firstPage, pages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(firstPage, pages) != null;

      state = InfiniteQuerySuccess<T>(
        pages: pages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: now,
      );

      _retryCount = 0;
      options.onSuccess?.call(firstPage);
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _fetchFirstPage();
      }

      state = InfiniteQueryError(error, stackTrace: stackTrace);
      _retryCount = 0;
      options.onError?.call(error, stackTrace);
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

    state = InfiniteQueryFetchingNextPage<T>(
      pages: currentState.pages,
      hasNextPage: currentState.hasNextPage,
      hasPreviousPage: currentState.hasPreviousPage,
      fetchedAt: currentState.fetchedAt,
    );

    try {
      final nextPage = await queryFn(nextPageParam);
      final newPages = [...currentState.pages, nextPage];

      final hasNextPage = options.getNextPageParam(nextPage, newPages) != null;
      final hasPreviousPage = options.getPreviousPageParam?.call(newPages.first, newPages) != null;

      state = InfiniteQuerySuccess<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: DateTime.now(),
      );

      options.onSuccess?.call(nextPage);
    } catch (error, stackTrace) {
      // Revert to previous success state on error
      state = currentState;
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

    if (previousPageParam == null) return;

    state = InfiniteQueryFetchingPreviousPage<T>(
      pages: currentState.pages,
      hasNextPage: currentState.hasNextPage,
      hasPreviousPage: currentState.hasPreviousPage,
      fetchedAt: currentState.fetchedAt,
    );

    try {
      final previousPage = await queryFn(previousPageParam);
      final newPages = [previousPage, ...currentState.pages];

      final hasNextPage = options.getNextPageParam(newPages.last, newPages) != null;
      final hasPreviousPage = options.getPreviousPageParam!(newPages.first, newPages) != null;

      state = InfiniteQuerySuccess<T>(
        pages: newPages,
        hasNextPage: hasNextPage,
        hasPreviousPage: hasPreviousPage,
        fetchedAt: DateTime.now(),
      );

      options.onSuccess?.call(previousPage);
    } catch (error, stackTrace) {
      // Revert to previous success state on error
      state = currentState;
      options.onError?.call(error, stackTrace);
    }
  }

  /// Refetch all pages
  Future<void> refetch() async {
    final currentState = state;
    if (currentState is InfiniteQuerySuccess<T>) {
      // Refetch all existing pages
      state = const InfiniteQueryLoading();
      
      try {
        final List<T> newPages = [];
        TPageParam pageParam = initialPageParam;

        // Fetch the same number of pages as currently loaded
        for (int i = 0; i < currentState.pages.length; i++) {
          final page = await queryFn(pageParam);
          newPages.add(page);

          if (i < currentState.pages.length - 1) {
            final nextParam = options.getNextPageParam(page, newPages);
            if (nextParam == null) break;
            pageParam = nextParam;
          }
        }

        final hasNextPage = options.getNextPageParam(newPages.last, newPages) != null;
        final hasPreviousPage = options.getPreviousPageParam?.call(newPages.first, newPages) != null;

        state = InfiniteQuerySuccess<T>(
          pages: newPages,
          hasNextPage: hasNextPage,
          hasPreviousPage: hasPreviousPage,
          fetchedAt: DateTime.now(),
        );
      } catch (error, stackTrace) {
        state = InfiniteQueryError(error, stackTrace: stackTrace);
      }
    } else {
      _fetchFirstPage();
    }
  }

  void _scheduleRefetch() {
    _refetchTimer?.cancel();
    if (options.refetchInterval != null) {
      _refetchTimer = Timer.periodic(options.refetchInterval!, (_) {
        if (options.enabled) {
          refetch();
        }
      });
    }
  }

  /// Set up cache change listener for automatic UI updates
  void _setupCacheListener() {
    getGlobalQueryCache().addListener<List<T>>(queryKey, (entry) {
      debugPrint('Cache listener called for key $queryKey in infinite query notifier');
      if (entry?.hasData ?? false) {
        // Update state when cache data changes externally (e.g., optimistic updates)
        final pages = entry!.data!;
        state = InfiniteQuerySuccess(
          pages: pages,
          hasNextPage: true, // This would need to be determined properly
          hasPreviousPage: false,
          fetchedAt: entry.fetchedAt,
        );
      } else if (entry == null) {
        // Cache entry was removed, reset to idle
        state = const InfiniteQueryIdle();
      }
    });
  }

  @override
  void dispose() {
    _refetchTimer?.cancel();
    
    // Clean up cache listener
    getGlobalQueryCache().removeAllListeners(queryKey);
    
    super.dispose();
  }
}

/// Provider for creating infinite queries
StateNotifierProvider<InfiniteQueryNotifier<T, TPageParam>, InfiniteQueryState<T>> infiniteQueryProvider<T, TPageParam>({
  required String name,
  required InfiniteQueryFunction<T, TPageParam> queryFn,
  required TPageParam initialPageParam,
  required InfiniteQueryOptions<T, TPageParam> options,
}) => StateNotifierProvider<InfiniteQueryNotifier<T, TPageParam>, InfiniteQueryState<T>>(
    (ref) => InfiniteQueryNotifier<T, TPageParam>(
      queryFn: queryFn,
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

/// Extension to create an infinite query result from a provider
extension InfiniteQueryProviderExtension<T, TPageParam> on StateNotifierProvider<InfiniteQueryNotifier<T, TPageParam>, InfiniteQueryState<T>> {
  /// Create an infinite query result that can be used in widgets
  InfiniteQueryResult<T> use(WidgetRef ref) {
    final notifier = ref.read(this.notifier);
    final state = ref.watch(this);

    return InfiniteQueryResult<T>(
      state: state,
      fetchNextPage: notifier.fetchNextPage,
      fetchPreviousPage: notifier.fetchPreviousPage,
      refetch: notifier.refetch,
    );
  }
}
