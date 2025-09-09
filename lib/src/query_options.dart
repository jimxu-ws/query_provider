import 'package:meta/meta.dart';

/// Configuration options for a query
@immutable
class QueryOptions<T> {
  const QueryOptions({
    this.staleTime = const Duration(minutes: 5),
    this.cacheTime = const Duration(minutes: 30),
    this.refetchOnMount = true,
    this.refetchOnWindowFocus = false,
    this.refetchOnAppFocus = true,
    this.pauseRefetchInBackground = true,
    this.refetchInterval,
    this.retry = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enabled = true,
    this.keepPreviousData = false,
    this.onSuccess,
    this.onError,
  });

  /// Time after which data is considered stale and will be refetched
  final Duration staleTime;

  /// Time after which unused data is removed from cache
  final Duration cacheTime;

  /// Whether to refetch when the query mounts
  final bool refetchOnMount;

  /// Whether to refetch when the window regains focus
  final bool refetchOnWindowFocus;

  /// Whether to refetch when the app comes to foreground
  final bool refetchOnAppFocus;

  /// Whether to pause automatic refetching when app is in background
  final bool pauseRefetchInBackground;

  /// Interval for automatic refetching (null to disable)
  final Duration? refetchInterval;

  /// Number of retry attempts on failure
  final int retry;

  /// Delay between retry attempts
  final Duration retryDelay;

  /// Whether the query is enabled
  final bool enabled;

  /// Whether to keep previous data while fetching new data
  final bool keepPreviousData;

  /// Callback called on successful query
  final void Function(T data)? onSuccess;

  /// Callback called on query error
  final void Function(Object error, StackTrace? stackTrace)? onError;

  QueryOptions<T> copyWith({
    Duration? staleTime,
    Duration? cacheTime,
    bool? refetchOnMount,
    bool? refetchOnWindowFocus,
    bool? refetchOnAppFocus,
    bool? pauseRefetchInBackground,
    Duration? refetchInterval,
    int? retry,
    Duration? retryDelay,
    bool? enabled,
    bool? keepPreviousData,
    void Function(T data)? onSuccess,
    void Function(Object error, StackTrace? stackTrace)? onError,
  }) {
    return QueryOptions<T>(
      staleTime: staleTime ?? this.staleTime,
      cacheTime: cacheTime ?? this.cacheTime,
      refetchOnMount: refetchOnMount ?? this.refetchOnMount,
      refetchOnWindowFocus: refetchOnWindowFocus ?? this.refetchOnWindowFocus,
      refetchOnAppFocus: refetchOnAppFocus ?? this.refetchOnAppFocus,
      pauseRefetchInBackground: pauseRefetchInBackground ?? this.pauseRefetchInBackground,
      refetchInterval: refetchInterval ?? this.refetchInterval,
      retry: retry ?? this.retry,
      retryDelay: retryDelay ?? this.retryDelay,
      enabled: enabled ?? this.enabled,
      keepPreviousData: keepPreviousData ?? this.keepPreviousData,
      onSuccess: onSuccess ?? this.onSuccess,
      onError: onError ?? this.onError,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueryOptions<T> &&
          other.staleTime == staleTime &&
          other.cacheTime == cacheTime &&
          other.refetchOnMount == refetchOnMount &&
          other.refetchOnWindowFocus == refetchOnWindowFocus &&
          other.refetchOnAppFocus == refetchOnAppFocus &&
          other.pauseRefetchInBackground == pauseRefetchInBackground &&
          other.refetchInterval == refetchInterval &&
          other.retry == retry &&
          other.retryDelay == retryDelay &&
          other.enabled == enabled &&
          other.keepPreviousData == keepPreviousData);

  @override
  int get hashCode => Object.hash(
        staleTime,
        cacheTime,
        refetchOnMount,
        refetchOnWindowFocus,
        refetchOnAppFocus,
        pauseRefetchInBackground,
        refetchInterval,
        retry,
        retryDelay,
        enabled,
        keepPreviousData,
      );

  @override
  String toString() => 'QueryOptions<$T>('
      'staleTime: $staleTime, '
      'cacheTime: $cacheTime, '
      'refetchOnMount: $refetchOnMount, '
      'refetchOnWindowFocus: $refetchOnWindowFocus, '
      'refetchInterval: $refetchInterval, '
      'retry: $retry, '
      'retryDelay: $retryDelay, '
      'enabled: $enabled, '
      'keepPreviousData: $keepPreviousData)';
}

/// Configuration for infinite queries
@immutable
class InfiniteQueryOptions<T, TPageParam> extends QueryOptions<T> {
  const InfiniteQueryOptions({
    required this.getNextPageParam,
    this.getPreviousPageParam,
    super.staleTime,
    super.cacheTime,
    super.refetchOnMount,
    super.refetchOnWindowFocus,
    super.refetchInterval,
    super.retry,
    super.retryDelay,
    super.enabled,
    super.keepPreviousData,
    super.onSuccess,
    super.onError,
  });

  /// Function to get the next page parameter
  final TPageParam? Function(T lastPage, List<T> allPages) getNextPageParam;

  /// Function to get the previous page parameter
  final TPageParam? Function(T firstPage, List<T> allPages)?
      getPreviousPageParam;

  @override
  InfiniteQueryOptions<T, TPageParam> copyWith({
    Duration? staleTime,
    Duration? cacheTime,
    bool? refetchOnMount,
    bool? refetchOnWindowFocus,
    bool? refetchOnAppFocus,
    bool? pauseRefetchInBackground,
    Duration? refetchInterval,
    int? retry,
    Duration? retryDelay,
    bool? enabled,
    bool? keepPreviousData,
    void Function(T data)? onSuccess,
    void Function(Object error, StackTrace? stackTrace)? onError,
    TPageParam? Function(T lastPage, List<T> allPages)? getNextPageParam,
    TPageParam? Function(T firstPage, List<T> allPages)?
        getPreviousPageParam,
  }) {
    return InfiniteQueryOptions<T, TPageParam>(
      staleTime: staleTime ?? this.staleTime,
      cacheTime: cacheTime ?? this.cacheTime,
      refetchOnMount: refetchOnMount ?? this.refetchOnMount,
      refetchOnWindowFocus: refetchOnWindowFocus ?? this.refetchOnWindowFocus,
      refetchInterval: refetchInterval ?? this.refetchInterval,
      retry: retry ?? this.retry,
      retryDelay: retryDelay ?? this.retryDelay,
      enabled: enabled ?? this.enabled,
      keepPreviousData: keepPreviousData ?? this.keepPreviousData,
      onSuccess: onSuccess ?? this.onSuccess,
      onError: onError ?? this.onError,
      getNextPageParam: getNextPageParam ?? this.getNextPageParam,
      getPreviousPageParam: getPreviousPageParam ?? this.getPreviousPageParam,
    );
  }
}
